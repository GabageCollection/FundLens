"""File I/O: scan, save, and load asset snapshot Excel files."""

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger(__name__)

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
UPLOADED_DIR = DATA_DIR / "uploaded"


def scan_uploaded_files() -> list[Path]:
    """Return list of all .xlsx files in data/uploaded/, sorted by modification time descending."""
    if not UPLOADED_DIR.exists():
        return []
    files = sorted(UPLOADED_DIR.glob("*.xlsx"), key=lambda p: p.stat().st_mtime, reverse=True)
    return files


def extract_snapshot_info(filepath: Path) -> dict[str, str | None]:
    """Read statistic_date from an Excel snapshot and derive a display name.

    Returns dict with keys: name (display label), date (YYYY-MM-DD string or None).
    Handles both Chinese (统计日期) and English (statistic_date) column headers.
    """
    try:
        df = pd.read_excel(filepath, sheet_name="asset_snapshot", nrows=2)
        date_col = None
        if "statistic_date" in df.columns:
            date_col = "statistic_date"
        elif "统计日期" in df.columns:
            date_col = "统计日期"
        if date_col and len(df) > 0:
            date_val = df.iloc[0][date_col]
            date_str = str(pd.Timestamp(date_val).date()) if pd.notna(date_val) else None
            name = Path(filepath).stem
            if date_str:
                name = f"{date_str} {name}"
            return {"name": name, "date": date_str}
    except Exception:
        logger.warning("Could not extract snapshot info from %s", filepath, exc_info=True)
    return {"name": Path(filepath).stem, "date": None}


def save_uploaded_file(uploaded_file) -> Path:
    """Save a Streamlit UploadedFile to data/uploaded/ and return the saved path.

    The filename is sanitized to prevent path traversal via '..' or absolute paths.
    """
    UPLOADED_DIR.mkdir(parents=True, exist_ok=True)
    safe_name = Path(uploaded_file.name).name  # strips directory components
    dest = UPLOADED_DIR / safe_name
    with open(dest, "wb") as f:
        f.write(uploaded_file.getbuffer())
    logger.info("Saved uploaded file to %s", dest)
    return dest



def get_snapshot_list() -> list[dict]:
    """Return list of available snapshot dicts with name, date, and path."""
    files = scan_uploaded_files()
    return [
        {"name": info["name"], "date": info["date"], "path": str(f)}
        for f in files
        if (info := extract_snapshot_info(f))
    ]
