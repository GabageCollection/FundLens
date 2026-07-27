"""PaddleOCR backend. Owns a single lazily constructed PaddleOCR instance."""

import logging
import os
from typing import Any

from .backend import OcrToken

logger = logging.getLogger("fundlens_engine")

# Screenshots larger than this on their long side are downscaled before
# inference: detection cost scales with pixels while the fund-app text stays
# comfortably legible at this size.
MAX_INPUT_LONG_SIDE = 1600


class PaddleBackend:
    def __init__(self) -> None:
        self._ocr: Any = None

    def _instance(self) -> Any:
        if self._ocr is None:
            # Workaround for PaddlePaddle 3.x CPU + oneDNN: the PIR runtime
            # converter does not support the ArrayAttribute<DoubleAttribute>
            # used by the PP-OCR models and crashes at inference time.
            # Disable oneDNN and opt out of the forced PIR API.
            # https://github.com/PaddlePaddle/PaddleOCR/issues/18119
            os.environ["FLAGS_enable_pir_api"] = "0"
            from paddleocr import PaddleOCR  # type: ignore[import-untyped]

            logger.info("initializing PaddleOCR")
            # Mobile models: roughly half the inference time of the medium
            # set on oneDNN-less CPUs, with plenty of accuracy for clean
            # fund-app screenshots.
            self._ocr = PaddleOCR(
                text_detection_model_name="PP-OCRv5_mobile_det",
                text_recognition_model_name="PP-OCRv5_mobile_rec",
                use_textline_orientation=True,
                lang="ch",
                enable_mkldnn=False,
            )
        return self._ocr

    def recognize(self, image_path: str) -> list[OcrToken]:
        source, box_scale = _load_for_inference(image_path)
        results = self._instance().predict(input=source)
        tokens: list[OcrToken] = []
        for result in results:
            texts = result["rec_texts"]
            scores = result["rec_scores"]
            boxes = result["rec_boxes"]
            for text, score, box in zip(texts, scores, boxes):
                # Map boxes back onto the original image so the review UI
                # crops match what the user actually selected.
                x1, y1, x2, y2 = (int(v * box_scale) for v in box)
                tokens.append(
                    OcrToken(
                        text=str(text),
                        confidence=float(score),
                        box=(x1, y1, max(0, x2 - x1), max(0, y2 - y1)),
                    )
                )
        return tokens


def _load_for_inference(image_path: str) -> tuple[Any, float]:
    """Load [image_path] for inference plus the box scale-back factor.

    Images longer than MAX_INPUT_LONG_SIDE are downscaled (detection cost
    scales with pixels); the returned factor maps inference boxes back to
    original-image coordinates. Small images pass through as the original
    path with factor 1.
    """
    from PIL import Image

    with Image.open(image_path) as image:
        width, height = image.size
        long_side = max(width, height)
        if long_side <= MAX_INPUT_LONG_SIDE:
            return image_path, 1.0
        scale = MAX_INPUT_LONG_SIDE / long_side
        resized = image.resize(
            (round(width * scale), round(height * scale)),
            Image.Resampling.LANCZOS,
        )
        import numpy as np

        return np.array(resized.convert("RGB")), 1.0 / scale
