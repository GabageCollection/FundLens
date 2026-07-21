"""Shared layout and text helpers for the Alipay and Tonghuashun parsers."""

import re
from collections.abc import Iterable

from ..models import OcrField
from .backend import OcrToken

# Tokens whose vertical center sits above this line are phone status-bar noise.
STATUS_BAR_MAX_Y = 48

NAV_LABELS = {
    "首页",
    "理财",
    "基金",
    "我的",
    "行情",
    "自选",
    "交易",
    "持仓",
    "持有",
    "详情",
    "收益明细",
}

CHART_KEYWORDS = ("走势", "曲线", "分时", "日K", "周K", "月K", "K线")

ACCOUNT_RE = re.compile(r"(\*\s*\*?\s*\d+|尾号|资金账号|账号)")

MONEY_RE = re.compile(r"^[+＋\-－]?[\d,，]*\d(?:[\.．]\d+)?$")

SIGNED_RE = re.compile(r"^[+＋\-－]")

RATIO_RE = re.compile(r"^[+＋\-－]?[\d\.．]+%$")

FULL_WIDTH = str.maketrans(
    "０１２３４５６７８９＋－．，％　",
    "0123456789+-.,% ",
)


def normalize_text(text: str) -> str:
    """Normalize full-width digits and punctuation; keep half-width as-is."""
    return text.translate(FULL_WIDTH).strip()


def is_money(text: str) -> bool:
    return bool(MONEY_RE.match(normalize_text(text)))


def is_signed(text: str) -> bool:
    return bool(SIGNED_RE.match(normalize_text(text)))


def is_ratio(text: str) -> bool:
    return bool(RATIO_RE.match(normalize_text(text)))


def is_noise(token: OcrToken) -> bool:
    """Status bar, account suffix, chart and navigation tokens are never parsed."""
    x, y, _w, h = token.box
    if y + h // 2 < STATUS_BAR_MAX_Y:
        return True
    text = token.text.strip()
    if text in NAV_LABELS:
        return True
    if any(keyword in text for keyword in CHART_KEYWORDS):
        return True
    return bool(ACCOUNT_RE.search(text))


def group_into_lines(tokens: Iterable[OcrToken], y_tolerance: int = 18) -> list[list[OcrToken]]:
    """Group tokens into horizontal lines by vertical center."""
    ordered = sorted(tokens, key=lambda t: (t.box[1] + t.box[3] // 2, t.box[0]))
    lines: list[list[OcrToken]] = []
    centers: list[int] = []
    for token in ordered:
        center = token.box[1] + token.box[3] // 2
        if lines and abs(center - centers[-1]) <= y_tolerance:
            lines[-1].append(token)
        else:
            lines.append([token])
            centers.append(center)
    for line in lines:
        line.sort(key=lambda t: t.box[0])
    return lines


def union_crop(tokens: Iterable[OcrToken]) -> tuple[int, int, int, int]:
    boxes = [t.box for t in tokens]
    left = min(b[0] for b in boxes)
    top = min(b[1] for b in boxes)
    right = max(b[0] + b[2] for b in boxes)
    bottom = max(b[1] + b[3] for b in boxes)
    return (left, top, right - left, bottom - top)


def make_field(name: str, tokens: list[OcrToken], page_index: int) -> OcrField:
    return OcrField(
        name=name,
        raw_text=" ".join(t.text for t in tokens),
        confidence=min(t.confidence for t in tokens),
        page_index=page_index,
        crop=union_crop(tokens),
    )
