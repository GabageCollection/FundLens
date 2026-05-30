"""Data cleaning pipeline — format normalization, auto-calculation, empty handling."""

import logging
import re

import pandas as pd

logger = logging.getLogger(__name__)

COLUMNS_NUMERIC = ["current_value", "cost_amount", "shares", "current_price", "cost_price"]
COLUMNS_PERCENTAGE = ["annual_fee_rate", "underlying_equity_pct", "holding_return"]


def clean_currency(value):
    """Remove thousand-separator commas and convert to float. 12,000 -> 12000.0"""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    value = str(value).strip().replace(",", "")
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        logger.debug("Could not parse currency value: %r", value)
        return value


def clean_percentage(value):
    """Convert percentage string to decimal. 4.35% -> 0.0435, 85% -> 0.85"""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    value = str(value).strip()
    if not value:
        return None
    if "%" in value:
        return float(value.replace("%", "")) / 100.0
    try:
        return float(value)
    except ValueError:
        return value


def clean_product_code(code):
    """Pad product code to 6 digits with leading zeros, store as string. 1 -> '000001'"""
    if code is None:
        return ""
    code_str = str(code).strip()
    if not code_str:
        return code_str
    try:
        return str(int(float(code_str))).zfill(6)
    except (ValueError, TypeError):
        return code_str


def clean_empty_to_none(value):
    """Convert empty strings, whitespace, and pandas NA to None."""
    if value is None:
        return None
    if isinstance(value, str) and value.strip() == "":
        return None
    if pd.isna(value):
        return None
    return value


def auto_calc_holding_profit(row: pd.Series) -> pd.Series:
    """Auto-calculate holding_profit from current_value - cost_amount when missing."""
    has_cost = pd.notna(row.get("cost_amount")) and row["cost_amount"] is not None
    has_current = pd.notna(row.get("current_value")) and row["current_value"] is not None
    profit = row.get("holding_profit")
    if has_cost and has_current:
        computed = float(row["current_value"]) - float(row["cost_amount"])
        if pd.isna(profit) or profit is None:
            row["holding_profit"] = computed
        else:
            deviation = abs(float(profit) - computed)
            if deviation > 1.0:
                logger.debug(
                    "Profit deviation > 1: user=%.2f computed=%.2f, keeping user value",
                    float(profit),
                    computed,
                )
    return row


def auto_calc_holding_return(row: pd.Series) -> pd.Series:
    """Auto-calculate holding_return from holding_profit / cost_amount when missing."""
    profit = row.get("holding_profit")
    cost = row.get("cost_amount")
    ret = row.get("holding_return")
    if pd.notna(profit) and pd.notna(cost) and float(cost) > 0:
        if pd.isna(ret) or ret is None:
            row["holding_return"] = float(profit) / float(cost)
    return row


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Apply the full cleaning pipeline to a DataFrame.

    Execution order:
    1. Clean empty values -> None
    2. Clean currency fields (remove commas)
    3. Clean percentage fields (% -> decimal)
    4. Clean product codes (leading zeros)
    5. Auto-calculate holding profit
    6. Auto-calculate holding return
    """
    df = df.copy()

    object_cols = df.select_dtypes(include=["object"]).columns
    for col in object_cols:
        df[col] = df[col].apply(clean_empty_to_none)

    for col in COLUMNS_NUMERIC:
        if col in df.columns:
            df[col] = df[col].apply(clean_currency)

    for col in COLUMNS_PERCENTAGE:
        if col in df.columns:
            df[col] = df[col].apply(clean_percentage)

    if "product_code" in df.columns:
        df["product_code"] = df["product_code"].apply(clean_product_code)

    if "current_value" in df.columns and "cost_amount" in df.columns:
        df = df.apply(auto_calc_holding_profit, axis=1)
    if "holding_profit" in df.columns and "cost_amount" in df.columns:
        df = df.apply(auto_calc_holding_return, axis=1)

    logger.info("Cleaned DataFrame: %d rows, %d cols", len(df), len(df.columns))
    return df
