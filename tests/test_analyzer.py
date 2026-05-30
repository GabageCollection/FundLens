"""测试 utils/analyzer.py — 阶段三统计分析模块。"""

import pandas as pd
import pytest

from tests.fixtures.sample_2026Q1 import create_sample_dataframe
from utils.analyzer import (
    calc_asset_class_distribution,
    calc_coverage,
    calc_equity_ratio,
    calc_max_single_ratio,
    calc_platform_count,
    calc_platform_distribution,
    calc_product_count,
    calc_top10_holdings,
    calc_top10_loss,
    calc_top10_profit,
    calc_total_assets,
    calc_total_cost,
    calc_total_profit,
    calc_total_return,
)


@pytest.fixture
def sample_df():
    """8 条产品，覆盖 6 种资产大类，2 个平台。"""
    return create_sample_dataframe()


class TestTotalMetrics:
    def test_total_assets(self, sample_df):
        assert calc_total_assets(sample_df) == 71000.0

    def test_total_cost(self, sample_df):
        assert calc_total_cost(sample_df) == 59700.0

    def test_total_profit(self, sample_df):
        assert calc_total_profit(sample_df) == 1300.0

    def test_total_return(self, sample_df):
        assert calc_total_return(sample_df) == pytest.approx(0.02177554, rel=1e-4)

    def test_coverage(self, sample_df):
        assert calc_coverage(sample_df) == pytest.approx(0.859155, rel=1e-4)

    def test_product_count(self, sample_df):
        assert calc_product_count(sample_df) == 8

    def test_platform_count(self, sample_df):
        assert calc_platform_count(sample_df) == 2

    def test_max_single_ratio(self, sample_df):
        assert calc_max_single_ratio(sample_df) == pytest.approx(0.2112676, rel=1e-4)

    def test_equity_ratio(self, sample_df):
        assert calc_equity_ratio(sample_df) == pytest.approx(0.3802817, rel=1e-4)


class TestDistributions:
    def test_platform_distribution(self, sample_df):
        dist = calc_platform_distribution(sample_df)
        assert dist["支付宝"] == 41000.0
        assert dist["同花顺"] == 30000.0

    def test_asset_class_distribution(self, sample_df):
        dist = calc_asset_class_distribution(sample_df)
        assert dist["固收类"] == 12000.0
        assert dist["权益类"] == 27000.0
        assert dist["现金类"] == 10000.0
        assert dist["跨境类"] == 14000.0
        assert dist["固收增强类"] == 8000.0


class TestTopLists:
    def test_top10_holdings(self, sample_df):
        top = calc_top10_holdings(sample_df)
        assert len(top) == 8  # only 8 products total
        assert top.iloc[0]["product_name"] == "沪深300ETF"
        assert top.iloc[0]["current_value"] == 15000.0

    def test_top10_profit(self, sample_df):
        top = calc_top10_profit(sample_df)
        # Only products with cost have profit, max profit = 1000 (沪深300ETF or 纳指ETF)
        assert len(top) > 0
        assert top.iloc[0]["holding_profit"] > 0

    def test_top10_loss(self, sample_df):
        top = calc_top10_loss(sample_df)
        # XX新能源基金 (6000-7000=-1000) and 证券ETF (6000-6500=-500) are losers
        assert len(top) == 2
        assert top.iloc[0]["holding_profit"] < 0

    def test_empty_dataframe(self):
        df = pd.DataFrame(columns=["current_value", "cost_amount", "platform", "asset_class", "product_name"])
        assert calc_total_assets(df) == 0.0
        assert calc_total_cost(df) == 0.0
        assert calc_total_profit(df) == 0.0
        assert calc_total_return(df) == 0.0
        assert calc_coverage(df) == 0.0
        assert calc_product_count(df) == 0
        assert calc_platform_count(df) == 0
        assert calc_max_single_ratio(df) == 0.0
        assert calc_equity_ratio(df) == 0.0
        assert len(calc_top10_holdings(df)) == 0
        assert len(calc_top10_profit(df)) == 0
        assert len(calc_top10_loss(df)) == 0
