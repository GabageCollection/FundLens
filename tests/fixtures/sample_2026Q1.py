"""Test fixture — 2026Q1 sample data converted from 前端设计/js/sample-data.js.

Provides 8 products across Alipay + Tonghuashun covering 6 asset classes.
Used as the verification baseline for Python-side metric calculations.
"""

import pandas as pd

SAMPLE_DATA_2026Q1 = [
    {
        "statistic_date": "2026-03-31",
        "platform": "支付宝",
        "account_name": "主账户",
        "asset_class": "固收类",
        "product_type": "纯债基金",
        "market_region": "中国内地",
        "product_name": "XX纯债债券A",
        "product_code": "000001",
        "currency": "CNY",
        "current_value": 12000,
        "cost_amount": 11500,
        "shares": None,
        "current_price": None,
        "cost_price": None,
        "risk_level": "中低",
        "usage_purpose": "稳健",
        "annual_fee_rate": 0.008,
        "underlying_equity_pct": 0,
        "top3_industries": "",
        "liquidity": "高",
        "remark": "长期持有",
    },
    {
        "statistic_date": "2026-03-31",
        "platform": "支付宝",
        "account_name": "主账户",
        "asset_class": "固收增强类",
        "product_type": "固收+",
        "market_region": "中国内地",
        "product_name": "XX稳健收益混合",
        "product_code": "000002",
        "currency": "CNY",
        "current_value": 8000,
        "cost_amount": 7900,
        "shares": None,
        "current_price": None,
        "cost_price": None,
        "risk_level": "中",
        "usage_purpose": "稳健",
        "annual_fee_rate": 0.012,
        "underlying_equity_pct": 15,
        "top3_industries": "金融, 消费",
        "liquidity": "中",
        "remark": "",
    },
    {
        "statistic_date": "2026-03-31",
        "platform": "支付宝",
        "account_name": "主账户",
        "asset_class": "跨境类",
        "product_type": "QDII",
        "market_region": "美国",
        "product_name": "XX海外收益基金",
        "product_code": "000003",
        "currency": "CNY",
        "current_value": 5000,
        "cost_amount": 4800,
        "shares": None,
        "current_price": None,
        "cost_price": None,
        "risk_level": "中高",
        "usage_purpose": "长期",
        "annual_fee_rate": 0.015,
        "underlying_equity_pct": 80,
        "top3_industries": "科技, 消费, 医疗",
        "liquidity": "中",
        "remark": "",
    },
    {
        "statistic_date": "2026-03-31",
        "platform": "支付宝",
        "account_name": "主账户",
        "asset_class": "权益类",
        "product_type": "行业基金",
        "market_region": "中国内地",
        "product_name": "XX新能源基金",
        "product_code": "000004",
        "currency": "CNY",
        "current_value": 6000,
        "cost_amount": 7000,
        "shares": None,
        "current_price": None,
        "cost_price": None,
        "risk_level": "高",
        "usage_purpose": "长期",
        "annual_fee_rate": 0.015,
        "underlying_equity_pct": 95,
        "top3_industries": "电力设备, 有色, 化工",
        "liquidity": "高",
        "remark": "",
    },
    {
        "statistic_date": "2026-03-31",
        "platform": "支付宝",
        "account_name": "主账户",
        "asset_class": "现金类",
        "product_type": "余利宝",
        "market_region": "中国内地",
        "product_name": "余利宝",
        "product_code": "",
        "currency": "CNY",
        "current_value": 10000,
        "cost_amount": None,
        "shares": None,
        "current_price": None,
        "cost_price": None,
        "risk_level": "低",
        "usage_purpose": "活钱",
        "annual_fee_rate": 0,
        "underlying_equity_pct": 0,
        "top3_industries": "",
        "liquidity": "高",
        "remark": "",
    },
    {
        "statistic_date": "2026-03-31",
        "platform": "同花顺",
        "account_name": "主账户",
        "asset_class": "权益类",
        "product_type": "宽基 ETF",
        "market_region": "中国内地",
        "product_name": "沪深300ETF",
        "product_code": "510300",
        "currency": "CNY",
        "current_value": 15000,
        "cost_amount": 14000,
        "shares": 3500,
        "current_price": 4.2857,
        "cost_price": 4.0,
        "risk_level": "中高",
        "usage_purpose": "长期",
        "annual_fee_rate": 0.005,
        "underlying_equity_pct": 100,
        "top3_industries": "金融, 食品饮料, 电子",
        "liquidity": "高",
        "remark": "",
    },
    {
        "statistic_date": "2026-03-31",
        "platform": "同花顺",
        "account_name": "主账户",
        "asset_class": "权益类",
        "product_type": "行业 ETF",
        "market_region": "中国内地",
        "product_name": "证券ETF",
        "product_code": "512880",
        "currency": "CNY",
        "current_value": 6000,
        "cost_amount": 6500,
        "shares": 5000,
        "current_price": 1.2,
        "cost_price": 1.3,
        "risk_level": "高",
        "usage_purpose": "长期",
        "annual_fee_rate": 0.005,
        "underlying_equity_pct": 100,
        "top3_industries": "非银金融",
        "liquidity": "高",
        "remark": "",
    },
    {
        "statistic_date": "2026-03-31",
        "platform": "同花顺",
        "account_name": "主账户",
        "asset_class": "跨境类",
        "product_type": "跨境 ETF",
        "market_region": "美国",
        "product_name": "纳指ETF",
        "product_code": "513100",
        "currency": "CNY",
        "current_value": 9000,
        "cost_amount": 8000,
        "shares": 2000,
        "current_price": 4.5,
        "cost_price": 4.0,
        "risk_level": "中高",
        "usage_purpose": "长期",
        "annual_fee_rate": 0.006,
        "underlying_equity_pct": 100,
        "top3_industries": "科技, 通信, 消费",
        "liquidity": "高",
        "remark": "",
    },
]


def create_sample_dataframe() -> pd.DataFrame:
    """Return the 8-row sample dataset as a DataFrame with computed profit/return columns."""
    df = pd.DataFrame(SAMPLE_DATA_2026Q1)

    mask = df["cost_amount"].notna() & (df["cost_amount"] > 0)
    df.loc[mask, "holding_profit"] = df.loc[mask, "current_value"] - df.loc[mask, "cost_amount"]
    df.loc[mask, "holding_return"] = df.loc[mask, "holding_profit"] / df.loc[mask, "cost_amount"]

    return df


def compute_metrics(df: pd.DataFrame) -> dict:
    """Compute aggregate metrics matching sample-data.js computeMetrics() output.

    Returns dict with: total_assets, total_cost, total_profit, total_return,
    coverage, platform_count, product_count, max_single_ratio, equity_ratio.
    """
    total_assets = df["current_value"].sum()
    with_cost = df[df["cost_amount"].notna() & (df["cost_amount"] > 0)]
    total_cost = with_cost["cost_amount"].sum()
    total_profit = with_cost["holding_profit"].sum() if "holding_profit" in with_cost.columns else 0
    total_return = total_profit / total_cost if total_cost > 0 else 0.0
    covered_amount = with_cost["current_value"].sum()
    coverage = covered_amount / total_assets if total_assets > 0 else 0.0

    platform_count = df["platform"].nunique()
    product_count = len(df)
    max_single_ratio = df["current_value"].max() / total_assets if total_assets > 0 else 0

    by_class = df.groupby("asset_class")["current_value"].sum().to_dict()
    equity_ratio = by_class.get("权益类", 0) / total_assets if total_assets > 0 else 0

    return {
        "total_assets": total_assets,
        "total_cost": total_cost,
        "total_profit": total_profit,
        "total_return": total_return,
        "coverage": coverage,
        "covered_amount": covered_amount,
        "platform_count": platform_count,
        "product_count": product_count,
        "max_single_ratio": max_single_ratio,
        "equity_ratio": equity_ratio,
        "by_class": by_class,
    }


# Expected metrics from the JS sample-data.js computeMetrics()
EXPECTED_METRICS = {
    "total_assets": 71000.0,
    "total_cost": 59700.0,
    "total_profit": 1300.0,
    "total_return": 0.02177554,  # 1300 / 59700 ≈ 2.18%
    "coverage": 0.8591549,  # ~85.9%
    "platform_count": 2,
    "product_count": 8,
    "max_single_ratio": 0.2112676,  # ~21.1% (沪深300ETF)
    "equity_ratio": 0.3802817,  # ~38.0%
}
