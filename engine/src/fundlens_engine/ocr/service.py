"""OCR normalization service and the ``ocr.parse_screenshots`` entry point.

Applies the financial consistency checks from the Phase 2 plan:

- 支付宝推算成本 = 当前金额 − 持有收益
- 同花顺推算成本 = 市值 − 盈亏金额
- 同花顺参考成本 = 成本价 × 持仓数量
- 容差 = max(CNY 1.00, abs(同花顺推算成本) × 0.001)

A Tonghuashun cost mismatch yields a blocking ``import.cost_mismatch`` issue;
neither cost is ever silently chosen.
"""

from dataclasses import asdict
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Literal

from .alipay_parser import parse_alipay
from .backend import DraftRow, OcrBackend, OcrIssue
from .layout import normalize_text
from .ths_parser import parse_ths

IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}

Template = Literal["alipay", "ths"]


def parse_money(raw: str) -> Decimal:
    """Parse a money string, tolerating full-width punctuation and separators."""
    text = (
        normalize_text(raw)
        .replace(",", "")
        .replace("¥", "")
        .replace("元", "")
        .replace("%", "")
        .strip()
    )
    return Decimal(text)


def _money(raw: str) -> Decimal | None:
    try:
        return parse_money(raw)
    except InvalidOperation:
        return None


def _require(row: DraftRow, name: str) -> Decimal | None:
    field = row.fields.get(name)
    if field is None:
        return None
    value = _money(field.raw_text)
    if value is None:
        row.issues.append(
            OcrIssue(
                code="ocr.unparseable_number",
                field=name,
                severity="blocking",
                message=f"field {name} raw text {field.raw_text!r} is not a number",
            )
        )
    return value


def _normalize_alipay(row: DraftRow) -> None:
    current = _require(row, "current_value")
    profit = _require(row, "holding_profit")
    cumulative = _require(row, "cumulative_profit")
    if current is not None:
        row.normalized["current_value"] = str(current)
    if profit is not None:
        row.normalized["holding_profit"] = str(profit)
    if cumulative is not None:
        row.normalized["cumulative_profit"] = str(cumulative)
    if current is not None and profit is not None:
        row.normalized["derived_cost"] = str(current - profit)


def _normalize_ths(row: DraftRow) -> None:
    current = _require(row, "current_value")
    profit = _require(row, "holding_profit")
    cost_price = _require(row, "cost_price")
    quantity = _require(row, "quantity")
    if current is not None:
        row.normalized["current_value"] = str(current)
    if profit is not None:
        row.normalized["holding_profit"] = str(profit)
    if cost_price is not None:
        row.normalized["cost_price"] = str(cost_price)
    if quantity is not None:
        row.normalized["quantity"] = str(quantity)
    if current is None or profit is None:
        return
    derived = current - profit
    row.normalized["derived_cost"] = str(derived)
    if cost_price is None or quantity is None:
        return
    reference = cost_price * quantity
    row.normalized["reference_cost"] = str(reference)
    tolerance = max(Decimal("1.00"), abs(derived) * Decimal("0.001"))
    if abs(derived - reference) > tolerance:
        row.issues.append(
            OcrIssue(
                code="import.cost_mismatch",
                field="derived_cost",
                severity="blocking",
                message=(
                    f"derived cost {derived} differs from cost_price*quantity "
                    f"{reference} beyond tolerance {tolerance}"
                ),
            )
        )


def normalize_rows(rows: list[DraftRow], template: Template) -> list[DraftRow]:
    for row in rows:
        if template == "alipay":
            _normalize_alipay(row)
        else:
            _normalize_ths(row)
    return rows


def _validate_image_path(raw_path: Any) -> Path:
    path = Path(str(raw_path))
    if not path.is_file() or path.suffix.lower() not in IMAGE_SUFFIXES:
        raise ValueError(f"ocr.invalid_image_path: {raw_path}")
    return path


def _row_to_dict(row: DraftRow, index: int) -> dict[str, Any]:
    return {
        "index": index,
        "page_index": row.page_index,
        "fields": {name: f.model_dump(mode="json") for name, f in row.fields.items()},
        "normalized": dict(row.normalized),
        "issues": [asdict(issue) for issue in row.issues],
    }


def parse_screenshots(params: dict[str, Any], backend: OcrBackend) -> dict[str, Any]:
    template = params.get("template")
    if template not in ("alipay", "ths"):
        raise ValueError(f"ocr.unknown_template: {template}")
    raw_paths = params.get("paths")
    if not isinstance(raw_paths, list) or not raw_paths:
        raise ValueError("ocr.invalid_image_path: paths must be a non-empty list")

    rows: list[DraftRow] = []
    for page_index, raw_path in enumerate(raw_paths):
        path = _validate_image_path(raw_path)
        tokens = backend.recognize(str(path))
        if template == "alipay":
            rows.extend(parse_alipay(tokens, page_index))
        else:
            rows.extend(parse_ths(tokens, page_index))
    normalize_rows(rows, template)

    return {
        "template": template,
        "rows": [_row_to_dict(row, i) for i, row in enumerate(rows)],
        "issues": [
            {**asdict(issue), "holding_index": i}
            for i, row in enumerate(rows)
            for issue in row.issues
            if issue.severity == "blocking"
        ],
    }
