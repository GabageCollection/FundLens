"""Phase 1 Playwright tests for FundLens — standalone runner.

Usage: py tests/run_phase1_tests.py
"""

import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

BASE_URL = "http://localhost:8501"
SCREENSHOT_DIR = Path(__file__).resolve().parent / "screenshots"
SCREENSHOT_DIR.mkdir(exist_ok=True)

passed = 0
failed = 0


def check(test_name: str, condition: bool, detail: str = "") -> None:
    global passed, failed
    if condition:
        print(f"  [PASS] {test_name}")
        passed += 1
    else:
        print(f"  [FAIL] {test_name}" + (f" — {detail}" if detail else ""))
        failed += 1


def run_tests() -> None:
    global passed, failed
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(viewport={"width": 1440, "height": 900}, locale="zh-CN")
        page = context.new_page()

        # ──────────────────────────────────────────────
        # Section 1: Main Page (app.py)
        # ──────────────────────────────────────────────
        print("\n=== 1. Main Page (app.py) ===")

        page.goto(BASE_URL)
        page.wait_for_timeout(3000)

        check("Page title contains FundLens", "FundLens" in page.title())
        check("Sidebar visible", page.locator("[data-testid='stSidebar']").is_visible())
        check("FundLens brand in sidebar", page.locator("[data-testid='stSidebar']").get_by_text("FundLens").first.is_visible())

        # Empty state or snapshot selector visible
        sidebar_text = page.locator("[data-testid='stSidebar']").text_content()
        has_empty_msg = "暂无已导入快照" in sidebar_text
        has_selectbox = "选择快照" in sidebar_text or "快照切换" in sidebar_text
        check("Snapshot selector or empty msg shown", has_empty_msg or has_selectbox, sidebar_text[:200])

        check("Main title FundLens", page.locator("h1").first.is_visible())

        # Privacy footer
        check("Privacy footer in sidebar", "所有数据仅在本地处理" in sidebar_text)

        # Custom CSS check — background should be warm parchment
        bg = page.locator(".stApp").evaluate("el => window.getComputedStyle(el).backgroundColor")
        check("Custom CSS loaded (background != white)", "rgb(245, 244, 237)" in bg or "#f5f4ed" in bg.lower(), bg)

        page.screenshot(path=str(SCREENSHOT_DIR / "01_main_page.png"), full_page=True)
        print("  Screenshot: 01_main_page.png")

        # ──────────────────────────────────────────────
        # Section 2: Import Data Page
        # ──────────────────────────────────────────────
        print("\n=== 2. Import Page (5_📥_import_data.py) ===")

        page.goto(f"{BASE_URL}/import_data")
        page.wait_for_load_state("networkidle", timeout=15000)
        page.wait_for_timeout(3000)

        page_text = page.locator("body").text_content()

        check("Import page loaded", "数据导入" in page_text, page_text[:300])
        check("Step 1 visible", "上传 Excel" in page_text)
        check("Step 2 visible", "预览与校验" in page_text, page_text[:500])
        check("Step 3 visible", "导入确认" in page_text, page_text[:500])

        # The file uploader might use a different test ID
        uploader = page.locator("[data-testid='stFileUploader']")
        alt_uploader = page.locator("section").filter(has_text="上传资产快照")
        check("File uploader visible", uploader.is_visible() or alt_uploader.is_visible())

        check("Template download button", page.locator("button:has-text('下载标准模板')").is_visible())

        active_step = page.locator(".import-step.active")
        if active_step.count() > 0:
            step_text = active_step.first.text_content()
            check("First step is active step", "1" in step_text, step_text)
        else:
            check("Step classes rendered", False, "No .import-step.active found")

        page.screenshot(path=str(SCREENSHOT_DIR / "02_import_page.png"), full_page=True)
        print("  Screenshot: 02_import_page.png")

        # ──────────────────────────────────────────────
        # Section 3: Upload & Preview
        # ──────────────────────────────────────────────
        print("\n=== 3. Upload & Preview Flow ===")

        sample_path = Path(__file__).resolve().parent.parent / "data" / "uploaded" / "2026Q1_示例快照.xlsx"
        if sample_path.exists():
            # Try multiple selectors for the file input
            file_input = page.locator("input[type='file']").first
            file_input.wait_for(state="attached", timeout=10000)
            file_input.set_input_files(str(sample_path))
            page.wait_for_timeout(4000)

            post_upload_text = page.locator("body").text_content()
            check("Import summary appears", "导入摘要" in post_upload_text)
            check("Data preview appears", "数据预览" in post_upload_text)
            check("Record count shown (8)", "共 8 条记录" in post_upload_text)
            check("Confirm button visible", page.locator("button:has-text('确认导入')").is_visible())

            # Coverage info
            check("Coverage stats shown", "收益统计覆盖率" in post_upload_text)

            page.screenshot(path=str(SCREENSHOT_DIR / "03_preview.png"), full_page=True)
            print("  Screenshot: 03_preview.png")

            # Click confirm import
            print("\n=== 4. Confirm Import & Navigate to Home ===")
            page.locator("button:has-text('确认导入')").click()
            page.wait_for_timeout(3000)

            # Now go to main page
            page.goto(BASE_URL)
            page.wait_for_timeout(3000)

            sidebar_text2 = page.locator("[data-testid='stSidebar']").text_content()
            # After import, the 2026Q1 snapshot should be available in the selectbox
            page.screenshot(path=str(SCREENSHOT_DIR / "04_main_after_import.png"), full_page=True)
            print("  Screenshot: 04_main_after_import.png")
        else:
            print(f"  [SKIP] Sample file not found at {sample_path}")
            check("Upload tests", False, "Sample file missing")

        # ──────────────────────────────────────────────
        # Section 4: Backend Data Integrity
        # ──────────────────────────────────────────────
        print("\n=== 5. Backend Data Integrity ===")

        # Verify using Python directly (bypasses UI)
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        from tests.fixtures.sample_2026Q1 import create_sample_dataframe, compute_metrics, EXPECTED_METRICS
        from utils.data_loader import read_asset_snapshot
        from utils.file_manager import get_snapshot_list

        # Test snapshot list
        snaps = get_snapshot_list()
        check("Snapshot list not empty", len(snaps) > 0, f"Found {len(snaps)} snapshots")
        if snaps:
            check("Snapshot has date", snaps[0]["date"] is not None or snaps[0]["name"] is not None)
            check("Snapshot path exists", Path(snaps[0]["path"]).exists())

            # Test data loading
            df = read_asset_snapshot(snaps[0]["path"])
            check("Data loaded with 8 rows", len(df) == 8, f"Got {len(df)} rows")
            check("Has 21+ columns", len(df.columns) >= 21, f"Got {len(df.columns)} columns")
            check("Total assets = 71000", abs(df["current_value"].sum() - 71000.0) < 0.01, str(df["current_value"].sum()))

        # Verify computed metrics match JS sample-data.js
        df = create_sample_dataframe()
        metrics = compute_metrics(df)
        for key, expected in EXPECTED_METRICS.items():
            actual = metrics[key]
            if isinstance(expected, float):
                ok = abs(actual - expected) < 0.001
                check(f"Metric {key}", ok, f"actual={actual:.6f} expected={expected:.6f}")
            else:
                ok = actual == expected
                check(f"Metric {key}", ok, f"actual={actual} expected={expected}")

        # ──────────────────────────────────────────────
        # Summary
        # ──────────────────────────────────────────────
        print(f"\n{'='*50}")
        print(f"  Results: {passed} passed, {failed} failed ({passed + failed} total)")
        print(f"{'='*50}")

        browser.close()
        if failed > 0:
            sys.exit(1)


if __name__ == "__main__":
    run_tests()
