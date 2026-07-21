"""Shared fixtures for OCR parser and service tests.

All tokens are synthetic fake OCR output; no test loads PaddleOCR or opens a
network/TCP connection. Token layouts mirror the generated fixture images.
"""

from pathlib import Path

import pytest

from fundlens_engine.ocr.backend import OcrToken

FIXTURE_DIR = Path(__file__).parent / "fixtures" / "ocr"


def tok(text: str, conf: float, x: int, y: int, w: int = 120, h: int = 30) -> OcrToken:
    return OcrToken(text=text, confidence=conf, box=(x, y, w, h))


class FakeOcrTokens:
    """Builds deterministic fake token pages for each template."""

    def alipay_page(self) -> list[OcrToken]:
        return [
            # Status bar (must be ignored).
            tok("9:41", 0.99, 20, 12, 60, 24),
            tok("100%", 0.99, 700, 12, 70, 24),
            # Title (navigation label, ignored).
            tok("基金", 0.99, 360, 60),
            # Holding 1.
            tok("脱敏安心债券A", 0.97, 40, 150, 200, 32),
            tok("稳健理财", 0.92, 40, 200, 110, 26),
            tok("金选", 0.72, 170, 200, 60, 26),
            tok("78,347.87", 0.96, 40, 260, 180, 34),
            tok("持有收益", 0.95, 40, 330, 110, 26),
            tok("+428.96", 0.95, 220, 330, 110, 26),
            tok("累计收益", 0.95, 420, 330, 110, 26),
            tok("+888.88", 0.95, 600, 330, 110, 26),
            # Holding 2.
            tok("脱敏远山混合C", 0.97, 40, 470, 200, 32),
            tok("12,000.00", 0.96, 40, 560, 180, 34),
            tok("持有收益", 0.95, 40, 630, 110, 26),
            tok("-156.20", 0.95, 220, 630, 110, 26),
            tok("累计收益", 0.95, 420, 630, 110, 26),
            tok("+45.00", 0.95, 600, 630, 110, 26),
            # Chart label, account suffix, navigation (all ignored).
            tok("收益曲线", 0.90, 40, 780, 110, 26),
            tok("尾号（8866）", 0.90, 40, 1100, 150, 24),
            tok("首页", 0.98, 60, 1200, 70, 26),
            tok("理财", 0.98, 300, 1200, 70, 26),
            tok("我的", 0.98, 560, 1200, 70, 26),
        ]

    def ths_page(self) -> list[OcrToken]:
        tokens = [
            tok("9:41", 0.99, 20, 12, 60, 24),
            tok("100%", 0.99, 700, 12, 70, 24),
            tok("持仓", 0.99, 360, 60),
        ]
        header_x = [40, 240, 380, 520, 660]
        for x, label in zip(header_x, ["名称", "市值", "盈亏", "成本价", "持仓数量"]):
            tokens.append(tok(label, 0.97, x, 120, 90, 26))
        rows = [
            ("脱敏先锋股票", "56,000.00", "+2,300.00", "53.700", "1000"),
            ("脱敏稳利ETF", "23,450.00", "-120.50", "2.3570", "10000"),
            ("脱敏长青混合", "9,800.00", "+0.00", "9.800", "1000"),
        ]
        for i, row in enumerate(rows):
            y = 200 + i * 100
            for x, cell in zip(header_x, row):
                tokens.append(tok(cell, 0.95, x, y, 130, 28))
        # Chart labels, account suffix, navigation (all ignored).
        for j, label in enumerate(["分时", "日K", "周K", "走势图"]):
            tokens.append(tok(label, 0.90, 60 + j * 120, 540, 80, 26))
        tokens.append(tok("资金账号 **6688", 0.90, 40, 1100, 180, 24))
        for j, label in enumerate(["首页", "行情", "自选", "交易", "我的"]):
            tokens.append(tok(label, 0.98, 60 + j * 140, 1200, 70, 26))
        return tokens


@pytest.fixture
def fake_ocr_tokens() -> FakeOcrTokens:
    return FakeOcrTokens()
