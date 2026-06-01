"""收益分析页面 — 摘要统计、基准对比、收益分解、盈亏排行。"""

import streamlit as st
import pandas as pd

from utils.analyzer import (
    calc_asset_class_distribution, calc_coverage, calc_platform_distribution,
    calc_top10_loss, calc_top10_profit, calc_total_assets,
    calc_total_profit, calc_total_return,
)
from utils.benchmarks import calc_benchmark_return, calc_relative_return, load_benchmark_config
from utils.charts import plot_bar, plot_dual_bar, plot_grouped_bar, plot_horizontal_bar, plot_waterfall
from utils.constants import KEY_SNAPSHOT_DATA
from utils.design_tokens import CHART_COLORS, COLOR_ACCENT, COLOR_LOSS, COLOR_PROFIT
from utils.ui_components import render_kpi_card

st.set_page_config(page_title="FundLens - 收益分析", page_icon="📈", layout="wide")

df = st.session_state.get(KEY_SNAPSHOT_DATA)

if df is None:
    st.info("👈 请先通过侧边栏选择快照")
    st.stop()

# 计算指标
total_profit = calc_total_profit(df)
total_return = calc_total_return(df)
coverage = calc_coverage(df)
total_assets = calc_total_assets(df)

# 基准对比
benchmark_config = load_benchmark_config(st.session_state)
if benchmark_config.get("start_value") and benchmark_config.get("end_value"):
    bm_return = calc_benchmark_return(benchmark_config)
    relative = calc_relative_return(total_return, bm_return)
else:
    bm_return = None
    relative = None


def _fmt_pct(val: float) -> str:
    return f"{val*100:+.2f}%"


def _fmt_money(val: float) -> str:
    return f"¥{val:,.0f}"

# ─── 页面标题 ─────────────────────────────────────

st.markdown(
    '<h2 style="font-family:var(--font-display);font-size:var(--text-3xl);margin-bottom:var(--space-2);">📈 收益分析</h2>',
    unsafe_allow_html=True,
)
st.markdown(
    '<p style="color:var(--meta);font-size:var(--text-base);margin-bottom:var(--space-6);">收益摘要、基准对比、分类分解和盈亏排行</p>',
    unsafe_allow_html=True,
)

# ─── 摘要统计条 ───────────────────────────────────

profit_level = "profit" if total_profit >= 0 else "loss"
kpi_row = (
    render_kpi_card("总持有收益", _fmt_money(total_profit), alert_level=profit_level)
    + render_kpi_card("总收益率", _fmt_pct(total_return), alert_level=profit_level)
    + render_kpi_card("收益统计覆盖率", f"{coverage*100:.1f}%")
)

if relative is not None:
    rel_level = "profit" if relative >= 0 else "loss"
    kpi_row += render_kpi_card(
        f"相对收益（vs {benchmark_config['name']}）",
        _fmt_pct(relative),
        alert_level=rel_level
    )
else:
    kpi_row += render_kpi_card("相对收益", "未配置基准", alert_level="normal")

st.markdown(
    f'<div class="grid-4" style="margin-bottom:var(--space-6);">{kpi_row}</div>',
    unsafe_allow_html=True,
)

# ─── 算法说明 ──────────────────────────────────────

st.markdown(
    '<div class="card" style="background:var(--warn-bg);border-color:var(--warn);margin-bottom:var(--space-6);">'
    '<h4 style="margin-bottom:var(--space-2);">ⓘ 收益率算法说明</h4>'
    '<p style="font-size:var(--text-sm);color:var(--muted);line-height:var(--leading-body);">'
    '当前使用<strong>简单持有期收益率</strong> = 持有收益 / 持有成本。不反映资金投入的时间差异（如定投分散投入）。'
    '如需精确考虑时间因素，应使用时间加权收益率（TWR）或内部收益率（IRR）。'
    '</p></div>',
    unsafe_allow_html=True,
)

# ─── 基准对比图 ───────────────────────────────────

if bm_return is not None:
    st.markdown("### 基准对比")
    fig = plot_dual_bar(
        ["投资组合"], [total_return], [bm_return],
        f"组合收益对比 {benchmark_config['name']}",
        name1="投资组合", name2=benchmark_config.get("name", "基准"),
    )
    st.plotly_chart(fig, width='stretch')
    if relative is not None:
        rel_text = f"{'跑赢' if relative >= 0 else '跑输'}基准 {abs(relative)*100:.2f}%"
        st.markdown(f"组合收益率 {_fmt_pct(total_return)}，基准收益率 {_fmt_pct(bm_return)}，{rel_text}")

st.markdown("---")

# ─── 平台收益对比 ─────────────────────────────────

st.markdown("### 平台收益对比")
platform_dist = calc_platform_distribution(df)
platforms = list(platform_dist.keys())
if platforms and "holding_profit" in df.columns:
    platform_profits = []
    platform_losses = []
    for p in platforms:
        mask = df["platform"] == p
        profit = df.loc[mask, "holding_profit"].sum()
        platform_profits.append(max(float(profit), 0))
        platform_losses.append(abs(min(float(profit), 0)))
    if any(v > 0 for v in platform_profits + platform_losses):
        fig = plot_grouped_bar(
            platforms,
            [
                {"name": "盈利", "values": platform_profits, "color": COLOR_PROFIT},
                {"name": "亏损", "values": platform_losses, "color": COLOR_LOSS},
            ],
            "平台收益对比",
        )
        st.plotly_chart(fig, width='stretch')

# ─── 资产大类收益对比 ─────────────────────────────

st.markdown("### 资产大类收益对比")
class_dist = calc_asset_class_distribution(df)
classes = list(class_dist.keys())
if classes and "holding_profit" in df.columns:
    class_profits = []
    class_losses = []
    for c in classes:
        mask = df["asset_class"] == c
        profit = df.loc[mask, "holding_profit"].sum()
        class_profits.append(max(float(profit), 0))
        class_losses.append(abs(min(float(profit), 0)))
    if any(v > 0 for v in class_profits + class_losses):
        fig = plot_grouped_bar(
            classes,
            [
                {"name": "盈利", "values": class_profits, "color": COLOR_PROFIT},
                {"name": "亏损", "values": class_losses, "color": COLOR_LOSS},
            ],
            "资产大类收益对比",
        )
        st.plotly_chart(fig, width='stretch')

st.markdown("---")

# ─── 收益贡献瀑布图 ───────────────────────────────

st.markdown("### 收益贡献度分解")
class_dist = calc_asset_class_distribution(df)
profit_by_class = {}
for cls_name in class_dist:
    mask = df["asset_class"] == cls_name
    p = df.loc[mask, "holding_profit"].sum() if "holding_profit" in df.columns else 0
    profit_by_class[cls_name] = float(p) if not (isinstance(p, float) and p != p) else 0.0

cats = list(profit_by_class.keys())
vals = list(profit_by_class.values())
if any(abs(v) > 0.01 for v in vals):
    fig = plot_waterfall(cats, vals, "收益贡献度分解（按资产大类）")
    st.plotly_chart(fig, width='stretch')
else:
    st.info("暂无收益数据，无法生成瀑布图")

st.markdown("---")

# ─── 盈亏排行 ─────────────────────────────────────

profit_col, loss_col = st.columns(2)

with profit_col:
    st.markdown("### 产品盈利前十")
    top_profit = calc_top10_profit(df)
    if not top_profit.empty:
        fig = plot_horizontal_bar(
            top_profit["product_name"].tolist(),
            top_profit["holding_profit"].tolist(),
            "盈利 前十", COLOR_PROFIT,
        )
        st.plotly_chart(fig, width='stretch')
    else:
        st.info("无盈利产品")

with loss_col:
    st.markdown("### 产品亏损 前十")
    top_loss = calc_top10_loss(df)
    if not top_loss.empty:
        fig = plot_horizontal_bar(
            top_loss["product_name"].tolist(),
            [abs(v) for v in top_loss["holding_profit"].tolist()],
            "亏损 前十", COLOR_LOSS,
        )
        st.plotly_chart(fig, width='stretch')
    else:
        st.info("无亏损产品")

st.markdown("---")

# ─── 收益率 Top / Bottom 10 ───────────────────────

if "holding_return" in df.columns:
    ret_col1, ret_col2 = st.columns(2)
    mask = df["holding_return"].notna()
    df_ret = df[mask].copy()

    with ret_col1:
        st.markdown("### 收益率 前十")
        top_ret = df_ret.nlargest(10, "holding_return")[["product_name", "holding_return"]]
        if not top_ret.empty:
            top_ret["收益率"] = top_ret["holding_return"].apply(lambda x: f"{x*100:+.2f}%")
            st.dataframe(top_ret[["product_name", "收益率"]], width='stretch', hide_index=True)
        else:
            st.info("无数据")

    with ret_col2:
        st.markdown("### 亏损率 前十")
        bottom_ret = df_ret.nsmallest(10, "holding_return")[["product_name", "holding_return"]]
        if not bottom_ret.empty:
            bottom_ret["收益率"] = bottom_ret["holding_return"].apply(lambda x: f"{x*100:+.2f}%")
            st.dataframe(bottom_ret[["product_name", "收益率"]], width='stretch', hide_index=True)
        else:
            st.info("无数据")
