"""PaddleOCR backend. Owns a single lazily constructed PaddleOCR instance."""

import logging
import os
from collections.abc import Callable
from typing import Any

from .backend import OcrToken
from .layout import is_money, is_ratio, normalize_text

# 贴图像左右边缘的数字 token 可能因检测框左右平移错位,在透视矫正时
# 被裁掉首尾字符(实测:1.879 → 1.87,置信度仍 1.0)。对这类 token
# 用扩大裁剪框二次识别补救。
EDGE_TOUCH_PX = 2
RESCUE_PAD_X = 60
RESCUE_PAD_Y = 10
RESCUE_MIN_SCORE = 0.85


def should_adopt_rescue(old_text: str, new_text: str, new_score: float) -> bool:
    """仅在「补回被裁字符」语义下采纳二次识别:旧文本须为新文本的严格子串。

    加宽框的重识别可能读出完全不同的内容或低质量结果,二者都拒绝。
    旧文本是数字/百分比时,新文本必须仍是同一形态,防止 1.87 → 1.87万。
    """
    if new_score < RESCUE_MIN_SCORE:
        return False
    old = normalize_text(old_text)
    new = normalize_text(new_text)
    if not old or not new or old == new or old not in new:
        return False
    if is_money(old) and not is_money(new):
        return False
    return not (is_ratio(old) and not is_ratio(new))


def rescue_edge_tokens(
    tokens: list[OcrToken],
    image_size: tuple[int, int],
    rec_fn: Callable[[tuple[int, int, int, int]], tuple[str, float] | None],
) -> list[OcrToken]:
    """对贴左右边缘的数字/百分比 token 做加宽框二次识别并按需替换。

    rec_fn 接收原图坐标系的 (x1, y1, x2, y2) 裁剪框,返回 (文本, 置信度),
    识别失败返回 None。其余 token 原样保留。
    """
    width, height = image_size
    rescued: list[OcrToken] = []
    for token in tokens:
        x, y, w, h = token.box
        touches_edge = x <= EDGE_TOUCH_PX or x + w >= width - EDGE_TOUCH_PX
        if not touches_edge or not (is_money(token.text) or is_ratio(token.text)):
            rescued.append(token)
            continue
        box = (
            max(0, x - max(RESCUE_PAD_X, w // 2)),
            max(0, y - RESCUE_PAD_Y),
            min(width, x + w + max(RESCUE_PAD_X, w // 2)),
            min(height, y + h + RESCUE_PAD_Y),
        )
        candidate = rec_fn(box)
        if candidate is None:
            rescued.append(token)
            continue
        new_text, new_score = candidate
        if should_adopt_rescue(token.text, new_text, new_score):
            logger.info(
                "edge rescue: %r -> %r (score %.3f)", token.text, new_text, new_score
            )
            rescued.append(
                OcrToken(
                    text=normalize_text(new_text),
                    confidence=new_score,
                    box=token.box,
                )
            )
        else:
            rescued.append(token)
    return rescued

logger = logging.getLogger("fundlens_engine")

# Screenshots larger than this on their long side are downscaled before
# inference: detection cost scales with pixels while the fund-app text stays
# comfortably legible at this size. Do not lower this: at 1600 the small
# colored digits of the THS positions page degrade beyond recognition
# (measured: '40.70' → '020' @0.24); at 2200 the same row reads ≥0.94 with
# negligible latency change (12.6s → 13.5s on CPU).
MAX_INPUT_LONG_SIDE = 2200


class PaddleBackend:
    def __init__(self) -> None:
        self._ocr: Any = None
        self._rec: Any = None

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
        return self._rescue(tokens, image_path)

    def _rescue(self, tokens: list[OcrToken], image_path: str) -> list[OcrToken]:
        """贴边缘数字 token 的加宽框二次识别;无候选 token 时不解码图像。"""
        from PIL import Image

        with Image.open(image_path) as probe:
            size = probe.size
        width, _height = size
        has_candidate = any(
            (
                t.box[0] <= EDGE_TOUCH_PX
                or t.box[0] + t.box[2] >= width - EDGE_TOUCH_PX
            )
            and (is_money(t.text) or is_ratio(t.text))
            for t in tokens
        )
        if not has_candidate:
            return tokens

        import numpy as np

        with Image.open(image_path) as image:
            pixels = image.convert("RGB")

        def rec_fn(box: tuple[int, int, int, int]) -> tuple[str, float] | None:
            result = self._rec_instance().predict(input=np.array(pixels.crop(box)))
            for item in result:
                return (str(item["rec_text"]), float(item["rec_score"]))
            return None

        return rescue_edge_tokens(tokens, size, rec_fn)

    def _rec_instance(self) -> Any:
        if self._rec is None:
            from paddleocr import TextRecognition  # type: ignore[import-untyped]

            self._rec = TextRecognition(
                model_name="PP-OCRv5_mobile_rec",
            )
        return self._rec


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
