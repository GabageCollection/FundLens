"""测试 utils/benchmarks.py — 基准对比模块。"""

import pytest

from utils.benchmarks import calc_benchmark_return, calc_relative_return, load_benchmark_config, save_benchmark_config


class TestBenchmarkCalculation:
    def test_benchmark_return_positive(self):
        config = {"name": "沪深300", "start_value": 3500.0, "end_value": 3850.0}
        assert calc_benchmark_return(config) == pytest.approx(0.1)

    def test_benchmark_return_negative(self):
        config = {"name": "沪深300", "start_value": 4000.0, "end_value": 3800.0}
        assert calc_benchmark_return(config) == pytest.approx(-0.05)

    def test_benchmark_return_zero_start(self):
        config = {"name": "X", "start_value": 0.0, "end_value": 100.0}
        assert calc_benchmark_return(config) == 0.0

    def test_benchmark_return_missing_keys(self):
        assert calc_benchmark_return({}) == 0.0
        assert calc_benchmark_return({"name": "X"}) == 0.0

    def test_relative_return_outperform(self):
        assert calc_relative_return(0.15, 0.10) == pytest.approx(0.05)

    def test_relative_return_underperform(self):
        assert calc_relative_return(0.03, 0.10) == pytest.approx(-0.07)

    def test_relative_return_equal(self):
        assert calc_relative_return(0.10, 0.10) == 0.0


class TestConfigIO:
    def test_load_existing_config(self):
        session = {"benchmark_config": {"name": "沪深300", "start_value": 3500.0, "end_value": 3850.0}}
        config = load_benchmark_config(session)
        assert config["name"] == "沪深300"
        assert config["start_value"] == 3500.0

    def test_load_missing_config_returns_default(self):
        config = load_benchmark_config({})
        assert config["name"] == ""
        assert config["start_value"] is None
        assert config["end_value"] is None

    def test_save_config(self):
        session = {}
        save_benchmark_config(session, "中证500", 6000.0, 6300.0)
        assert session["benchmark_config"]["name"] == "中证500"
        assert session["benchmark_config"]["start_value"] == 6000.0
        assert session["benchmark_config"]["end_value"] == 6300.0
