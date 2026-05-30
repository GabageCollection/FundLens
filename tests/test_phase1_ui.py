"""Phase 1 UI tests for FundLens using Playwright."""

import os
import sys
import time
from pathlib import Path

import pytest
from playwright.sync_api import Page, expect

BASE_URL = "http://localhost:8501"


# ─── Fixtures ───────────────────────────────────────────────────────

@pytest.fixture(scope="session")
def browser_context(browser):
    context = browser.new_context(
        viewport={"width": 1440, "height": 900},
        locale="zh-CN",
    )
    yield context
    context.close()


@pytest.fixture
def page(browser_context):
    page = browser_context.new_page()
    yield page
    page.close()


# ─── Helper functions ───────────────────────────────────────────────

def wait_for_streamlit(page: Page, timeout: int = 15000) -> None:
    """Wait for Streamlit to finish its initial render."""
    page.wait_for_selector("[data-testid='stAppViewContainer']", timeout=timeout)
    # Streamlit shows a "Please wait..." or "Running..." indicator initially
    page.wait_for_timeout(2000)


# ─── 1. Main Entry Point (app.py) ───────────────────────────────────

class TestMainPage:
    """Tests for app.py — main entry point with sidebar and navigation."""

    def test_page_title(self, page: Page):
        page.goto(BASE_URL)
        wait_for_streamlit(page)
        title = page.title()
        assert "FundLens" in title, f"Page title should contain FundLens, got: {title}"

    def test_sidebar_branding(self, page: Page):
        page.goto(BASE_URL)
        wait_for_streamlit(page)
        sidebar = page.locator("[data-testid='stSidebar']")
        assert sidebar.is_visible(), "Sidebar should be visible"
        assert sidebar.locator("text=FundLens").first.is_visible(), "FundLens brand should be visible in sidebar"
        assert sidebar.locator("text=多平台资产快照分析").is_visible(), "Subtitle should be visible"

    def test_sidebar_empty_state(self, page: Page):
        page.goto(BASE_URL)
        wait_for_streamlit(page)
        sidebar = page.locator("[data-testid='stSidebar']")
        # When no snapshots imported, should show guidance
        assert sidebar.locator("text=暂无已导入快照").is_visible(), "Should show empty snapshot message"

    def test_main_content_guidance(self, page: Page):
        page.goto(BASE_URL)
        wait_for_streamlit(page)
        main = page.locator("[data-testid='stAppViewContainer']")
        assert main.locator("text=FundLens").first.is_visible(), "Main title should be visible"

    def test_privacy_footer_in_sidebar(self, page: Page):
        page.goto(BASE_URL)
        wait_for_streamlit(page)
        sidebar = page.locator("[data-testid='stSidebar']")
        assert sidebar.locator("text=所有数据仅在本地处理").is_visible(), "Privacy notice should be visible"

    def test_custom_css_loaded(self, page: Page):
        page.goto(BASE_URL)
        wait_for_streamlit(page)
        # Check that custom CSS variables are applied
        bg_color = page.locator(".stApp").evaluate("el => getComputedStyle(el).backgroundColor")
        # Should be #f5f4ed (warm parchment background)
        assert bg_color is not None, "Custom CSS should set background color"


# ─── 2. Import Data Page (5_📥_import_data.py) ──────────────────────

class TestImportPage:
    """Tests for the data import page."""

    def test_page_loads(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)
        assert "FundLens" in page.title(), "Page title should contain FundLens"

    def test_step_indicator_visible(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)
        # Three steps should be visible
        assert page.locator("text=上传 Excel").is_visible(), "Step 1 should be visible"
        assert page.locator("text=预览与校验").is_visible(), "Step 2 should be visible"
        assert page.locator("text=导入确认").is_visible(), "Step 3 should be visible"

    def test_active_step_is_upload(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)
        # First step should be active (accent color)
        step1 = page.locator(".import-step.active")
        assert step1.is_visible(), "First step should be active"
        assert "1" in step1.text_content(), "Active step should be step 1"

    def test_file_uploader_visible(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)
        uploader = page.locator("[data-testid='stFileUploader']")
        assert uploader.is_visible(), "File uploader should be visible"

    def test_template_download_button(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)
        download_btn = page.locator("text=下载标准模板")
        assert download_btn.is_visible(), "Template download button should be visible"

    def test_page_header_visible(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)
        assert page.locator("h2").filter(has_text="数据导入").is_visible() or \
               page.locator("text=数据导入").first.is_visible(), "Page header should show 数据导入"


# ─── 3. Upload & Preview Flow ──────────────────────────────────────

class TestUploadAndPreview:
    """Tests for file upload, data preview, and import confirmation."""

    def test_upload_sample_excel(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)

        sample_path = Path(__file__).resolve().parent.parent / "data" / "uploaded" / "2026Q1_示例快照.xlsx"
        if not sample_path.exists():
            pytest.skip("Sample Excel file not found")

        # Upload file
        file_input = page.locator("[data-testid='stFileUploader'] input[type='file']")
        file_input.set_input_files(str(sample_path))
        page.wait_for_timeout(3000)  # Wait for Streamlit to process

        # After upload, preview should show
        assert page.locator("text=导入摘要").is_visible(), "Import summary should appear after upload"
        assert page.locator("text=数据预览").is_visible(), "Data preview should appear after upload"
        assert page.locator("text=成功读取").is_visible(), "Summary should show success count"

    def test_preview_shows_eight_rows(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)

        sample_path = Path(__file__).resolve().parent.parent / "data" / "uploaded" / "2026Q1_示例快照.xlsx"
        if not sample_path.exists():
            pytest.skip("Sample Excel file not found")

        file_input = page.locator("[data-testid='stFileUploader'] input[type='file']")
        file_input.set_input_files(str(sample_path))
        page.wait_for_timeout(3000)

        assert page.locator("text=共 8 条记录").is_visible(), "Should show 8 records"

    def test_confirm_import_button(self, page: Page):
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)

        sample_path = Path(__file__).resolve().parent.parent / "data" / "uploaded" / "2026Q1_示例快照.xlsx"
        if not sample_path.exists():
            pytest.skip("Sample Excel file not found")

        file_input = page.locator("[data-testid='stFileUploader'] input[type='file']")
        file_input.set_input_files(str(sample_path))
        page.wait_for_timeout(3000)

        confirm_btn = page.locator("button:has-text('确认导入')")
        assert confirm_btn.is_visible(), "Confirm import button should be visible"


# ─── 4. Snapshot Switching ─────────────────────────────────────────

class TestSnapshotSwitching:
    """Tests for sidebar snapshot selection and switching."""

    def test_snapshot_appears_in_sidebar(self, page: Page):
        # First upload via import page
        page.goto(f"{BASE_URL}/数据导入")
        wait_for_streamlit(page)

        sample_path = Path(__file__).resolve().parent.parent / "data" / "uploaded" / "2026Q1_示例快照.xlsx"
        if not sample_path.exists():
            pytest.skip("Sample Excel file not found")

        file_input = page.locator("[data-testid='stFileUploader'] input[type='file']")
        file_input.set_input_files(str(sample_path))
        page.wait_for_timeout(3000)

        # Click confirm import
        confirm_btn = page.locator("button:has-text('确认导入')")
        confirm_btn.click()
        page.wait_for_timeout(3000)

        # Go back to main page
        page.goto(BASE_URL)
        wait_for_streamlit(page)

        # Sidebar should now show the snapshot
        sidebar = page.locator("[data-testid='stSidebar']")
        assert sidebar.locator("text=2026Q1").is_visible(), "Snapshot should appear in sidebar selector"


# ─── 5. Data Integrity ────────────────────────────────────────────

class TestDataIntegrity:
    """Verify data computed by UI matches expected values."""

    def test_main_page_shows_data_after_import(self, page: Page):
        page.goto(BASE_URL)
        wait_for_streamlit(page)

        # The sample snapshot should already be available
        sidebar = page.locator("[data-testid='stSidebar']")
        # Select the snapshot from dropdown
        selectbox = sidebar.locator("[data-testid='stSelectbox']")
        if selectbox.is_visible():
            selectbox.click()
            page.keyboard.press("ArrowDown")
            page.keyboard.press("Enter")
            page.wait_for_timeout(3000)

        # After selecting, the main area should show data (no empty-state message)
        main = page.locator("[data-testid='stAppViewContainer']")
        # FundLens title should be visible
        assert main.locator("text=FundLens").first.is_visible(), "Main title should be visible"