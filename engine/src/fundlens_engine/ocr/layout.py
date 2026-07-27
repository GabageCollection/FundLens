"""Shared layout and text helpers for the Alipay and Tonghuashun parsers."""

import re
from collections.abc import Iterable
from dataclasses import dataclass

from ..models import OcrField
from .backend import DraftRow, OcrIssue, OcrToken

# Tokens whose vertical center sits above this line are phone status-bar noise.
STATUS_BAR_MAX_Y = 48

NAV_LABELS = {
    "首页",
    "理财",
    "我的",
    "行情",
    "自选",
    "交易",
    "持仓",
    "持有",
    "详情",
    "收益明细",
    "买入",
    "卖出",
    "撤单",
    "查询",
    "持仓股",
    "全部",
    "全部持有",
    "金额/占比排序",
    "资讯",
}

CHART_KEYWORDS = ("走势", "曲线", "分时", "日K", "周K", "月K", "K线")

ACCOUNT_RE = re.compile(r"(\*\s*\*?\s*\d+|尾号|资金账号|账号)")

TIME_RE = re.compile(r"^\d{1,2}:\d{2}$")

QUOTE_TICK_RE = re.compile(r"(最新|额|换)[:：]")

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
    if TIME_RE.match(normalize_text(text)):
        return True
    if QUOTE_TICK_RE.search(text):
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


@dataclass
class ColumnLayout:
    """表头锚定的列区间。boundaries[i] = [left, right) 对应 names[i]。"""

    names: list[str]
    boundaries: list[tuple[int, int]]

    def column_of(self, token: OcrToken) -> str | None:
        """按 token 中心 x 返回所属列名；落不进任何列返回 None。"""
        center = token.box[0] + token.box[2] // 2
        for name, (left, right) in zip(self.names, self.boundaries):
            if left <= center < right:
                return name
        return None


def anchor_columns(
    lines: list[list[OcrToken]], anchors: dict[str, set[str]]
) -> tuple[ColumnLayout, int] | None:
    """找到包含全部锚点组的表头行并构建列区间。

    anchors: 列语义名 -> 可接受的表头文本集合（任取其一）。
    返回 (列布局, 表头行下标)；找不到返回 None。
    """
    for index, line in enumerate(lines):
        texts = {t.text.strip() for t in line}
        if not all(texts & accepted for accepted in anchors.values()):
            continue
        centers: list[tuple[str, int]] = []
        for name, accepted in anchors.items():
            token = next(t for t in line if t.text.strip() in accepted)
            centers.append((name, token.box[0] + token.box[2] // 2))
        centers.sort(key=lambda item: item[1])
        names = [name for name, _ in centers]
        xs = [x for _, x in centers]
        boundaries: list[tuple[int, int]] = []
        for i, x in enumerate(xs):
            left = 0 if i == 0 else (xs[i - 1] + x) // 2
            right = 1 << 30 if i == len(xs) - 1 else (x + xs[i + 1]) // 2
            boundaries.append((left, right))
        return ColumnLayout(names, boundaries), index
    return None


def layout_unknown_row(page_index: int, detail: str) -> DraftRow:
    """页级 blocking 行：表头缺失时占位，字段为空，只带 layout_unknown issue。"""
    row = DraftRow(page_index=page_index)
    row.issues.append(
        OcrIssue(
            code="ocr.layout_unknown",
            field="",
            severity="blocking",
            message=f"未找到表头锚点，版式不支持：{detail}",
        )
    )
    return row
