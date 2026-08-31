"""OCR normalization service and the ``ocr.parse_screenshots`` entry point.

Applies the financial consistency checks from the Phase 2 plan:

- 支付宝推算成本 = 当前金额 − 持有收益
- 同花顺推算成本 = 市值 − 盈亏金额
- 同花顺参考成本 = 成本价 × 持仓数量
- 容差 = max(CNY 1.00, abs(同花顺推算成本) × 0.001)

A Tonghuashun cost mismatch yields a blocking ``import.cost_mismatch`` issue;
neither cost is ever silently chosen.
"""

from dataclasses import asdict, replace
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, Literal

from ..security import IMAGE_SUFFIXES as IMAGE_SUFFIXES
from ..security import PathAccessError, validate_selected_files
from .alipay_parser import parse_alipay
from .backend import DraftRow, OcrBackend, OcrIssue, field_label
from .layout import ColumnLayout, normalize_text
from .ths_parser import parse_ths, ths_column_layout

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
                message=f"{field_label(name)}「{field.raw_text}」不是有效的数字，请修正",
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
                    f"按「当前金额 − 持有收益」推算的成本 {derived} "
                    f"与「成本价 × 持仓数量」算出的 {reference} 对不上，"
                    "请核对成本价和持仓数量"
                ),
            )
        )
    else:
        _downgrade_corroborated_confidence(row)


def _downgrade_corroborated_confidence(row: DraftRow) -> None:
    """成本恒等式成立时，cost_price/quantity 的低置信阻断降级为警告。

    cost_price × quantity ≈ 市值 − 盈亏 由三个独立识别的字段交叉验证，
    恒等式成立即数学 corroborate 这两个读数；此时卡 0.90 阈值刀锋的阻断
    只会逼用户反复确认已验证正确的值。恒等式不成立时阻断保持原样，
    由 import.cost_mismatch 与低置信双重把关。
    """
    row.issues[:] = [
        replace(
            issue,
            severity="warning",
            message=issue.message + "（与当前金额、持有收益交叉验证一致，请人工确认）",
        )
        if (
            issue.code == "ocr.low_confidence"
            and issue.field in ("cost_price", "quantity")
            and issue.severity == "blocking"
        )
        else issue
        for issue in row.issues
    ]


_THS_DEDUPE_FIELDS = ("product_name", "current_value", "holding_profit", "quantity", "cost_price")


def _ths_dedupe_key(row: DraftRow) -> tuple[str, ...] | None:
    """五要素完全一致才视为同一持仓；任一缺失则不参与去重（保守）。"""
    parts: list[str] = []
    for name in _THS_DEDUPE_FIELDS:
        field = row.fields.get(name)
        if field is None:
            return None
        parts.append(normalize_text(field.raw_text).replace(",", "").replace(" ", "").lower())
    return tuple(parts)


def _dedupe_ths_rows(rows: list[DraftRow]) -> list[DraftRow]:
    """滚动截屏跨页重叠时同一持仓会被重复识别；合并并保留首次出现的行。

    保留行附 info 级 duplicate_merged 提示，合并行为对人工可见。
    """
    seen: dict[tuple[str, ...], DraftRow] = {}
    kept: list[DraftRow] = []
    for row in rows:
        key = _ths_dedupe_key(row)
        if key is None:
            kept.append(row)
            continue
        if key not in seen:
            seen[key] = row
            kept.append(row)
            continue
        seen[key].issues.append(
            OcrIssue(
                code="ocr.duplicate_merged",
                field="",
                severity="info",
                message=(
                    f"第 {row.page_index + 1} 页识别到相同持仓"
                    f"「{row.fields['product_name'].raw_text}」，已按首次出现合并去重"
                ),
            )
        )
    return kept


def normalize_rows(rows: list[DraftRow], template: Template) -> list[DraftRow]:
    for row in rows:
        if template == "alipay":
            _normalize_alipay(row)
        else:
            _normalize_ths(row)
    return rows


def _validate_image_paths(raw_paths: list[Any]) -> list[Path]:
    """Enforce the selected-path boundary before any file is read.

    The request's paths double as the allowlist: each resolved path must
    equal an exact allowlisted entry, be a regular image file and stay
    within per-file and total size limits.
    """
    try:
        return validate_selected_files(
            [str(raw_path) for raw_path in raw_paths],
            allowed_paths=[str(raw_path) for raw_path in raw_paths],
        )
    except PathAccessError as exc:
        raise ValueError(f"ocr.invalid_image_path: {exc}") from exc


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
    ths_layout: ColumnLayout | None = None
    for page_index, path in enumerate(_validate_image_paths(raw_paths)):
        tokens = backend.recognize(str(path))
        if template == "alipay":
            rows.extend(parse_alipay(tokens, page_index))
        else:
            found = ths_column_layout(tokens)
            rows.extend(parse_ths(tokens, page_index, fallback_layout=ths_layout))
            if found is not None:
                ths_layout = found
    if template == "ths":
        rows = _dedupe_ths_rows(rows)
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
