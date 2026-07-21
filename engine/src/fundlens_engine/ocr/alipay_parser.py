"""Alipay holdings screenshot parser.

Groups fake/real OCR tokens into holding blocks by vertical bands. Never
infers sign from color; signs come only from explicit +/− characters.
"""

from .backend import DraftRow, OcrIssue, OcrToken
from .layout import (
    group_into_lines,
    is_money,
    is_noise,
    is_signed,
    make_field,
)
PROFIT_LABELS = {"持有收益": "holding_profit", "累计收益": "cumulative_profit"}

REQUIRED_FIELDS = ("product_name", "current_value")
NAME_THRESHOLD = 0.85
AMOUNT_THRESHOLD = 0.90
TAG_THRESHOLD = 0.70


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


def parse_alipay(tokens: list[OcrToken], page_index: int = 0) -> list[DraftRow]:
    lines = group_into_lines(t for t in tokens if not is_noise(t))
    rows: list[DraftRow] = []
    current: DraftRow | None = None

    for line in lines:
        labels = [t for t in line if t.text.strip() in PROFIT_LABELS]
        money = [t for t in line if is_money(t.text)]
        texts = [t for t in line if t not in labels and t not in money]

        if labels:
            if current is None:
                continue
            # Pair each profit label with the money token to its right.
            for label in labels:
                value = next(
                    (t for t in money if t.box[0] > label.box[0]),
                    None,
                )
                if value is not None:
                    name = PROFIT_LABELS[label.text.strip()]
                    current.fields[name] = make_field(name, [value], page_index)
        elif texts and not money:
            if current is None or "current_value" in current.fields:
                current = DraftRow(page_index=page_index)
                rows.append(current)
                current.fields["product_name"] = make_field("product_name", texts, page_index)
            else:
                current.fields["platform_tags"] = make_field("platform_tags", texts, page_index)
        elif money and current is not None and "current_value" not in current.fields:
            current.fields["current_value"] = make_field("current_value", [money[0]], page_index)

    for row in rows:
        _finalize(row)
    return rows
