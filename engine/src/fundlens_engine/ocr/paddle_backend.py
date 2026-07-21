"""PaddleOCR backend. Owns a single lazily constructed PaddleOCR instance."""

import logging
from typing import Any

from .backend import OcrToken

logger = logging.getLogger("fundlens_engine")


class PaddleBackend:
    def __init__(self) -> None:
        self._ocr: Any = None

    def _instance(self) -> Any:
        if self._ocr is None:
            from paddleocr import PaddleOCR  # type: ignore[import-untyped]

            logger.info("initializing PaddleOCR")
            self._ocr = PaddleOCR(use_textline_orientation=True, lang="ch")
        return self._ocr

    def recognize(self, image_path: str) -> list[OcrToken]:
        results = self._instance().predict(input=image_path)
        tokens: list[OcrToken] = []
        for result in results:
            texts = result["rec_texts"]
            scores = result["rec_scores"]
            boxes = result["rec_boxes"]
            for text, score, box in zip(texts, scores, boxes):
                x1, y1, x2, y2 = (int(v) for v in box)
                tokens.append(
                    OcrToken(
                        text=str(text),
                        confidence=float(score),
                        box=(x1, y1, max(0, x2 - x1), max(0, y2 - y1)),
                    )
                )
        return tokens
