"""OCR a FundLens regression screenshot into text+bbox lines.

The app screenshots are captured by screenshot_window.ps1; this script runs
PaddleOCR (already present in engine/.venv) on the image so the captured page
can be verified without a human looking at it. The content is rendered 2x with
LANCZOS first, because small Chinese UI text is otherwise missed.

Usage:
  engine/.venv/Scripts/python.exe docs/regression/scripts/ocr_page.py \
      docs/regression/screenshots/before-overview.png

Output: one line per recognized text box:
  x0 y0 x1 y1 score text
(stdout; coordinates are in the ORIGINAL image space)
"""

import sys

from PIL import Image

from paddleocr import PaddleOCR

_OCR = None


def _get_ocr() -> PaddleOCR:
    global _OCR
    if _OCR is None:
        # enable_mkldnn=False: PP-OCRv6 + paddlepaddle 3.3 has a oneDNN
        # converter crash (ConvertPirAttribute2RuntimeAttribute) on this box.
        _OCR = PaddleOCR(
            use_doc_orientation_classify=False,
            use_doc_unwarping=False,
            use_textline_orientation=False,
            lang="ch",
            enable_mkldnn=False,
        )
    return _OCR


def ocr_path(path: str, scale: float = 2.0) -> list[tuple[int, int, int, int, float, str]]:
    im = Image.open(path).convert("RGB")
    if scale != 1.0:
        im = im.resize(
            (int(im.width * scale), int(im.height * scale)), Image.LANCZOS
        )
    tmp = path + f".ocr{scale}x.png"
    im.save(tmp)
    res = _get_ocr().predict(tmp)
    pages = res if isinstance(res, list) else [res]
    out: list[tuple[int, int, int, int, float, str]] = []
    for page in pages:
        items = page if isinstance(page, list) else [page]
        for item in items:
            if not isinstance(item, dict):
                continue
            for text, score, poly in zip(
                item.get("rec_texts", []),
                item.get("rec_scores", []),
                item.get("rec_polys", []),
            ):
                xs = [pt[0] / scale for pt in poly]
                ys = [pt[1] / scale for pt in poly]
                out.append(
                    (
                        int(min(xs)),
                        int(min(ys)),
                        int(max(xs)),
                        int(max(ys)),
                        round(float(score), 3),
                        text,
                    )
                )
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    for path in sys.argv[1:]:
        lines = ocr_path(path)
        for x0, y0, x1, y1, score, text in sorted(lines, key=lambda r: (r[1], r[0])):
            print(f"{x0} {y0} {x1} {y1} {score} {text}")
        print(f"TOTAL {len(lines)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
