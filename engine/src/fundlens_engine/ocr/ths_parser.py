"""Tonghuashun (同花顺) holdings table parser.

Each non-header line of the positions table is one holding. Signs come only
from explicit +/− characters, never from color.
"""

from .backend import DraftRow, OcrIssue, OcrToken
from .layout import (
    group_into_lines,
    is_money,
    is_noise,
    is_ratio,
    is_signed,
    make_field,
)

NAME_THRESHOLD = 0.85
AMOUNT_THRESHOLD = 0.90
RATIO_THRESHOLD = 0.70

HEADER_LABELS = {"名称", "市值", "盈亏", "成本价", "持仓数量"}
NUMERIC_SLOTS = ("current_value", "cost_price", "quantity")


def _is_header(line: list[OcrToken]) -> bool:
    texts = {t.text.strip() for t in line}
    return "名称" in texts and "市值" in texts


def _finalize(row: DraftRow) -> None:
    for name in ("product_name", "current_value", "holding_profit", "cost_price", "quantity"):
        if name not in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.field_missing",
                    field=name,
                    severity="blocking",
                    message=f"required field {name} missing",
                )
            )
    profit = row.fields.get("holding_profit")
    if profit is not None and not is_signed(profit.raw_text):
        row.issues.append(
            OcrIssue(
                code="ocr.sign_missing",
                field="holding_profit",
                severity="blocking",
                message="field holding_profit has no explicit +/− sign",
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
            severity = "warning" if name == "profit_ratio" else "blocking"
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
    lines = group_into_lines(t for t in tokens if not is_noise(t))
    rows: list[DraftRow] = []

    for line in lines:
        if _is_header(line):
            continue
        names = [t for t in line if not is_money(t.text) and not is_ratio(t.text)]
        ratios = [t for t in line if is_ratio(t.text)]
        signed = [t for t in line if is_money(t.text) and is_signed(t.text)]
        plain = [t for t in line if is_money(t.text) and not is_signed(t.text)]
        if not names or not plain:
            continue

        row = DraftRow(page_index=page_index)
        row.fields["product_name"] = make_field("product_name", names, page_index)
        if signed:
            row.fields["holding_profit"] = make_field("holding_profit", [signed[0]], page_index)
        if ratios:
            row.fields["profit_ratio"] = make_field("profit_ratio", [ratios[0]], page_index)
        for name, token in zip(NUMERIC_SLOTS, plain):
            row.fields[name] = make_field(name, [token], page_index)
        _finalize(row)
        rows.append(row)

    return rows
