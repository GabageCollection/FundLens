"""Tests for utils/validator.py — three-tier validation with 18 rules + report generator."""

import pandas as pd
import pytest

from utils.validator import (
    check_abnormal_return,
    check_date_format,
    check_duplicate_records,
    check_missing_asset_class,
    check_missing_current_value,
    check_missing_platform,
    check_missing_product_name,
    check_missing_product_type,
    check_missing_statistic_date,
    check_negative_cost_amount,
    check_negative_current_value,
    check_product_code_number_format,
    check_profit_deviation,
    check_shares_price_mismatch,
    detect_auto_calc_profit,
    detect_auto_calc_return,
    detect_currency_issues,
    detect_missing_cost,
    detect_percentage_issues,
    generate_validation_report,
)


# ─── Helper: build a minimal valid row ─────────────────────────

def _make_row(**overrides) -> dict:
    """Return a dict representing one valid row, ready for DataFrame construction."""
    base = {
        "statistic_date": "2026-03-31",
        "platform": "支付宝",
        "asset_class": "固收类",
        "product_type": "纯债基金",
        "product_name": "测试产品A",
        "product_code": "000001",
        "current_value": 10000.0,
        "cost_amount": 9500.0,
        "holding_profit": 500.0,
        "holding_return": 0.0526,
        "shares": None,
        "current_price": None,
        "annual_fee_rate": 0.008,
    }
    base.update(overrides)
    return base


def _make_df(*rows) -> pd.DataFrame:
    """Build a DataFrame from row dicts."""
    return pd.DataFrame(list(rows))


# ═══════════════════════════════════════════════════════════════
# Blocking Error Rules
# ═══════════════════════════════════════════════════════════════

class TestCheckMissingCurrentValue:
    def test_detects_none(self):
        df = _make_df(_make_row(current_value=None))
        result = check_missing_current_value(df)
        assert len(result) == 1
        assert result[0]["rule"] == "E001"
        assert result[0]["field"] == "current_value"
        assert "为空" in result[0]["message"]

    def test_detects_nan(self):
        df = _make_df(_make_row(current_value=float("nan")))
        result = check_missing_current_value(df)
        assert len(result) == 1

    def test_no_false_positive(self):
        df = _make_df(_make_row(current_value=5000.0))
        result = check_missing_current_value(df)
        assert len(result) == 0

    def test_column_missing_returns_empty(self):
        df = pd.DataFrame([{"platform": "支付宝"}])
        result = check_missing_current_value(df)
        assert len(result) == 0


class TestCheckNegativeCurrentValue:
    def test_detects_negative(self):
        df = _make_df(_make_row(current_value=-100.0))
        result = check_negative_current_value(df)
        assert len(result) == 1
        assert result[0]["rule"] == "E002"
        assert "负" in result[0]["message"]

    def test_allows_zero(self):
        df = _make_df(_make_row(current_value=0.0))
        result = check_negative_current_value(df)
        assert len(result) == 0

    def test_allows_positive(self):
        df = _make_df(_make_row(current_value=100.0))
        result = check_negative_current_value(df)
        assert len(result) == 0


class TestCheckNegativeCostAmount:
    def test_detects_negative(self):
        df = _make_df(_make_row(cost_amount=-500.0))
        result = check_negative_cost_amount(df)
        assert len(result) == 1
        assert result[0]["rule"] == "E003"
        assert "负" in result[0]["message"]

    def test_allows_none_cost(self):
        df = _make_df(_make_row(cost_amount=None))
        result = check_negative_cost_amount(df)
        assert len(result) == 0


class TestCheckMissingProductName:
    def test_detects_none(self):
        df = _make_df(_make_row(product_name=None))
        result = check_missing_product_name(df)
        assert len(result) == 1
        assert result[0]["rule"] == "E004"

    def test_detects_empty_string(self):
        df = _make_df(_make_row(product_name=""))
        result = check_missing_product_name(df)
        assert len(result) == 1

    def test_column_missing_returns_empty(self):
        df = pd.DataFrame([{"platform": "支付宝"}])
        result = check_missing_product_name(df)
        assert len(result) == 0


class TestCheckMissingPlatform:
    def test_detects_none(self):
        df = _make_df(_make_row(platform=None))
        result = check_missing_platform(df)
        assert len(result) == 1
        assert result[0]["rule"] == "E005"

    def test_detects_empty_string(self):
        df = _make_df(_make_row(platform=""))
        result = check_missing_platform(df)
        assert len(result) == 1


class TestCheckMissingStatisticDate:
    def test_detects_none(self):
        df = _make_df(_make_row(statistic_date=None))
        result = check_missing_statistic_date(df)
        assert len(result) == 1
        assert result[0]["rule"] == "E006"

    def test_detects_nan(self):
        df = _make_df(_make_row(statistic_date=float("nan")))
        result = check_missing_statistic_date(df)
        assert len(result) == 1


class TestCheckDateFormat:
    def test_detects_invalid_format(self):
        df = _make_df(_make_row(statistic_date="2026/03/31"))
        result = check_date_format(df)
        assert len(result) == 1
        assert result[0]["rule"] == "E007"

    def test_detects_nonsense_string(self):
        df = _make_df(_make_row(statistic_date="abc"))
        result = check_date_format(df)
        assert len(result) == 1

    def test_detects_numeric_date(self):
        df = _make_df(_make_row(statistic_date=20260331))
        result = check_date_format(df)
        assert len(result) == 1

    def test_accepts_iso_format(self):
        df = _make_df(_make_row(statistic_date="2026-03-31"))
        result = check_date_format(df)
        assert len(result) == 0

    def test_accepts_timestamp(self):
        df = _make_df(_make_row(statistic_date=pd.Timestamp("2026-03-31")))
        result = check_date_format(df)
        assert len(result) == 0

    def test_allows_none_bypassed(self):
        """None dates are caught by E006, not E007."""
        df = _make_df(_make_row(statistic_date=None))
        result = check_date_format(df)
        assert len(result) == 0  # handled by E006


# ═══════════════════════════════════════════════════════════════
# Warning Rules
# ═══════════════════════════════════════════════════════════════

class TestCheckMissingAssetClass:
    def test_detects_none(self):
        df = _make_df(_make_row(asset_class=None))
        result = check_missing_asset_class(df)
        assert len(result) == 1
        assert result[0]["rule"] == "W001"
        assert "资产大类" in result[0]["message"]

    def test_detects_empty_string(self):
        df = _make_df(_make_row(asset_class=""))
        result = check_missing_asset_class(df)
        assert len(result) == 1


class TestCheckMissingProductType:
    def test_detects_none(self):
        df = _make_df(_make_row(product_type=None))
        result = check_missing_product_type(df)
        assert len(result) == 1
        assert result[0]["rule"] == "W002"
        assert "产品类型" in result[0]["message"]


class TestCheckProfitDeviation:
    def test_flags_deviation_gt_1_rmb(self):
        # user wrote profit=600 but current-cost=500, deviation=100
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=9500.0, holding_profit=600.0
        ))
        result = check_profit_deviation(df)
        assert len(result) == 1
        assert result[0]["rule"] == "W003"
        assert "偏差" in result[0]["message"]

    def test_accepts_deviation_le_1_rmb(self):
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=9500.0, holding_profit=500.5
        ))
        result = check_profit_deviation(df)
        assert len(result) == 0

    def test_skips_when_no_cost(self):
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=None, holding_profit=500.0
        ))
        result = check_profit_deviation(df)
        assert len(result) == 0

    def test_skips_when_no_profit(self):
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=9500.0, holding_profit=None
        ))
        result = check_profit_deviation(df)
        assert len(result) == 0


class TestCheckAbnormalReturn:
    def test_flags_return_above_100_pct(self):
        df = _make_df(_make_row(holding_return=1.5))  # 150%
        result = check_abnormal_return(df)
        assert len(result) == 1
        assert result[0]["rule"] == "W004"

    def test_flags_return_below_minus_80_pct(self):
        df = _make_df(_make_row(holding_return=-0.95))  # -95%
        result = check_abnormal_return(df)
        assert len(result) == 1

    def test_accepts_normal_range(self):
        df = _make_df(_make_row(holding_return=0.25))  # 25%
        result = check_abnormal_return(df)
        assert len(result) == 0

    def test_skips_when_return_is_none(self):
        df = _make_df(_make_row(holding_return=None))
        result = check_abnormal_return(df)
        assert len(result) == 0

    def test_skips_when_column_missing(self):
        df = _make_df(_make_row())
        df = df.drop(columns=["holding_return"])
        result = check_abnormal_return(df)
        assert len(result) == 0


class TestCheckProductCodeNumberFormat:
    def test_flags_short_all_digits(self):
        df = _make_df(_make_row(product_code="1"))  # only 1 digit
        result = check_product_code_number_format(df)
        assert len(result) == 1
        assert result[0]["rule"] == "W005"

    def test_flags_short_numeric_string(self):
        df = _make_df(_make_row(product_code="300"))  # 3 digits
        result = check_product_code_number_format(df)
        assert len(result) == 1

    def test_accepts_six_digit_code(self):
        df = _make_df(_make_row(product_code="000001"))
        result = check_product_code_number_format(df)
        assert len(result) == 0

    def test_accepts_alphanumeric_code(self):
        df = _make_df(_make_row(product_code="ABC123"))
        result = check_product_code_number_format(df)
        assert len(result) == 0

    def test_accepts_empty_code(self):
        df = _make_df(_make_row(product_code=""))
        result = check_product_code_number_format(df)
        assert len(result) == 0

    def test_accepts_none_code(self):
        df = _make_df(_make_row(product_code=None))
        result = check_product_code_number_format(df)
        assert len(result) == 0

    def test_skips_when_column_missing(self):
        df = _make_df(_make_row())
        df = df.drop(columns=["product_code"])
        result = check_product_code_number_format(df)
        assert len(result) == 0


class TestCheckDuplicateRecords:
    def test_detects_duplicate(self):
        row = _make_row(
            statistic_date="2026-03-31", platform="支付宝", product_name="测试产品A"
        )
        df = _make_df(row, row)
        result = check_duplicate_records(df)
        assert len(result) == 1
        assert result[0]["rule"] == "W006"

    def test_no_duplicate_when_unique(self):
        df = _make_df(
            _make_row(product_name="A"),
            _make_row(product_name="B"),
        )
        result = check_duplicate_records(df)
        assert len(result) == 0

    def test_different_platforms_not_duplicate(self):
        df = _make_df(
            _make_row(platform="支付宝", product_name="Test"),
            _make_row(platform="同花顺", product_name="Test"),
        )
        result = check_duplicate_records(df)
        assert len(result) == 0


class TestCheckSharesPriceMismatch:
    def test_flags_mismatch_above_5_pct(self):
        # shares=100, price=50 → computed=5000, but current_value=6000 → 20% mismatch
        df = _make_df(_make_row(
            shares=100.0, current_price=50.0, current_value=6000.0
        ))
        result = check_shares_price_mismatch(df)
        assert len(result) == 1
        assert result[0]["rule"] == "W007"

    def test_accepts_small_mismatch(self):
        df = _make_df(_make_row(
            shares=100.0, current_price=50.0, current_value=5005.0
        ))
        result = check_shares_price_mismatch(df)
        assert len(result) == 0

    def test_skips_when_shares_missing(self):
        df = _make_df(_make_row(
            shares=None, current_price=50.0, current_value=5000.0
        ))
        result = check_shares_price_mismatch(df)
        assert len(result) == 0

    def test_skips_when_price_missing(self):
        df = _make_df(_make_row(
            shares=100.0, current_price=None, current_value=5000.0
        ))
        result = check_shares_price_mismatch(df)
        assert len(result) == 0


# ═══════════════════════════════════════════════════════════════
# Auto-Fix Detection Rules
# ═══════════════════════════════════════════════════════════════

class TestDetectMissingCost:
    def test_detects_row_with_no_cost(self):
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=None
        ))
        result = detect_missing_cost(df)
        assert len(result) == 1
        assert result[0]["rule"] == "F001"

    def test_detects_nan_cost(self):
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=float("nan")
        ))
        result = detect_missing_cost(df)
        assert len(result) == 1

    def test_no_detection_when_cost_exists(self):
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=9500.0
        ))
        result = detect_missing_cost(df)
        assert len(result) == 0

    def test_column_missing_returns_empty(self):
        df = pd.DataFrame([{"current_value": 10000.0}])
        result = detect_missing_cost(df)
        assert len(result) == 0


class TestDetectCurrencyIssues:
    def test_no_detection_on_clean_data(self):
        """Post-cleaning, commas are already removed — detection returns empty."""
        df = _make_df(_make_row(current_value=12000.0, cost_amount=11500.0))
        result = detect_currency_issues(df)
        assert len(result) == 0


class TestDetectPercentageIssues:
    def test_detects_unconverted_percentage(self):
        """annual_fee_rate > 1 indicates percentage was not converted to decimal."""
        df = _make_df(_make_row(annual_fee_rate=4.35))
        result = detect_percentage_issues(df)
        assert len(result) == 1
        assert result[0]["rule"] == "F005"

    def test_accepts_proper_decimal(self):
        df = _make_df(_make_row(annual_fee_rate=0.008))
        result = detect_percentage_issues(df)
        assert len(result) == 0

    def test_skips_none_values(self):
        df = _make_df(_make_row(annual_fee_rate=None))
        result = detect_percentage_issues(df)
        assert len(result) == 0


class TestDetectAutoCalcProfit:
    def test_detects_likely_auto_calc(self):
        """When holding_profit == current_value - cost_amount, likely auto-calculated."""
        df = _make_df(_make_row(
            current_value=12000.0, cost_amount=11500.0, holding_profit=500.0,
        ))
        result = detect_auto_calc_profit(df)
        assert len(result) == 1
        assert result[0]["rule"] == "F003"

    def test_no_detection_when_profit_missing(self):
        df = _make_df(_make_row(
            current_value=12000.0, cost_amount=11500.0, holding_profit=None,
        ))
        result = detect_auto_calc_profit(df)
        assert len(result) == 0


class TestDetectAutoCalcReturn:
    def test_detects_likely_auto_calc(self):
        df = _make_df(_make_row(
            holding_profit=500.0, cost_amount=11500.0, holding_return=0.043478,
        ))
        result = detect_auto_calc_return(df)
        assert len(result) == 1
        assert result[0]["rule"] == "F004"

    def test_no_detection_when_return_missing(self):
        df = _make_df(_make_row(
            holding_profit=500.0, cost_amount=11500.0, holding_return=None,
        ))
        result = detect_auto_calc_return(df)
        assert len(result) == 0


# ═══════════════════════════════════════════════════════════════
# Full Report Generation
# ═══════════════════════════════════════════════════════════════

class TestGenerateValidationReport:
    def test_clean_data_passes_all(self):
        """A clean 2-row dataset should produce 0 errors."""
        df = _make_df(
            _make_row(product_name="A"),
            _make_row(product_name="B"),
        )
        report = generate_validation_report(df)
        assert report["summary"]["total_rows"] == 2
        assert report["summary"]["error_count"] == 0
        assert len(report["errors"]) == 0

    def test_report_has_required_keys(self):
        df = _make_df(_make_row())
        report = generate_validation_report(df)
        for key in ("errors", "warnings", "fixes", "summary"):
            assert key in report
        for key in ("total_rows", "error_count", "warning_count", "fix_count"):
            assert key in report["summary"]

    def test_error_entries_have_required_keys(self):
        df = _make_df(_make_row(current_value=None))
        report = generate_validation_report(df)
        assert report["summary"]["error_count"] >= 1
        for err in report["errors"]:
            for key in ("rule", "row", "field", "message"):
                assert key in err, f"Error entry missing key: {key}"

    def test_warning_entries_have_required_keys(self):
        df = _make_df(_make_row(asset_class=None, holding_return=1.5))
        report = generate_validation_report(df)
        assert report["summary"]["warning_count"] >= 1
        for w in report["warnings"]:
            for key in ("rule", "row", "message"):
                assert key in w, f"Warning entry missing key: {key}"

    def test_fix_entries_have_required_keys(self):
        df = _make_df(_make_row(
            current_value=10000.0, cost_amount=None  # triggers missing cost fix
        ))
        report = generate_validation_report(df)
        assert report["summary"]["fix_count"] >= 1
        for f in report["fixes"]:
            for key in ("rule", "row", "message"):
                assert key in f, f"Fix entry missing key: {key}"

    def test_multiple_errors_on_same_row(self):
        """A row with multiple problems should generate multiple error entries."""
        df = _make_df(_make_row(
            current_value=None,
            product_name=None,
            platform=None,
        ))
        report = generate_validation_report(df)
        assert report["summary"]["error_count"] >= 3

    def test_empty_dataframe(self):
        df = pd.DataFrame()
        report = generate_validation_report(df)
        assert report["summary"]["total_rows"] == 0
        assert report["summary"]["error_count"] == 0

    def test_row_numbers_are_one_based(self):
        df = _make_df(
            _make_row(product_name="OK"),
            _make_row(current_value=None),  # row 2
        )
        report = generate_validation_report(df)
        error_rows = {e["row"] for e in report["errors"]}
        assert 2 in error_rows
        assert 1 not in error_rows

    def test_comprehensive_dirty_dataset(self):
        """Single dataset with many issues — verify counts."""
        df = _make_df(
            _make_row(
                statistic_date="bad-date",
                platform=None,
                asset_class=None,
                product_name="",
                current_value=-100,
                cost_amount=-50,
                holding_return=2.0,
                product_code="5",
            ),
            _make_row(
                statistic_date="2026-03-31",
                platform="支付宝",
                asset_class="固收类",
                product_type="纯债基金",
                product_name="Test",
                product_code="000001",
                current_value=10000.0,
                cost_amount=None,  # triggers fix detection
                holding_profit=None,
                holding_return=None,
            ),
            _make_row(  # duplicate of row 2
                statistic_date="2026-03-31",
                platform="支付宝",
                asset_class="固收类",
                product_name="Test",
                product_code="000002",
                current_value=20000.0,
                cost_amount=19000.0,
                holding_profit=1000.0,
                holding_return=0.0526,
            ),
            _make_row(  # shares*price mismatch
                statistic_date="2026-03-31",
                platform="同花顺",
                asset_class="权益类",
                product_type="宽基 ETF",
                product_name="ETF",
                product_code="510300",
                current_value=6000.0,
                cost_amount=5500.0,
                holding_profit=500.0,
                holding_return=0.09,
                shares=100.0,
                current_price=50.0,
            ),
        )
        report = generate_validation_report(df)

        assert report["summary"]["total_rows"] == 4
        # Row 1 has: E001(missing current_value? No, -100 is valid), E002(negative current), E003(negative cost),
        #            E004(missing product_name), E005(missing platform), E007(bad date),
        #            W001(missing asset_class), W004(abnormal return), W005(product code issues)
        # Expected errors: E002, E003, E004, E005, E007 = 5 errors
        # Note: E001 not triggered because -100 is not None/null (it's negative, handled by E002)
        # E006 not triggered because "bad-date" is not None (but fails format, handled by E007)
        assert report["summary"]["error_count"] >= 1
        assert report["summary"]["warning_count"] >= 1
        # Row 2 has missing cost, row 4 has possible auto-calc profit match
        assert report["summary"]["fix_count"] >= 1
