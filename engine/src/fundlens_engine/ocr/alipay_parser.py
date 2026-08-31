"""Alipay holdings parser: header-anchored columns + row state machine.

每个持仓固定四行结构：名称 → 标签（可缺）→ 数值（按列拆分）→ 占比（忽略）。
字段归属只看列区间，与行内 token 顺序无关。符号只来自显式 +/− 字符。
截图未含表头时按支付宝固定列序（金额/日收益/持有收益/累计收益）聚类推断
列区间，并附 warning 提醒人工核对。
"""

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

# 支付宝列序固定:金额 → 日收益 → 持有收益 → 累计收益。
_INFERRED_COLUMNS = ("value", "daily", "holding", "cumulative")

# 同列数值 token 的 x 中心抖动(数字右对齐、位数不同)远小于列间距;
# 相邻 x 中心差超过该像素即视为跨列。
_INFER_COLUMN_GAP = 80


def _infer_layout(lines: list[list[OcrToken]]) -> ColumnLayout | None:
    """表头缺失时按支付宝固定列序推断列区间。

    聚类所有数值 token 的 x 中心：同列接近、列间间隔大。恰好聚出 4 列时
    从左到右固定映射为 金额/日收益/持有收益/累计收益；聚不出 4 列说明
    版式无法辨认，交给上层 layout_unknown 阻断。
    """
    xs = sorted(
        token.box[0] + token.box[2] // 2 for line in lines for token in line if is_money(token.text)
    )
    if len(xs) < len(_INFERRED_COLUMNS):
        return None
    clusters: list[list[int]] = [[xs[0]]]
    for x in xs[1:]:
        center = sum(clusters[-1]) // len(clusters[-1])
        if x - center <= _INFER_COLUMN_GAP:
            clusters[-1].append(x)
        else:
            clusters.append([x])
    if len(clusters) != len(_INFERRED_COLUMNS):
        return None
    centers = [sum(cluster) // len(cluster) for cluster in clusters]
    boundaries: list[tuple[int, int]] = []
    for i, x in enumerate(centers):
        left = 0 if i == 0 else (centers[i - 1] + x) // 2
        right = 1 << 30 if i == len(centers) - 1 else (x + centers[i + 1]) // 2
        boundaries.append((left, right))
    return ColumnLayout(list(_INFERRED_COLUMNS), boundaries)


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
                    message=f"这一行识别到多余的数字「{token.text}」，已自动忽略",
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
                        f"{field_label(name)}识别不太确定"
                        f"（可信度约 {field.confidence:.0%}），请仔细核对"
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
                    message=f"没有识别出{field_label(name)}，请手动补填",
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
                    message=f"{field_label(name)}没有识别到正负号，请确认是盈利还是亏损",
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
    layout_inferred = False
    if anchored is not None:
        layout, header_index = anchored
        body = lines[header_index + 1 :]
    else:
        # 截图只截了列表中段、没含表头:按固定列序推断列区间,照常解析。
        inferred = _infer_layout(lines)
        if inferred is None:
            return [layout_unknown_row(page_index, "名称/金额、日收益、持有收益、累计收益")]
        layout = inferred
        body = lines
        layout_inferred = True

    rows: list[DraftRow] = []
    current: DraftRow | None = None
    state = "name"  # name -> tags -> numbers -> ratio -> name ...

    for line in body:
        money = [t for t in line if is_money(t.text)]
        texts = [t for t in line if not is_money(t.text) and not is_ratio(t.text)]
        ratio_line = any(t.text.strip().startswith("占比") for t in line)

        if state == "tags":
            if texts and not money and not ratio_line:
                assert current is not None
                current.fields["platform_tags"] = make_field("platform_tags", texts, page_index)
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
    if layout_inferred and rows:
        rows[0].issues.append(
            OcrIssue(
                code="ocr.layout_inferred",
                field="",
                severity="warning",
                message="没有识别到列表表头，已按支付宝默认列顺序"
                "（金额/日收益/持有收益/累计收益）推断，请核对各列金额是否对得上",
            )
        )
    return rows
