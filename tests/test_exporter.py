"""测试 utils/exporter.py — 导出功能。"""

import pytest
import pandas as pd
from pathlib import Path
import tempfile
import os
from utils.exporter import export_to_excel, export_to_csv


@pytest.fixture
def sample_df():
    return pd.DataFrame({
        "product_name": ["A基金", "B ETF"],
        "current_value": [12000.0, 8000.0],
        "holding_profit": [500.0, -200.0],
        "holding_return": [0.043, -0.024],
    })


class TestExportToExcel:
    def test_export_creates_file(self, sample_df):
        with tempfile.NamedTemporaryFile(suffix=".xlsx", delete=False) as f:
            path = f.name
        try:
            export_to_excel(sample_df, path)
            assert Path(path).exists()
            assert Path(path).stat().st_size > 0
        finally:
            os.unlink(path)

    def test_export_creates_directory(self, sample_df):
        import tempfile
        tmpdir = Path(tempfile.mkdtemp()) / "sub" / "export.xlsx"
        try:
            export_to_excel(sample_df, str(tmpdir))
            assert tmpdir.exists()
        finally:
            import shutil
            shutil.rmtree(tmpdir.parent.parent, ignore_errors=True)


class TestExportToCSV:
    def test_export_creates_file(self, sample_df):
        with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as f:
            path = f.name
        try:
            export_to_csv(sample_df, path)
            assert Path(path).exists()
            content = Path(path).read_text(encoding="utf-8-sig")
            assert "A基金" in content
            assert "12000" in content
        finally:
            os.unlink(path)

    def test_csv_uses_bom(self, sample_df):
        with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as f:
            path = f.name
        try:
            export_to_csv(sample_df, path)
            raw = Path(path).read_bytes()
            assert raw[:3] == b'\xef\xbb\xbf'  # UTF-8 BOM
        finally:
            os.unlink(path)
