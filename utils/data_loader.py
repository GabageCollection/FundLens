"""Excel reading: Sheet parsing and Chinese/English field name mapping."""

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)

# Chinese → English field name mapping
COLUMN_MAP: dict[str, str] = {
    "统计日期": "statistic_date",
    "平台": "platform",
    "账户名称": "account_name",
    "资产大类": "asset_class",
    "产品类型": "product_type",
    "市场区域": "market_region",
    "产品名称": "product_name",
    "产品代码": "product_code",
    "币种": "currency",
    "当前金额": "current_value",
    "持有成本": "cost_amount",
    "持有份额": "shares",
    "当前价格": "current_price",
    "成本价格": "cost_price",
    "风险等级": "risk_level",
    "资金用途": "usage_purpose",
    "年化管理费率": "annual_fee_rate",
    "底层权益占比": "underlying_equity_pct",
    "重仓行业（前3）": "top3_industries",
    "流动性": "liquidity",
    "备注": "remark",
}


def detect_field_language(df: pd.DataFrame) -> str:
    """Detect whether the DataFrame uses Chinese or English column headers.

    Returns "zh" if 3+ columns match the Chinese COLUMN_MAP keys, otherwise "en".
    """
    zh_matches = sum(1 for col in df.columns if col in COLUMN_MAP)
    return "zh" if zh_matches >= 3 else "en"


def map_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Map Chinese (or already English) column names to internal English names.

    Columns that are already in English are left unchanged.
    """
    lang = detect_field_language(df)
    if lang == "zh":
        df = df.rename(columns=COLUMN_MAP)
        logger.debug("Mapped %d Chinese columns to English", len(set(df.columns) & set(COLUMN_MAP.values())))
    else:
        logger.debug("Columns already in English, skipping rename")
    return df


def read_asset_snapshot(filepath: str | Path) -> pd.DataFrame:
    """Read the asset_snapshot sheet from an Excel file, map columns, and return a clean DataFrame."""
    filepath = Path(filepath)
    if not filepath.exists():
        raise FileNotFoundError(f"File not found: {filepath}")

    df = pd.read_excel(filepath, sheet_name="asset_snapshot")
    df = map_columns(df)
    logger.info("Read asset snapshot from %s: %d rows, %d columns", filepath, len(df), len(df.columns))
    return df


if __name__ == "__main__":
    import sys

    logging.basicConfig(level=logging.DEBUG, format="%(levelname)s: %(message)s")

    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        path = "data/sample/FundLens_Asset_Snapshot_Template.xlsx"
    df = read_asset_snapshot(path)
    print(df.head())
    print(f"\nColumns: {list(df.columns)}")
