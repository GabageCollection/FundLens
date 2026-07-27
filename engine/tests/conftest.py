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
        """镜像支付宝「全部持有」真实版式：表头 + 每持仓四行（名称/标签/数值/占比）。"""
        return [
            # 状态栏（忽略）。
            tok("08:04", 0.99, 20, 12, 60, 24),
            tok("100%", 0.99, 700, 12, 70, 24),
            # 标题与排序控件（忽略）。
            tok("全部持有", 0.99, 120, 60, 130, 30),
            tok("收益明细", 0.99, 330, 60, 110, 30),
            tok("全部", 0.95, 40, 110, 60, 26),
            tok("金额/占比排序", 0.95, 400, 110, 180, 26),
            # 表头（列锚点）：列中心 100 / 345 / 515 / 705。
            tok("名称/金额", 0.97, 40, 160, 120, 26),
            tok("日收益", 0.97, 300, 160, 90, 26),
            tok("持有收益", 0.97, 460, 160, 110, 26),
            tok("累计收益", 0.97, 650, 160, 110, 26),
            # 持仓 1：名称 → 标签 → 数值 → 占比。
            tok("脱敏安心债券A", 0.97, 40, 220, 200, 32),
            tok("基金", 0.92, 40, 270, 60, 24),
            tok("稳健理财", 0.92, 120, 270, 110, 24),
            tok("78,347.87", 0.96, 40, 320, 180, 34),
            tok("0.00", 0.95, 300, 320, 80, 30),
            tok("+428.96", 0.95, 460, 320, 110, 30),
            tok("+888.88", 0.95, 650, 320, 110, 30),
            tok("占比 34.68%", 0.93, 40, 370, 130, 24),
            tok("+0.67%", 0.93, 460, 370, 90, 24),
            # 持仓 2：负收益，无标签行。
            tok("脱敏远山混合C", 0.97, 40, 430, 200, 32),
            tok("12,000.00", 0.96, 40, 480, 180, 34),
            tok("0.00", 0.95, 300, 480, 80, 30),
            tok("-156.20", 0.95, 460, 480, 110, 30),
            tok("+45.00", 0.95, 650, 480, 110, 30),
            tok("占比 5.30%", 0.93, 40, 530, 130, 24),
            # 底部导航（忽略）。
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
