"""Alipay holdings parser: header-anchored columns + row state machine.

每个持仓固定四行结构：名称 → 标签（可缺）→ 数值（按列拆分）→ 占比（忽略）。
字段归属只看列区间，与行内 token 顺序无关。符号只来自显式 +/− 字符。
"""

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
    "value": {"名称/金额", "名称"},
    "daily": {"日收益"},
    "holding": {"持有收益"},
    "cumulative": {"累计收益"},
}

REQUIRED_FIELDS = ("product_name", "current_value")
NAME_THRESHOLD = 0.85
AMOUNT_THRESHOLD = 0.90
TAG_THRESHOLD = 0.70

_NUMBER_SLOTS = {
    "value": "current_value",
    "holding": "holding_profit",
    "cumulative": "cumulative_profit",
}


def _assign_numbers(
    row: DraftRow, layout: ColumnLayout, line: list[OcrToken], page_index: int
) -> None:
    """把数值行的 money token 按列归入字段；日收益列与列外 token 丢弃。"""
    for token in (t for t in line if is_money(t.text)):
        field_name = _NUMBER_SLOTS.get(layout.column_of(token) or "")
        if field_name is None:
            continue
        if field_name in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.extra_token",
                    field=field_name,
                    severity="warning",
                    message=f"列内多余数字 token {token.text!r} 已忽略",
                )
            )
            continue
        row.fields[field_name] = make_field(field_name, [token], page_index)


def _add_confidence_issues(row: DraftRow) -> None:
    for name, field in row.fields.items():
        if name == "product_name":
            threshold, severity = NAME_THRESHOLD, "blocking"
        elif name == "platform_tags":
            threshold, severity = TAG_THRESHOLD, "warning"
        else:
            threshold, severity = AMOUNT_THRESHOLD, "blocking"
        if field.confidence < threshold:
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
    for name in ("holding_profit", "cumulative_profit"):
        field = row.fields.get(name)
        if field is not None and not is_signed(field.raw_text):
            row.issues.append(
                OcrIssue(
                    code="ocr.sign_missing",
                    field=name,
                    severity="blocking",
                    message=f"field {name} has no explicit +/− sign",
                )
            )
    _add_confidence_issues(row)


def _is_garbled_fragment(row: DraftRow) -> bool:
    """截图底部截断的 OCR 碎块：名称低置信乱码且没有任何数值字段。

    这类碎块不是可读持仓（数值根本不在截图里），生成阻断行只会逼用户
    每次手动删除。名称清晰但数值缺失的行不属于此类——数值可能真被截断，
    必须保留阻断由人工确认。
    """
    name = row.fields.get("product_name")
    has_numbers = any(field in row.fields for field in _NUMBER_SLOTS.values())
    return name is not None and not has_numbers and name.confidence < NAME_THRESHOLD


def parse_alipay(tokens: list[OcrToken], page_index: int = 0) -> list[DraftRow]:
    lines = group_into_lines(t for t in tokens if not is_noise(t))
    anchored = anchor_columns(lines, ANCHORS)
    if anchored is None:
        return [layout_unknown_row(page_index, "名称/金额、日收益、持有收益、累计收益")]
    layout, header_index = anchored

    rows: list[DraftRow] = []
    current: DraftRow | None = None
    state = "name"  # name -> tags -> numbers -> ratio -> name ...

    for line in lines[header_index + 1 :]:
        money = [t for t in line if is_money(t.text)]
        texts = [t for t in line if not is_money(t.text) and not is_ratio(t.text)]
        ratio_line = any(t.text.strip().startswith("占比") for t in line)

        if state == "tags":
            if texts and not money and not ratio_line:
                assert current is not None
                current.fields["platform_tags"] = make_field(
                    "platform_tags", texts, page_index
                )
                continue
            state = "numbers"  # 标签行可缺

        if state == "numbers":
            if money:
                assert current is not None
                _assign_numbers(current, layout, line, page_index)
                state = "ratio"
                continue
            state = "ratio"

        # state 为 name 或 ratio：文本行开启新持仓，占比行与零散数字行忽略
        if texts and not money and not ratio_line:
            current = DraftRow(page_index=page_index)
            rows.append(current)
            current.fields["product_name"] = make_field("product_name", texts, page_index)
            state = "tags"

    rows = [row for row in rows if not _is_garbled_fragment(row)]
    for row in rows:
        _finalize(row)
    return rows
