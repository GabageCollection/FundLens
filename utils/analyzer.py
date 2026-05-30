"""统计分析模块 — 分组聚合、指标计算，供首页看板和分析页面使用。

所有函数接受清洗后的 DataFrame（英文列名），返回纯 Python 数值或 DataFrame。
"""

import pandas as pd


def calc_total_assets(df: pd.DataFrame) -> float:
    """所有资产当前金额之和。"""
    if "current_value" not in df.columns or df.empty:
        return 0.0
    return float(df["current_value"].sum())


def calc_total_cost(df: pd.DataFrame) -> float:
    """有成本数据的资产持有成本之和。"""
    if "cost_amount" not in df.columns or "current_value" not in df.columns:
        return 0.0
    mask = df["cost_amount"].notna() & (df["cost_amount"] > 0)
    return float(df.loc[mask, "cost_amount"].sum()) if mask.any() else 0.0


def calc_total_profit(df: pd.DataFrame) -> float:
    """总持有收益（仅统计有成本数据的资产）。"""
    if "holding_profit" not in df.columns:
        return 0.0
    mask = df["holding_profit"].notna()
    return float(df.loc[mask, "holding_profit"].sum()) if mask.any() else 0.0


def calc_total_return(df: pd.DataFrame) -> float:
    """总收益率 = 总持有收益 / 总持有成本。仅基于有成本数据的资产计算。"""
    total_cost = calc_total_cost(df)
    if total_cost == 0:
        return 0.0
    return calc_total_profit(df) / total_cost


def calc_coverage(df: pd.DataFrame) -> float:
    """收益统计覆盖率 = 有成本资产的当前金额 / 总资产。"""
    if "current_value" not in df.columns or "cost_amount" not in df.columns:
        return 0.0
    total = df["current_value"].sum()
    if total == 0:
        return 0.0
    mask = df["cost_amount"].notna() & (df["cost_amount"] > 0)
    covered = df.loc[mask, "current_value"].sum() if mask.any() else 0.0
    return float(covered / total)


def calc_product_count(df: pd.DataFrame) -> int:
    """产品总数。"""
    return len(df)


def calc_platform_count(df: pd.DataFrame) -> int:
    """平台数量（去重）。"""
    if "platform" not in df.columns:
        return 0
    return int(df["platform"].nunique())


def calc_max_single_ratio(df: pd.DataFrame) -> float:
    """最大单品占比 = 最大单品的当前金额 / 总资产。"""
    if "current_value" not in df.columns or df.empty:
        return 0.0
    total = df["current_value"].sum()
    if total == 0:
        return 0.0
    return float(df["current_value"].max() / total)


def calc_equity_ratio(df: pd.DataFrame) -> float:
    """权益类资产占比。"""
    if "asset_class" not in df.columns or "current_value" not in df.columns:
        return 0.0
    total = df["current_value"].sum()
    if total == 0:
        return 0.0
    equity = df.loc[df["asset_class"] == "权益类", "current_value"].sum()
    return float(equity / total)


def calc_platform_distribution(df: pd.DataFrame) -> dict[str, float]:
    """按平台分组当前金额，返回 {平台名: 金额}。"""
    if "platform" not in df.columns or "current_value" not in df.columns:
        return {}
    return df.groupby("platform")["current_value"].sum().to_dict()


def calc_asset_class_distribution(df: pd.DataFrame) -> dict[str, float]:
    """按资产大类分组当前金额，返回 {大类名: 金额}。"""
    if "asset_class" not in df.columns or "current_value" not in df.columns:
        return {}
    return df.groupby("asset_class")["current_value"].sum().to_dict()


def calc_top10_holdings(df: pd.DataFrame) -> pd.DataFrame:
    """持仓 Top 10（按当前金额降序，返回含 product_name + current_value 的 DataFrame）。"""
    if df.empty or "product_name" not in df.columns or "current_value" not in df.columns:
        return pd.DataFrame()
    return df.nlargest(10, "current_value")[["product_name", "current_value"]].reset_index(drop=True)


def calc_top10_profit(df: pd.DataFrame) -> pd.DataFrame:
    """收益 Top 10（按持有收益降序，仅含盈利 > 0 的产品）。"""
    if df.empty or "holding_profit" not in df.columns or "product_name" not in df.columns:
        return pd.DataFrame()
    mask = df["holding_profit"].notna() & (df["holding_profit"] > 0)
    return df[mask].nlargest(10, "holding_profit")[["product_name", "holding_profit"]].reset_index(drop=True)


def calc_top10_loss(df: pd.DataFrame) -> pd.DataFrame:
    """亏损 Top 10（按持有收益升序，仅含亏损 < 0 的产品）。"""
    if df.empty or "holding_profit" not in df.columns or "product_name" not in df.columns:
        return pd.DataFrame()
    mask = df["holding_profit"].notna() & (df["holding_profit"] < 0)
    return df[mask].nsmallest(10, "holding_profit")[["product_name", "holding_profit"]].reset_index(drop=True)
