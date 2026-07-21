"""Generate synthetic OCR fixtures for parser acceptance tests.

Every image is drawn from a blank canvas with Pillow. All product names and
amounts are fictional. The script never reads any user screenshot or other
existing image; it only writes the two fixture PNGs under
``engine/tests/fixtures/ocr/``.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "engine" / "tests" / "fixtures" / "ocr"

FONT_CANDIDATES = [
    "C:/Windows/Fonts/msyh.ttc",
    "C:/Windows/Fonts/msyh.ttf",
    "C:/Windows/Fonts/simhei.ttf",
    "C:/Windows/Fonts/simsun.ttc",
    "C:/Windows/Fonts/Deng.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
    "/System/Library/Fonts/PingFang.ttc",
]


def find_cjk_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in FONT_CANDIDATES:
        if Path(candidate).is_file():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def draw(draw_obj: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, size: int = 28) -> None:
    draw_obj.text(xy, text, fill=(0, 0, 0), font=find_cjk_font(size))


def new_canvas(width: int = 800, height: int = 1280) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (width, height), (255, 255, 255))
    return image, ImageDraw.Draw(image)


def draw_status_bar(d: ImageDraw.ImageDraw) -> None:
    draw(d, (20, 12), "9:41", 24)
    draw(d, (700, 12), "100%", 24)


def draw_nav(d: ImageDraw.ImageDraw, labels: list[str]) -> None:
    x = 60
    for label in labels:
        draw(d, (x, 1200), label, 26)
        x += 150


def build_alipay(path: Path) -> None:
    image, d = new_canvas()
    draw_status_bar(d)
    draw(d, (360, 60), "基金", 30)

    draw(d, (40, 150), "脱敏安心债券A", 30)
    draw(d, (40, 200), "稳健理财 金选", 24)
    draw(d, (40, 260), "78,347.87", 32)
    draw(d, (40, 330), "持有收益", 24)
    draw(d, (220, 330), "+428.96", 24)
    draw(d, (420, 330), "累计收益", 24)
    draw(d, (600, 330), "+888.88", 24)

    draw(d, (40, 470), "脱敏远山混合C", 30)
    draw(d, (40, 560), "12,000.00", 32)
    draw(d, (40, 630), "持有收益", 24)
    draw(d, (220, 630), "-156.20", 24)
    draw(d, (420, 630), "累计收益", 24)
    draw(d, (600, 630), "+45.00", 24)

    draw(d, (40, 780), "收益曲线", 24)
    draw(d, (40, 1100), "尾号（8866）", 22)
    draw_nav(d, ["首页", "理财", "我的"])
    image.save(path)


def build_ths(path: Path) -> None:
    image, d = new_canvas()
    draw_status_bar(d)
    draw(d, (360, 60), "持仓", 30)

    header_x = [40, 240, 380, 520, 660]
    for x, label in zip(header_x, ["名称", "市值", "盈亏", "成本价", "持仓数量"]):
        draw(d, (x, 120), label, 24)

    rows = [
        ("脱敏先锋股票", "56,000.00", "+2,300.00", "53.700", "1000"),
        ("脱敏稳利ETF", "23,450.00", "-120.50", "2.3570", "10000"),
        ("脱敏长青混合", "9,800.00", "+0.00", "9.800", "1000"),
    ]
    for i, row in enumerate(rows):
        y = 200 + i * 100
        for x, cell in zip(header_x, row):
            draw(d, (x, y), cell, 24)

    for j, label in enumerate(["分时", "日K", "周K", "走势图"]):
        draw(d, (60 + j * 120, 540), label, 24)
    draw(d, (40, 1100), "资金账号 **6688", 22)
    draw_nav(d, ["首页", "行情", "自选", "交易", "我的"])
    image.save(path)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    alipay = OUT_DIR / "alipay_synthetic.png"
    ths = OUT_DIR / "ths_synthetic.png"
    build_alipay(alipay)
    build_ths(ths)
    print(f"wrote {alipay}")
    print(f"wrote {ths}")


if __name__ == "__main__":
    main()
