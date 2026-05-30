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
    """
    try:
        df = pd.read_excel(filepath, sheet_name="asset_snapshot", nrows=2)
        if "statistic_date" in df.columns and len(df) > 0:
            date_val = df.iloc[0]["statistic_date"]
            date_str = str(pd.Timestamp(date_val).date()) if pd.notna(date_val) else None
            name = f"{Path(filepath).stem}"
            if date_str:
                name = f"{date_str} {name}"
            return {"name": name, "date": date_str}
    except Exception:
        logger.warning("Could not extract snapshot info from %s", filepath, exc_info=True)
    return {"name": Path(filepath).stem, "date": None}


def save_uploaded_file(uploaded_file) -> Path:
    """Save a Streamlit UploadedFile to data/uploaded/ and return the saved path."""
    UPLOADED_DIR.mkdir(parents=True, exist_ok=True)
    dest = UPLOADED_DIR / uploaded_file.name
    with open(dest, "wb") as f:
        f.write(uploaded_file.getbuffer())
    logger.info("Saved uploaded file to %s", dest)
    return dest


def load_snapshot(filepath: Path) -> pd.DataFrame:
    """Read the asset_snapshot sheet from an Excel file and return a DataFrame."""
    df = pd.read_excel(filepath, sheet_name="asset_snapshot")
    logger.info("Loaded snapshot %s: %d rows", filepath, len(df))
    return df


def get_snapshot_list() -> list[dict]:
    """Return list of available snapshot dicts with name, date, and path."""
    files = scan_uploaded_files()
    return [
        {"name": info["name"], "date": info["date"], "path": str(f)}
        for f in files
        if (info := extract_snapshot_info(f))
    ]
