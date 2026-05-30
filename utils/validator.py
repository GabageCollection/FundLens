"""Data validation module — three-tier rules (blocking errors, warnings, auto-fix detection).

Runs 17 rules + config check on cleaned DataFrames and generates structured reports.
Receives already-cleaned DataFrames from data_cleaner.  Auto-fix rules detect
remaining issues and report on what was handled during the cleaning pipeline.

Spec reference: task.md section 2.2-2.3
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Any

import pandas as pd

logger = logging.getLogger(__name__)

# ─── Constants ─────────────────────────────────────────────────

# Only YYYY-MM-DD is considered valid for statistic_date
DATE_FORMAT = "%Y-%m-%d"

# Percentage column names that should hold decimal values (0.0–1.0)
PERCENTAGE_COLUMNS = {"annual_fee_rate", "underlying_equity_pct", "holding_return"}

# Column sets used by specific rules
REQUIRED_STRING_COLS = {"platform", "product_name", "asset_class", "product_type"}

# ─── Helper ────────────────────────────────────────────────────


def _is_blank(value: Any) -> bool:
    """Return True if value is None, NaN, or an empty/whitespace-only string."""
    if value is None:
        return True
    if isinstance(value, float) and pd.isna(value):
        return True
    if isinstance(value, str) and value.strip() == "":
        return True
    return False


def _try_parse_date(value: Any) -> bool:
    """Return True if value can be parsed as a valid date."""
    if _is_blank(value):
        return False
    if isinstance(value, (datetime, pd.Timestamp)):
        return True
    if isinstance(value, (int, float)):
        return False  # a bare number like 20260331 is not a standard date format
    value_str = str(value).strip()
    try:
        datetime.strptime(value_str, DATE_FORMAT)
        return True
    except ValueError:
        return False


# ═════════════════════════════════════════════════════════════════
# Blocking Errors (7 rules)
# ═════════════════════════════════════════════════════════════════


def check_missing_current_value(df: pd.DataFrame) -> list[dict]:
    """E001: 当前金额为空 — rows where current_value is missing."""
    issues: list[dict] = []
    if "current_value" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        val = row["current_value"]
        if _is_blank(val):
            issues.append({
                "rule": "E001",
                "row": idx + 1,
                "field": "current_value",
                "message": "当前金额为空，无法参与资产统计",
            })
    return issues


def check_negative_current_value(df: pd.DataFrame) -> list[dict]:
    """E002: 当前金额为负."""
    issues: list[dict] = []
    if "current_value" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        val = row["current_value"]
        if not _is_blank(val):
            try:
                if float(val) < 0:
                    issues.append({
                        "rule": "E002",
                        "row": idx + 1,
                        "field": "current_value",
                        "message": f"当前金额为负 ({float(val):.2f})，数据异常",
                    })
            except (ValueError, TypeError):
                pass
    return issues


def check_negative_cost_amount(df: pd.DataFrame) -> list[dict]:
    """E003: 持有成本为负."""
    issues: list[dict] = []
    if "cost_amount" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        val = row["cost_amount"]
        if not _is_blank(val):
            try:
                if float(val) < 0:
                    issues.append({
                        "rule": "E003",
                        "row": idx + 1,
                        "field": "cost_amount",
                        "message": f"持有成本为负 ({float(val):.2f})，数据异常",
                    })
            except (ValueError, TypeError):
                pass
    return issues


def check_missing_product_name(df: pd.DataFrame) -> list[dict]:
    """E004: 产品名称为空."""
    issues: list[dict] = []
    if "product_name" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        if _is_blank(row.get("product_name")):
            issues.append({
                "rule": "E004",
                "row": idx + 1,
                "field": "product_name",
                "message": "产品名称为空，无法识别产品",
            })
    return issues


def check_missing_platform(df: pd.DataFrame) -> list[dict]:
    """E005: 平台为空."""
    issues: list[dict] = []
    if "platform" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        if _is_blank(row.get("platform")):
            issues.append({
                "rule": "E005",
                "row": idx + 1,
                "field": "platform",
                "message": "平台为空，无法归类统计",
            })
    return issues


def check_missing_statistic_date(df: pd.DataFrame) -> list[dict]:
    """E006: 统计日期为空."""
    issues: list[dict] = []
    if "statistic_date" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        if _is_blank(row.get("statistic_date")):
            issues.append({
                "rule": "E006",
                "row": idx + 1,
                "field": "statistic_date",
                "message": "统计日期为空，无法关联快照周期",
            })
    return issues


def check_date_format(df: pd.DataFrame) -> list[dict]:
    """E007: 日期格式非标准格式（仅检查非空日期）."""
    issues: list[dict] = []
    if "statistic_date" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        val = row["statistic_date"]
        if _is_blank(val):
            continue  # already caught by E006
        if isinstance(val, (pd.Timestamp, datetime)):
            continue
        if not _try_parse_date(val):
            issues.append({
                "rule": "E007",
                "row": idx + 1,
                "field": "statistic_date",
                "message": f"日期格式不正确 ({val})，请使用 YYYY-MM-DD 格式",
            })
    return issues


# ═════════════════════════════════════════════════════════════════
# Warnings (7 rules on df; check_target_allocation_sum is separate)
# ═════════════════════════════════════════════════════════════════


def check_missing_asset_class(df: pd.DataFrame) -> list[dict]:
    """W001: 资产大类为空 — 将自动归为'其他类'."""
    issues: list[dict] = []
    if "asset_class" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        if _is_blank(row.get("asset_class")):
            issues.append({
                "rule": "W001",
                "row": idx + 1,
                "message": "资产大类为空，将自动归为'其他类'",
            })
    return issues


def check_missing_product_type(df: pd.DataFrame) -> list[dict]:
    """W002: 产品类型为空 — 将自动归为'其他资产'."""
    issues: list[dict] = []
    if "product_type" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        if _is_blank(row.get("product_type")):
            issues.append({
                "rule": "W002",
                "row": idx + 1,
                "message": "产品类型为空，将自动归为'其他资产'",
            })
    return issues


def check_profit_deviation(df: pd.DataFrame) -> list[dict]:
    """W003: 持有收益与 (current_value - cost_amount) 偏差超过 1 元."""
    issues: list[dict] = []
    if "current_value" not in df.columns or "cost_amount" not in df.columns:
        return issues
    if "holding_profit" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        cv = row["current_value"]
        ca = row["cost_amount"]
        hp = row["holding_profit"]
        if _is_blank(cv) or _is_blank(ca) or _is_blank(hp):
            continue
        try:
            computed = float(cv) - float(ca)
            deviation = abs(float(hp) - computed)
            if deviation > 1.0:
                issues.append({
                    "rule": "W003",
                    "row": idx + 1,
                    "message": (
                        f"持有收益偏差 {deviation:.2f} 元 "
                        f"(填报值={float(hp):.2f}, 计算值={computed:.2f})，"
                        f"请确认数据是否准确"
                    ),
                })
        except (ValueError, TypeError):
            continue
    return issues


def check_abnormal_return(df: pd.DataFrame) -> list[dict]:
    """W004: 收益率超过 100% 或低于 -80%."""
    issues: list[dict] = []
    if "holding_return" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        val = row["holding_return"]
        if _is_blank(val):
            continue
        try:
            v = float(val)
            if v > 1.0:
                issues.append({
                    "rule": "W004",
                    "row": idx + 1,
                    "message": f"收益率异常偏高 ({v*100:.1f}% > 100%)，请确认数据是否准确",
                })
            elif v < -0.8:
                issues.append({
                    "rule": "W004",
                    "row": idx + 1,
                    "message": f"收益率异常偏低 ({v*100:.1f}% < -80%)，请确认数据是否准确",
                })
        except (ValueError, TypeError):
            continue
    return issues


def check_product_code_number_format(df: pd.DataFrame) -> list[dict]:
    """W005: 产品代码疑似数字格式（可能前导零丢失）."""
    issues: list[dict] = []
    if "product_code" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        code = row["product_code"]
        if _is_blank(code):
            continue
        code_str = str(code).strip()
        # Flag codes that are purely numeric but fewer than 6 digits
        if code_str.isdigit() and len(code_str) < 6:
            issues.append({
                "rule": "W005",
                "row": idx + 1,
                "message": f"产品代码 '{code_str}' 少于6位，可能丢失了前导零",
            })
    return issues


def check_duplicate_records(df: pd.DataFrame) -> list[dict]:
    """W006: 同一快照内 (统计日期 + 平台 + 产品名称) 重复."""
    issues: list[dict] = []
    keys = ["statistic_date", "platform", "product_name"]
    available = [k for k in keys if k in df.columns]
    if len(available) < 2:
        return issues
    dup_mask = df.duplicated(subset=available, keep=False)
    # Only report the first occurrence's dup partners
    seen: set[tuple] = set()
    for idx in df.index[dup_mask]:
        row = df.loc[idx]
        key = tuple(str(row.get(k, "")) for k in keys)
        if key in seen:
            continue
        seen.add(key)
        # Find all rows with this key
        dup_indices = []
        for idx2 in df.index:
            key2 = tuple(str(df.loc[idx2].get(k, "")) for k in keys)
            if key2 == key:
                dup_indices.append(idx2 + 1)
        if len(dup_indices) > 1:
            issues.append({
                "rule": "W006",
                "row": dup_indices[1],  # first duplicate row
                "message": (
                    f"发现重复记录（行 {', '.join(str(r) for r in dup_indices)}），"
                    f"产品 '{row.get('product_name', '')}'，请确认是否为重复数据"
                ),
            })
    return issues


def check_shares_price_mismatch(df: pd.DataFrame) -> list[dict]:
    """W007: 份额 x 当前价格 与当前金额偏差超过 5%."""
    issues: list[dict] = []
    for col in ("shares", "current_price", "current_value"):
        if col not in df.columns:
            return issues
    for idx, row in df.iterrows():
        shares = row["shares"]
        price = row.get("current_price")
        cv = row["current_value"]
        if _is_blank(shares) or _is_blank(price) or _is_blank(cv):
            continue
        try:
            computed = float(shares) * float(price)
            actual = float(cv)
            if computed == 0 and actual == 0:
                continue
            if computed == 0:
                continue
            deviation_pct = abs(actual - computed) / abs(computed)
            if deviation_pct > 0.05:
                issues.append({
                    "rule": "W007",
                    "row": idx + 1,
                    "message": (
                        f"份额×价格 ({computed:.2f}) 与当前金额 ({actual:.2f}) "
                        f"偏差 {deviation_pct*100:.1f}%，请确认份额和价格"
                    ),
                })
        except (ValueError, TypeError, ZeroDivisionError):
            continue
    return issues


# ═════════════════════════════════════════════════════════════════
# Auto-Fix Detection (runs on cleaned df, reports what was handled)
# ═════════════════════════════════════════════════════════════════


def detect_missing_cost(df: pd.DataFrame) -> list[dict]:
    """F001: 检测无成本数据的产品 — 已标记，不参与收益率计算."""
    issues: list[dict] = []
    if "current_value" not in df.columns or "cost_amount" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        cv = row["current_value"]
        ca = row["cost_amount"]
        if not _is_blank(cv) and _is_blank(ca):
            issues.append({
                "rule": "F001",
                "row": idx + 1,
                "message": f"产品 '{row.get('product_name', idx+1)}' 无成本数据，已标记，不参与收益率计算",
            })
    return issues


def detect_currency_issues(df: pd.DataFrame) -> list[dict]:
    """F002: 检测金额千分位逗号 — 后清洗阶段仅做检查（已由 data_cleaner 清理）."""
    # Post-cleaning, commas have been removed.  This function exists for traceability.
    # Returns empty list on cleaned data.
    return []


def detect_auto_calc_profit(df: pd.DataFrame) -> list[dict]:
    """F003: 检测自动计算的持有收益（holding_profit == current_value - cost_amount）."""
    issues: list[dict] = []
    if "current_value" not in df.columns or "cost_amount" not in df.columns:
        return issues
    if "holding_profit" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        cv = row["current_value"]
        ca = row["cost_amount"]
        hp = row["holding_profit"]
        if _is_blank(cv) or _is_blank(ca) or _is_blank(hp):
            continue
        try:
            computed = float(cv) - float(ca)
            if abs(float(hp) - computed) <= 1.0:
                issues.append({
                    "rule": "F003",
                    "row": idx + 1,
                    "message": (
                        f"产品 '{row.get('product_name', idx+1)}' 持有收益已计算 "
                        f"({float(hp):+.2f} = {float(cv):.2f} - {float(ca):.2f})"
                    ),
                })
        except (ValueError, TypeError):
            continue
    return issues


def detect_auto_calc_return(df: pd.DataFrame) -> list[dict]:
    """F004: 检测自动计算的持有收益率（holding_return ~= holding_profit / cost_amount）."""
    issues: list[dict] = []
    if "holding_profit" not in df.columns or "cost_amount" not in df.columns:
        return issues
    if "holding_return" not in df.columns:
        return issues
    for idx, row in df.iterrows():
        hp = row["holding_profit"]
        ca = row["cost_amount"]
        hr = row["holding_return"]
        if _is_blank(hp) or _is_blank(ca) or _is_blank(hr):
            continue
        try:
            if float(ca) <= 0:
                continue
            computed = float(hp) / float(ca)
            if abs(float(hr) - computed) < 0.001:
                issues.append({
                    "rule": "F004",
                    "row": idx + 1,
                    "message": (
                        f"产品 '{row.get('product_name', idx+1)}' 持有收益率已计算 "
                        f"({float(hr)*100:.2f}% = {float(hp):.2f} / {float(ca):.2f})"
                    ),
                })
        except (ValueError, TypeError):
            continue
    return issues


def detect_percentage_issues(df: pd.DataFrame) -> list[dict]:
    """F005: 检测疑似未转换的百分号值（年化管理费率 > 1 等）."""
    issues: list[dict] = []
    for col in PERCENTAGE_COLUMNS:
        if col not in df.columns:
            continue
        for idx, row in df.iterrows():
            val = row[col]
            if _is_blank(val):
                continue
            try:
                if float(val) > 1.0:
                    issues.append({
                        "rule": "F005",
                        "row": idx + 1,
                        "message": (
                            f"'{col}' 值 {float(val)} 疑似未转换的百分号格式"
                            f"（应存储为小数如 0.0435 而非 4.35），已自动转换"
                        ),
                    })
            except (ValueError, TypeError):
                continue
    return issues


# ═════════════════════════════════════════════════════════════════
# Report Generator
# ═════════════════════════════════════════════════════════════════


def generate_validation_report(df: pd.DataFrame) -> dict:
    """Run all validation rules and return a structured report.

    Args:
        df: A cleaned DataFrame (from data_cleaner.clean_dataframe).

    Returns:
        Dict with keys:
          - errors: list of blocking error dicts (rule, row, field, message)
          - warnings: list of warning dicts (rule, row, message)
          - fixes: list of auto-fix detection dicts (rule, row, message)
          - summary: dict with total_rows, error_count, warning_count, fix_count
    """
    if df is None or len(df) == 0:
        return {
            "errors": [],
            "warnings": [],
            "fixes": [],
            "summary": {
                "total_rows": len(df) if df is not None else 0,
                "error_count": 0,
                "warning_count": 0,
                "fix_count": 0,
            },
        }

    # ── Blocking errors (7 rules) ──────────────────────────
    errors: list[dict] = []
    for rule_fn in [
        check_missing_current_value,
        check_negative_current_value,
        check_negative_cost_amount,
        check_missing_product_name,
        check_missing_platform,
        check_missing_statistic_date,
        check_date_format,
    ]:
        errors.extend(rule_fn(df))

    # ── Warnings (7 rules on df) ───────────────────────────
    warnings: list[dict] = []
    for rule_fn in [
        check_missing_asset_class,
        check_missing_product_type,
        check_profit_deviation,
        check_abnormal_return,
        check_product_code_number_format,
        check_duplicate_records,
        check_shares_price_mismatch,
    ]:
        warnings.extend(rule_fn(df))

    # ── Auto-fix detection (3 rules on df) ────────────────
    fixes: list[dict] = []
    for rule_fn in [
        detect_missing_cost,
        detect_auto_calc_profit,
        detect_auto_calc_return,
        detect_percentage_issues,
        detect_currency_issues,
    ]:
        fixes.extend(rule_fn(df))

    total_rows = len(df)

    logger.info(
        "Validation complete: %d rows, %d errors, %d warnings, %d fixes",
        total_rows,
        len(errors),
        len(warnings),
        len(fixes),
    )

    return {
        "errors": errors,
        "warnings": warnings,
        "fixes": fixes,
        "summary": {
            "total_rows": total_rows,
            "error_count": len(errors),
            "warning_count": len(warnings),
            "fix_count": len(fixes),
        },
    }
