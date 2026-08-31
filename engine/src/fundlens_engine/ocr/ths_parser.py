"""Tonghuashun (同花顺) holdings parser: header-anchored columns + two-line merge.

每个持仓两行：第一行 名称/盈亏/持仓/成本，第二行 市值/盈亏%/可用/现价。
内嵌分时图噪声通过整行剔除「最新」行情行与严格的行模式门禁消除。
无符号的盈亏/盈亏% 按列语义视为正数并附 warning，由人工确认把关。
滚动截屏的续页通常没有表头：调用方传入上一页的 fallback_layout 即可
按相同列位置继续识别，此类行附 info 级 layout_inherited 提示人工核对。
"""

import re

from .backend import DraftRow, OcrIssue, OcrToken, field_label
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


def _is_damaged_line1(layout: ColumnLayout, line: list[OcrToken]) -> bool:
    """名称区损坏的第一行：盈亏/持仓/成本三列同时有金额 token。

    图表轴标签只占 value/cost 边缘列且右侧是百分比、行情摘要行已整行剔除，
    三列同现金额在正常版式里只可能是持仓第一行。孤立的第二行（profit 列
    是百分比而非金额）不满足该门，不会被误捞。
    """
    slots = {layout.column_of(t) for t in line if is_money(t.text)}
    return set(_LINE1_SLOTS) <= slots


def _drop_quote_lines(tokens: list[OcrToken], y_tolerance: int = 18) -> list[OcrToken]:
    """剔除「最新:…」行情摘要锚点所在的整行（含同行的 额/换/行情 碎块）。

    必须在 is_noise 过滤之前调用——「最新」锚点本身也是噪声词，
    先过滤噪声会丢掉锚点，导致同行残留的数字/百分比 token 泄漏。

    容差与 group_into_lines 一样随 token 高度自适应：大图下 OCR 会把同一
    视觉行拆成高度不一的碎片，中心偏移可超过固定 18px。
    """
    anchors = [t for t in tokens if t.text.strip().startswith("最新")]
    if not anchors:
        return tokens

    def on_quote_line(token: OcrToken) -> bool:
        center = token.box[1] + token.box[3] // 2
        return any(
            abs(center - (a.box[1] + a.box[3] // 2))
            <= max(y_tolerance, a.box[3] // 2 + token.box[3] // 2)
            for a in anchors
        )

    return [t for t in tokens if not on_quote_line(t)]


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
                    message=f"没有识别出{field_label(name)}，请手动补填",
                )
            )
    for name in OPTIONAL_FIELDS:
        if name not in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.field_missing",
                    field=name,
                    severity="warning",
                    message=f"没有识别出{field_label(name)}（不影响导入），如需要可手动补填",
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
                    message=f"{field_label(name)}没有识别到正负号，已按正数处理，请确认",
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
                        f"{field_label(name)}识别不太确定"
                        f"（可信度约 {field.confidence:.0%}），请仔细核对"
                    ),
                )
            )


def _prepare_lines(tokens: list[OcrToken]) -> list[list[OcrToken]]:
    cleaned = [t for t in _drop_quote_lines(tokens) if not is_noise(t)]
    return group_into_lines(cleaned)


def ths_column_layout(tokens: list[OcrToken]) -> ColumnLayout | None:
    """从单页 token 中提取表头锚定的列布局；本页无表头返回 None。

    供调用方跨页传递：滚动截屏的续页没有表头，需沿用上一页的列位置。
    """
    anchored = anchor_columns(_prepare_lines(tokens), ANCHORS)
    return None if anchored is None else anchored[0]


def parse_ths(
    tokens: list[OcrToken],
    page_index: int = 0,
    fallback_layout: ColumnLayout | None = None,
) -> list[DraftRow]:
    lines = _prepare_lines(tokens)
    anchored = anchor_columns(lines, ANCHORS)
    inherited = False
    if anchored is None:
        if fallback_layout is None:
            return [layout_unknown_row(page_index, "市值、盈亏、持仓/可用、成本/现价")]
        # 续页无表头：沿用上一页列布局，从第 0 行开始扫描（页首常是上一
        # 持仓的分时图尾部，纯轴标签无名称 token，不会生成幻影持仓）。
        layout, header_index = fallback_layout, -1
        inherited = True
    else:
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
            if names and has_numbers:
                pending = DraftRow(page_index=page_index)
                rows.append(pending)
                pending.fields["product_name"] = make_field("product_name", names, page_index)
                _assign_line1(pending, layout, line, page_index)
                continue
            if not names and _is_damaged_line1(layout, line):
                # 名称区 OCR 损坏的持仓行：数字按列归位，product_name 缺失
                # 由 _finalize 的 blocking 提示人工补填，不静默丢持仓。
                pending = DraftRow(page_index=page_index)
                rows.append(pending)
                _assign_line1(pending, layout, line, page_index)
                continue
            continue  # 图表残片、导航图标碎块（有汉字但零数字）、空行

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
    if inherited:
        for row in rows:
            row.issues.append(
                OcrIssue(
                    code="ocr.layout_inherited",
                    field="",
                    severity="info",
                    message="本页未识别到列表表头，已沿用上一页的列位置识别，请人工核对",
                )
            )
    return rows
