"""数据导出 — Excel / CSV 导出，供产品明细页面使用。"""

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)


def export_to_excel(df: pd.DataFrame, filepath: str | Path) -> Path:
    """导出 DataFrame 为 .xlsx 文件，自动创建目录。"""
    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    df.to_excel(filepath, index=False, engine="openpyxl")
    logger.info("Exported %d rows to %s", len(df), filepath)
    return filepath


def export_to_csv(df: pd.DataFrame, filepath: str | Path) -> Path:
    """导出 DataFrame 为 UTF-8 BOM .csv 文件（Excel 兼容中文）。"""
    filepath = Path(filepath)
    filepath.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(filepath, index=False, encoding="utf-8-sig")
    logger.info("Exported %d rows to %s", len(df), filepath)
    return filepath
