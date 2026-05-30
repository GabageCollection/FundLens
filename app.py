"""FundLens — 本地化多平台资产快照分析系统 (main entry point)."""

import logging
from pathlib import Path

import streamlit as st

from utils.constants import KEY_BENCHMARK_CONFIG, KEY_BLUR_MODE, KEY_CURRENT_SNAPSHOT, KEY_SNAPSHOT_DATA, KEY_TARGET_ALLOCATION
from utils.design_tokens import COLOR_META

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)


def _init_session_state() -> None:
    defaults = {
        KEY_CURRENT_SNAPSHOT: None,
        KEY_SNAPSHOT_DATA: None,
        KEY_BENCHMARK_CONFIG: {"name": "", "start_value": None, "end_value": None},
        KEY_TARGET_ALLOCATION: {},
        KEY_BLUR_MODE: False,
    }
    for key, default in defaults.items():
        if key not in st.session_state:
            st.session_state[key] = default


def _inject_css() -> None:
    css_path = Path(__file__).resolve().parent / "assets" / "style.css"
    if css_path.exists():
        with open(css_path, encoding="utf-8") as f:
            st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)


def _render_sidebar() -> None:
    from utils.data_loader import read_asset_snapshot
    from utils.file_manager import get_snapshot_list

    st.sidebar.markdown(
        '<div style="font-family:Georgia,serif;font-size:22px;font-weight:700;color:#c96442;'
        'margin-bottom:8px;">FundLens</div>',
        unsafe_allow_html=True,
    )
    st.sidebar.markdown(
        '<div style="font-size:12px;color:#87867f;margin-bottom:16px;">多平台资产快照分析</div>',
        unsafe_allow_html=True,
    )

    snapshots = get_snapshot_list()
    if snapshots:
        options = ["— 选择快照 —"] + [s["name"] for s in snapshots]
        selected_idx = 0
        current = st.session_state.get(KEY_CURRENT_SNAPSHOT)
        if current:
            for i, s in enumerate(snapshots):
                if s["path"] == current:
                    selected_idx = i + 1
                    break
        selected_label = st.sidebar.selectbox(
            "📂 快照切换",
            options,
            index=selected_idx,
            label_visibility="collapsed",
        )
        if selected_label != "— 选择快照 —":
            chosen = next(s for s in snapshots if s["name"] == selected_label)
            if chosen["path"] != st.session_state.get(KEY_CURRENT_SNAPSHOT):
                st.session_state[KEY_CURRENT_SNAPSHOT] = chosen["path"]
                try:
                    st.session_state[KEY_SNAPSHOT_DATA] = read_asset_snapshot(chosen["path"])
                    logger.info("Switched to snapshot: %s", chosen["path"])
                except (FileNotFoundError, ValueError, KeyError) as e:
                    logger.warning("Failed to load snapshot: %s", e)
                    st.sidebar.error("无法加载所选快照")
                    st.session_state[KEY_SNAPSHOT_DATA] = None
    else:
        st.sidebar.info("暂无已导入快照")

    st.sidebar.markdown("---")
    st.sidebar.markdown(
        '<div style="font-size:11px;color:#87867f;text-transform:uppercase;'
        'letter-spacing:0.05em;margin-bottom:8px;">导航</div>',
        unsafe_allow_html=True,
    )
    st.sidebar.markdown("---")
    st.sidebar.markdown(
        '<div class="sidebar-footer">所有数据仅在本地处理<br>不上传至任何外部服务器</div>',
        unsafe_allow_html=True,
    )


def _render_main() -> None:
    st.title("FundLens")
    st.markdown(
        f'<span style="color:{COLOR_META};font-size:14px;">'
        "本地化多平台资产快照分析系统 — 上传 Excel 快照，统一查看支付宝/同花顺资产全景"
        "</span>",
        unsafe_allow_html=True,
    )
    if st.session_state.get(KEY_SNAPSHOT_DATA) is None:
        st.info("👈 请先通过侧边栏选择快照，或前往 **数据导入** 页面上传 Excel 文件。")


if __name__ == "__main__":
    st.set_page_config(
        page_title="FundLens — 资产快照分析",
        page_icon="💰",
        layout="wide",
        initial_sidebar_state="expanded",
    )
    _inject_css()
    _init_session_state()
    _render_sidebar()
    _render_main()
