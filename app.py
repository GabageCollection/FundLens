"""FundLens — 本地化多平台资产快照分析系统 (main entry point)."""

import logging
from pathlib import Path

import streamlit as st

from utils.constants import KEY_BENCHMARK_CONFIG, KEY_BLUR_MODE, KEY_CURRENT_SNAPSHOT, KEY_SNAPSHOT_DATA, KEY_TARGET_ALLOCATION

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


def _inject_css_and_js() -> None:
    css_path = Path(__file__).resolve().parent / "assets" / "style.css"
    if css_path.exists():
        with open(css_path, encoding="utf-8") as f:
            st.markdown(f"<style>{f.read()}</style>", unsafe_allow_html=True)

    # 注入 JS 翻译 Streamlit 内置英文 UI
    st.components.v1.html("""
<script>
(function() {
    var parentDoc = window.parent.document;
    function t() {
        parentDoc.querySelectorAll('[role="menuitem"], [role="menuitemcheckbox"]').forEach(function(el) {
            var label = el.querySelector('[data-testid="stMainMenuItemLabel"]');
            if (label) {
                var txt = label.textContent.trim();
                if (txt.indexOf("Rerun")===0) label.textContent="重新运行";
                else if (txt.indexOf("Clear cache")===0) label.textContent="清除缓存";
                else if (txt.indexOf("Print")===0) label.textContent="打印";
                else if (txt.indexOf("Record")===0) label.textContent="录屏";
                else if (txt.indexOf("Settings")===0) label.textContent="设置";
                else if (txt.indexOf("About")===0) label.textContent="关于";
                var k=el.querySelector('kbd'); if(k) k.style.display='none';
            } else if (el.firstChild&&el.firstChild.nodeType===3) {
                if (el.firstChild.textContent.trim()==="Auto rerun") el.firstChild.textContent="自动刷新";
            }
        });
        parentDoc.querySelectorAll('a[href*="streamlit.io"]').forEach(function(a){a.style.display='none';});
    }
    var obs = new parentDoc.defaultView.MutationObserver(function() {
        var btn = parentDoc.querySelector('[data-testid="stMainMenuButton"]');
        if (btn && !btn._zhHooked) {
            btn._zhHooked = true;
            btn.addEventListener('click', function(){setTimeout(t,80);});
        }
    });
    obs.observe(parentDoc.body, {childList:true,subtree:true});
    setInterval(t, 1500);
})();
</script>
    """, height=0)


def _render_sidebar() -> None:
    """渲染侧边栏：品牌标识 + 快照选择器（在页面导航上方）。"""
    from utils.data_loader import read_asset_snapshot
    from utils.file_manager import get_snapshot_list

    # 品牌区域
    st.sidebar.markdown(
        '<div style="font-family:var(--font-display);font-size:var(--text-lg);font-weight:500;'
        'color:var(--accent);margin-bottom:var(--space-1);display:flex;align-items:center;gap:var(--space-2);">'
        '<span style="width:8px;height:8px;border-radius:50%;background:var(--accent);"></span>'
        'FundLens</div>',
        unsafe_allow_html=True,
    )
    st.sidebar.markdown(
        '<div style="font-size:var(--text-xs);color:var(--meta);margin-bottom:var(--space-4);">多平台资产快照分析</div>',
        unsafe_allow_html=True,
    )

    # 快照选择器
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

    st.sidebar.markdown('<div style="height:var(--space-4);"></div>', unsafe_allow_html=True)
    st.sidebar.page_link("pages/1_🏠_首页概览.py", label="首页概览", icon="🏠", width="stretch")
    st.sidebar.page_link("pages/2_📊_资产配置.py", label="资产配置", icon="📊", width="stretch")
    st.sidebar.page_link("pages/3_📈_收益分析.py", label="收益分析", icon="📈", width="stretch")
    st.sidebar.page_link("pages/4_📋_产品明细.py", label="产品明细", icon="📋", width="stretch")
    st.sidebar.page_link("pages/5_📥_数据导入.py", label="数据导入", icon="📥", width="stretch")
    st.sidebar.page_link("pages/6_🔍_数据校验.py", label="数据校验", icon="🔍", width="stretch")
    st.sidebar.page_link("pages/7_⚙️_设置.py", label="设置", icon="⚙️", width="stretch")


if __name__ == "__main__":
    st.set_page_config(
        page_title="FundLens — 资产快照分析",
        page_icon="💰",
        layout="wide",
        initial_sidebar_state="expanded",
    )
    _inject_css_and_js()
    _init_session_state()

    # 侧边栏：品牌 + 快照选择器（导航上方）
    _render_sidebar()

    # 页面导航（不含 "app" 落地页，默认首页概览）
    pages_dir = Path(__file__).resolve().parent / "pages"
    pages = [
        st.Page(str(pages_dir / "1_🏠_首页概览.py"), title="首页概览", icon="🏠", default=True),
        st.Page(str(pages_dir / "2_📊_资产配置.py"), title="资产配置", icon="📊"),
        st.Page(str(pages_dir / "3_📈_收益分析.py"), title="收益分析", icon="📈"),
        st.Page(str(pages_dir / "4_📋_产品明细.py"), title="产品明细", icon="📋"),
        st.Page(str(pages_dir / "5_📥_数据导入.py"), title="数据导入", icon="📥"),
        st.Page(str(pages_dir / "6_🔍_数据校验.py"), title="数据校验", icon="🔍"),
        st.Page(str(pages_dir / "7_⚙️_设置.py"), title="设置", icon="⚙️"),
    ]
    pg = st.navigation(pages, position="hidden")
    pg.run()

    # 侧边栏底部：隐私声明（导航下方）
    st.sidebar.markdown("---")
    st.sidebar.markdown(
        '<div class="sidebar-footer">所有数据仅在本地处理<br>不上传至任何外部服务器</div>',
        unsafe_allow_html=True,
    )
