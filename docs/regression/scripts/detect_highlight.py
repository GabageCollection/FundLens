"""Detect the y position of the selected sidebar nav item in a FundLens
baseline screenshot.

The baseline (pre-redesign) sidebar highlights the active nav item with an
indigo band (~RGB 85,80,182). This script scans the left 230px of the window
for that band and prints its vertical center in window pixels, so the click
driver can self-calibrate:

  click_y' = click_y + (target_nav_y - highlight_y)

Usage:
  engine/.venv/Scripts/python.exe docs/regression/scripts/detect_highlight.py IMG [indigo|warm]

Styles:
  indigo - baseline build (Graphite/Indigo theme), selected item is indigo
  warm   - redesigned build (Open Design warm-ink theme #B65233)
Default: auto (try indigo first, then warm).
"""

import sys

from PIL import Image


def _indigo(r: int, g: int, b: int) -> bool:
    return b > 140 and r < 140 and g < 120 and b > r + 60


def _warm(r: int, g: int, b: int) -> bool:
    return r > 140 and g < 110 and b < 110 and r > g + 40 and r > b + 40


def detect_highlight_y(path: str, style: str | None = None) -> int | None:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    side = im.crop((0, 0, min(230, w), h))
    styles = [style] if style else ["indigo", "warm"]
    for st in styles:
        pred = _indigo if st == "indigo" else _warm
        y = _detect(side, pred)
        if y is not None:
            return y
    return None


def _detect(side: Image.Image, pred) -> int | None:
    h = side.height
    rows: dict[int, int] = {}
    for y in range(h):
        count = 0
        for x in range(0, 230, 2):
            r, g, b = side.getpixel((x, y))
            if pred(r, g, b):
                count += 1
        if count >= 15:  # a band is a mostly-continuous colored row
            rows[y] = count
    if not rows:
        return None
    # contiguous runs -> choose the largest run's center
    best_start, best_len = 0, 0
    start, length = 0, 0
    ys = sorted(rows)
    prev = None
    for y in ys:
        if prev is not None and y - prev == 1:
            length += 1
        else:
            start, length = y, 1
        if length > best_len:
            best_start, best_len = start, length
        prev = y
    return best_start + best_len // 2


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: detect_highlight.py IMG [indigo|warm]", file=sys.stderr)
        return 2
    style = sys.argv[2] if len(sys.argv) > 2 else None
    y = detect_highlight_y(sys.argv[1], style)
    print(f"HIGHLIGHT_Y={y if y is not None else 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
