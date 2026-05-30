"""Tests for utils/data_cleaner.py — Phase 2 data cleaning pipeline."""

import pandas as pd
import pytest

from utils.data_cleaner import (
    auto_calc_holding_profit,
    auto_calc_holding_return,
    clean_currency,
    clean_dataframe,
    clean_empty_to_none,
    clean_percentage,
    clean_product_code,
)


class TestCleanCurrency:
    def test_removes_comma_thousands(self):
        assert clean_currency("12,000") == 12000.0
        assert clean_currency("1,234,567.89") == 1234567.89

    def test_passes_through_clean_number(self):
        assert clean_currency(12000.0) == 12000.0
        assert clean_currency(12000) == 12000.0

    def test_returns_none_for_empty(self):
        assert clean_currency(None) is None
        assert clean_currency("") is None

    def test_strips_whitespace(self):
        assert clean_currency(" 12,000 ") == 12000.0


class TestCleanPercentage:
    def test_converts_percent_to_decimal(self):
        assert clean_percentage("4.35%") == pytest.approx(0.0435)
        assert clean_percentage("85%") == pytest.approx(0.85)
        assert clean_percentage("0.5%") == pytest.approx(0.005)

    def test_passes_through_decimal(self):
        assert clean_percentage(0.0435) == pytest.approx(0.0435)

    def test_returns_none_for_empty(self):
        assert clean_percentage(None) is None
        assert clean_percentage("") is None


class TestCleanProductCode:
    def test_pads_to_six_digits(self):
        assert clean_product_code("1") == "000001"
        assert clean_product_code("510300") == "510300"
        assert clean_product_code(1) == "000001"

    def test_returns_none_for_empty(self):
        assert clean_product_code("") == ""
        assert clean_product_code(None) == ""


class TestCleanEmptyToNone:
    def test_converts_empty_to_none(self):
        assert clean_empty_to_none("") is None
        assert clean_empty_to_none("   ") is None
        assert clean_empty_to_none(pd.NA) is None

    def test_passes_through_value(self):
        assert clean_empty_to_none("hello") == "hello"
        assert clean_empty_to_none(0) == 0


class TestAutoCalcHoldingProfit:
    def test_calculates_when_cost_exists_profit_missing(self):
        row = pd.Series({"current_value": 12000.0, "cost_amount": 11500.0, "holding_profit": None})
        row = auto_calc_holding_profit(row)
        assert row["holding_profit"] == 500.0

    def test_preserves_existing_profit(self):
        row = pd.Series({"current_value": 12000.0, "cost_amount": 11500.0, "holding_profit": 600.0})
        row = auto_calc_holding_profit(row)
        assert row["holding_profit"] == 600.0

    def test_skips_when_no_cost(self):
        row = pd.Series({"current_value": 10000.0, "cost_amount": None, "holding_profit": None})
        row = auto_calc_holding_profit(row)
        assert pd.isna(row["holding_profit"])


class TestAutoCalcHoldingReturn:
    def test_calculates_when_profit_exists_return_missing(self):
        row = pd.Series({"holding_profit": 500.0, "cost_amount": 11500.0, "holding_return": None})
        row = auto_calc_holding_return(row)
        assert row["holding_return"] == pytest.approx(0.043478, rel=1e-4)

    def test_preserves_existing_return(self):
        row = pd.Series({"holding_profit": 500.0, "cost_amount": 11500.0, "holding_return": 0.05})
        row = auto_calc_holding_return(row)
        assert row["holding_return"] == 0.05

    def test_skips_when_no_cost_or_no_profit(self):
        row = pd.Series({"holding_profit": None, "cost_amount": 11500.0, "holding_return": None})
        row = auto_calc_holding_return(row)
        assert pd.isna(row["holding_return"])


class TestCleanDataFrame:
    def test_end_to_end_cleaning(self):
        df = pd.DataFrame([
            {"current_value": "12,000", "cost_amount": "11,500", "holding_profit": None, "holding_return": None,
             "annual_fee_rate": "0.8%", "product_code": 1, "product_name": "Test", "platform": "支付宝"},
            {"current_value": "8,000", "cost_amount": "", "holding_profit": None, "holding_return": None,
             "annual_fee_rate": "1.2%", "product_code": "000002", "product_name": "", "platform": ""},
        ])
        cleaned = clean_dataframe(df)

        assert cleaned.iloc[0]["current_value"] == 12000.0
        assert cleaned.iloc[0]["cost_amount"] == 11500.0
        assert cleaned.iloc[0]["holding_profit"] == 500.0
        assert cleaned.iloc[0]["holding_return"] == pytest.approx(0.043478, rel=1e-4)
        assert cleaned.iloc[0]["annual_fee_rate"] == pytest.approx(0.008)
        assert cleaned.iloc[0]["product_code"] == "000001"

        assert cleaned.iloc[1]["current_value"] == 8000.0
        assert pd.isna(cleaned.iloc[1]["cost_amount"])
        assert cleaned.iloc[1]["annual_fee_rate"] == pytest.approx(0.012)
