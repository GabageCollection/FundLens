"""设置页面 — 基准指数配置、目标配置比例、图表偏好、数据管理。"""

import streamlit as st

from utils.benchmarks import load_benchmark_config, save_benchmark_config
from utils.constants import KEY_BENCHMARK_CONFIG, KEY_BLUR_MODE, KEY_TARGET_ALLOCATION, KEY_SNAPSHOT_DATA, KEY_CURRENT_SNAPSHOT
from utils.file_manager import get_snapshot_list

st.set_page_config(page_title="FundLens - 设置", page_icon="⚙️", layout="wide")

st.markdown(
    '<h2 style="font-family:var(--font-display);font-size:var(--text-3xl);margin-bottom:var(--space-2);">⚙️ 设置</h2>',
    unsafe_allow_html=True,
)
st.markdown(
    '<p style="color:var(--meta);font-size:var(--text-base);margin-bottom:var(--space-6);">配置基准指数、目标配置比例、偏好和数据管理</p>',
    unsafe_allow_html=True,
)

# ─── 基准指数配置 ────────────────────────────────

st.markdown('<div class="settings-section">', unsafe_allow_html=True)
st.markdown('<h4>📊 基准指数配置</h4>', unsafe_allow_html=True)
st.markdown(
    '<p style="color:var(--muted);font-size:var(--text-sm);margin-bottom:var(--space-4);">设定一个基准指数用于对比投资组合表现。</p>',
    unsafe_allow_html=True,
)

bm_config = load_benchmark_config(st.session_state)

col1, col2, col3 = st.columns(3)
with col1:
    bm_name = st.text_input("基准名称", value=bm_config.get("name", ""), placeholder="如: 沪深300")
with col2:
    bm_start = st.number_input("期初值（点位）", value=bm_config.get("start_value") or 0.0, step=100.0, format="%.2f")
with col3:
    bm_end = st.number_input("期末值（点位）", value=bm_config.get("end_value") or 0.0, step=100.0, format="%.2f")

if bm_start and bm_end and bm_start > 0:
    bm_return = (bm_end - bm_start) / bm_start * 100
    st.markdown(
        f'<p style="color:var(--fg);font-size:var(--text-sm);">基准收益率: <strong>{bm_return:+.2f}%</strong>（公式: ({bm_end:.0f} - {bm_start:.0f}) / {bm_start:.0f}）</p>',
        unsafe_allow_html=True,
    )

col_save, col_reset = st.columns([1, 4])
if col_save.button("💾 保存基准配置", type="primary"):
    save_benchmark_config(st.session_state, bm_name, bm_start, bm_end)
    st.success("✅ 基准配置已保存")
if col_reset.button("🔄 重置"):
    st.session_state[KEY_BENCHMARK_CONFIG] = {"name": "", "start_value": None, "end_value": None}
    st.rerun()

st.markdown('</div>', unsafe_allow_html=True)

# ─── 目标配置比例 ────────────────────────────────

st.markdown('<div class="settings-section">', unsafe_allow_html=True)
st.markdown('<h4>🎯 目标配置比例</h4>', unsafe_allow_html=True)
st.markdown(
    '<p style="color:var(--muted);font-size:var(--text-sm);margin-bottom:var(--space-4);">设定各资产大类的目标配置比例，总和应为 100%。</p>',
    unsafe_allow_html=True,
)

target = st.session_state.get(KEY_TARGET_ALLOCATION, {})

ASSET_CLASSES = ["现金类", "固收类", "固收增强类", "权益类", "跨境类", "其他类"]

new_target = {}
cols = st.columns(3)
for i, cls_name in enumerate(ASSET_CLASSES):
    with cols[i % 3]:
        default_val = int((target.get(cls_name, 0) or 0) * 100)
        pct = st.number_input(f"{cls_name} (%)", min_value=0, max_value=100, value=default_val, step=1, key=f"target_{cls_name}")
        new_target[cls_name] = pct / 100.0

total_pct = sum(new_target.values()) * 100
if abs(total_pct - 100.0) > 0.5:
    st.warning(f"⚠ 当前总和为 {total_pct:.0f}%，不等于 100%。请调整各比例使其总和为 100%。")
else:
    st.success(f"✓ 总和为 {total_pct:.0f}%，配置一致")

col_t1, col_t2 = st.columns([1, 4])
if col_t1.button("💾 保存目标配置", type="primary"):
    st.session_state[KEY_TARGET_ALLOCATION] = {k: v for k, v in new_target.items() if v > 0}
    st.success("✅ 目标配置已保存")
if col_t2.button("🔄 重置目标配置"):
    st.session_state[KEY_TARGET_ALLOCATION] = {}
    st.rerun()

st.markdown('</div>', unsafe_allow_html=True)

# ─── 偏好设置 ────────────────────────────────────

st.markdown('<div class="settings-section">', unsafe_allow_html=True)
st.markdown('<h4>⚙️ 偏好设置</h4>', unsafe_allow_html=True)

blur_mode = st.toggle("🔒 模糊模式（隐藏具体金额，仅显示百分比）", value=st.session_state.get(KEY_BLUR_MODE, False))
st.session_state[KEY_BLUR_MODE] = blur_mode

st.markdown('</div>', unsafe_allow_html=True)
if blur_mode:
    st.info("模糊模式已开启：首页和分析页面的具体金额将被隐藏，仅显示百分比和比率。")

# ─── 数据管理 ────────────────────────────────────

st.markdown("---")
st.markdown("### 🗂️ 数据管理")

snapshots = get_snapshot_list()
if snapshots:
    st.markdown(f"已保存 **{len(snapshots)}** 个快照")
    for s in snapshots:
        col_s1, col_s2 = st.columns([4, 1])
        col_s1.markdown(f"- **{s['name']}** ({s.get('date', '未知日期')})")
        if col_s2.button("🗑️ 删除", key=f"del_{s['path']}"):
            from pathlib import Path
            p = Path(s["path"])
            if p.exists():
                p.unlink()
                st.success(f"已删除 {s['name']}")
                st.rerun()
else:
    st.info("暂无已保存的快照")

# 全部导出按钮
if snapshots and "export_all" not in st.session_state:
    st.markdown("---")
    if st.button("📦 导出全部数据（备份）"):
        import io
        import zipfile
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zf:
            for s in snapshots:
                zf.write(s["path"], f"{s['name']}.xlsx")
        st.download_button("📥 下载备份 ZIP", data=zip_buffer.getvalue(),
                          file_name="FundLens_全量备份.zip", mime="application/zip")

# ─── 关于 ─────────────────────────────────────────

st.markdown("---")
st.markdown("### ℹ️ 关于 FundLens")
st.markdown('<div style="color:var(--meta);font-size:13px;">版本: v1.0.0 (Phase 6)<br>'
            '技术栈: Python 3.10+ / Streamlit / Pandas / Plotly / OpenPyXL<br>'
            '定位: 本地化多平台资产快照分析系统 — 客观呈现，不做决策代劳</div>',
            unsafe_allow_html=True)
