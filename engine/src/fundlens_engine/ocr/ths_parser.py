"""Tonghuashun (同花顺) holdings parser: header-anchored columns + two-line merge.

每个持仓两行：第一行 名称/盈亏/持仓/成本，第二行 市值/盈亏%/可用/现价。
内嵌分时图噪声通过整行剔除「最新」行情行与严格的行模式门禁消除。
无符号的盈亏/盈亏% 按列语义视为正数并附 warning，由人工确认把关。
"""

import re

from .backend import DraftRow, OcrIssue, OcrToken
from .layout import (
    ColumnLayout,
    anchor_columns,
    group_into_lines,
    is_money,
    is_noise,
    is_ratio,
    is_signed,
    layout_unknown_row,
    make_field,
)

ANCHORS = {
    "value": {"市值"},
    "profit": {"盈亏"},
    "quantity": {"持仓/可用", "持仓"},
    "cost": {"成本/现价", "成本"},
}

REQUIRED_FIELDS = ("product_name", "current_value", "holding_profit", "cost_price", "quantity")
OPTIONAL_FIELDS = ("profit_ratio", "latest_price")

NAME_THRESHOLD = 0.85
AMOUNT_THRESHOLD = 0.90
RATIO_THRESHOLD = 0.70

_LINE1_SLOTS = {"profit": "holding_profit", "quantity": "quantity", "cost": "cost_price"}


def _drop_quote_lines(tokens: list[OcrToken], y_tolerance: int = 18) -> list[OcrToken]:
    """剔除「最新:…」行情摘要锚点所在的整行（含同行的 额/换/行情 碎块）。

    必须在 is_noise 过滤之前调用——「最新」锚点本身也是噪声词，
    先过滤噪声会丢掉锚点，导致同行残留的数字/百分比 token 泄漏。
    """
    anchors = [t for t in tokens if t.text.strip().startswith("最新")]
    if not anchors:
        return tokens
    centers = [t.box[1] + t.box[3] // 2 for t in anchors]
    return [
        t
        for t in tokens
        if all(abs(t.box[1] + t.box[3] // 2 - c) > y_tolerance for c in centers)
    ]


_ANCHOR_RE = re.compile(r"[一-鿿A-Za-z]")


def _name_tokens(layout: ColumnLayout, line: list[OcrToken]) -> list[OcrToken]:
    """名称 token：首列文本，且至少含一个中日韩字符或字母。

    坐标轴虚线带出的尾点数字已按 money 分类；'-'、'•'、'□' 这类
    纯符号碎块在这里被进一步挡掉，避免生成幻影持仓。
    """
    return [
        t
        for t in line
        if layout.column_of(t) == "value"
        and not is_money(t.text)
        and not is_ratio(t.text)
        and _ANCHOR_RE.search(t.text)
    ]


def _assign_line1(
    row: DraftRow, layout: ColumnLayout, line: list[OcrToken], page_index: int
) -> None:
    for token in (t for t in line if is_money(t.text)):
        field_name = _LINE1_SLOTS.get(layout.column_of(token) or "")
        if field_name is None or field_name in row.fields:
            continue
        row.fields[field_name] = make_field(field_name, [token], page_index)


def _assign_line2(
    row: DraftRow, layout: ColumnLayout, line: list[OcrToken], page_index: int
) -> None:
    for token in line:
        column = layout.column_of(token)
        if column == "value" and is_money(token.text) and "current_value" not in row.fields:
            row.fields["current_value"] = make_field("current_value", [token], page_index)
        elif column == "profit" and is_ratio(token.text) and "profit_ratio" not in row.fields:
            row.fields["profit_ratio"] = make_field("profit_ratio", [token], page_index)
        elif column == "cost" and is_money(token.text) and "latest_price" not in row.fields:
            row.fields["latest_price"] = make_field("latest_price", [token], page_index)
        # quantity 列第二行是可用数量，丢弃


def _finalize(row: DraftRow) -> None:
    for name in REQUIRED_FIELDS:
        if name not in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.field_missing",
                    field=name,
                    severity="blocking",
                    message=f"required field {name} missing",
                )
            )
    for name in OPTIONAL_FIELDS:
        if name not in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.field_missing",
                    field=name,
                    severity="warning",
                    message=f"optional field {name} missing",
                )
            )
    for name in ("holding_profit", "profit_ratio"):
        field = row.fields.get(name)
        if field is not None and not is_signed(field.raw_text):
            row.issues.append(
                OcrIssue(
                    code="ocr.sign_assumed_positive",
                    field=name,
                    severity="warning",
                    message=f"field {name} 无显式符号，按列语义视为正数，请人工确认",
                )
            )
    for name, field in row.fields.items():
        if name == "product_name":
            threshold = NAME_THRESHOLD
        elif name == "profit_ratio":
            threshold = RATIO_THRESHOLD
        else:
            threshold = AMOUNT_THRESHOLD
        if field.confidence < threshold:
            severity = "warning" if name in OPTIONAL_FIELDS else "blocking"
            row.issues.append(
                OcrIssue(
                    code="ocr.low_confidence",
                    field=name,
                    severity=severity,  # type: ignore[arg-type]
                    message=(
                        f"field {name} confidence {field.confidence:.2f} "
                        f"below threshold {threshold:.2f}"
                    ),
                )
            )


def parse_ths(tokens: list[OcrToken], page_index: int = 0) -> list[DraftRow]:
    cleaned = [t for t in _drop_quote_lines(tokens) if not is_noise(t)]
    lines = group_into_lines(cleaned)
    anchored = anchor_columns(lines, ANCHORS)
    if anchored is None:
        return [layout_unknown_row(page_index, "市值、盈亏、持仓/可用、成本/现价")]
    layout, header_index = anchored

    rows: list[DraftRow] = []
    pending: DraftRow | None = None
    index = header_index + 1
    while index < len(lines):
        line = lines[index]
        index += 1
        names = _name_tokens(layout, line)

        if pending is None:
            has_numbers = any(is_money(t.text) for t in line)
            if not names or not has_numbers:
                continue  # 图表残片、导航图标碎块（有汉字但零数字）、空行
            pending = DraftRow(page_index=page_index)
            rows.append(pending)
            pending.fields["product_name"] = make_field("product_name", names, page_index)
            _assign_line1(pending, layout, line, page_index)
            continue

        value_tokens = [t for t in line if layout.column_of(t) == "value" and is_money(t.text)]
        ratio_tokens = [t for t in line if layout.column_of(t) == "profit" and is_ratio(t.text)]
        if value_tokens and ratio_tokens:
            _assign_line2(pending, layout, line, page_index)
            _finalize(pending)
            pending = None
            continue

        # 第二行缺失：当前行可能是下一个持仓的第一行
        _finalize(pending)
        pending = None
        if names:
            index -= 1  # 重新按第一行处理

    if pending is not None:
        _finalize(pending)
    return rows
