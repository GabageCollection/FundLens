"""首页资产总览 — 核心看板页面，10 个 KPI 卡片 + 6 个图表区域。"""

import streamlit as st

from utils.analyzer import (
    calc_asset_class_distribution, calc_coverage, calc_equity_ratio,
    calc_max_single_ratio, calc_platform_count, calc_platform_distribution,
    calc_product_count, calc_top10_holdings, calc_top10_loss, calc_top10_profit,
    calc_total_assets, calc_total_cost, calc_total_profit, calc_total_return,
)
from utils.benchmarks import calc_benchmark_return, calc_relative_return, load_benchmark_config
from utils.charts import (
    plot_bullet, plot_dual_bar, plot_horizontal_bar, plot_pie, plot_waterfall,
)
from utils.constants import KEY_BENCHMARK_CONFIG, KEY_CURRENT_SNAPSHOT, KEY_SNAPSHOT_DATA, KEY_TARGET_ALLOCATION
from utils.design_tokens import (
    ASSET_CLASS_COLORS, CHART_COLORS, COLOR_ACCENT,
    COLOR_LOSS, COLOR_META, COLOR_PROFIT, COLOR_WARNING,
)
from utils.ui_components import render_kpi_card, render_kpi_row
from utils.validator import generate_validation_report

st.set_page_config(
    page_title="FundLens - 首页概览",
    page_icon="🏠",
    layout="wide",
)


def _fmt_money(val: float) -> str:
    """格式化金额为 ¥x,xxx 格式。"""
    return f"¥{val:,.0f}"


def _fmt_pct(val: float) -> str:
    """格式化百分比为 x.x% 格式。"""
    return f"{val * 100:.1f}%"


def _fmt_delta(val: float) -> str:
    """格式化变化值，正数加 + 前缀。"""
    sign = "+" if val >= 0 else ""
    return f"{sign}{val * 100:.2f}%"


# ─── 数据加载 ──────────────────────────────────────────

df = st.session_state.get(KEY_SNAPSHOT_DATA)

if df is None:
    st.markdown(
        '<div class="empty-state"><h3>暂无资产快照数据</h3>'
        '<p>请先通过侧边栏选择快照，或前往数据导入页面上传 Excel 文件</p></div>',
        unsafe_allow_html=True,
    )
    st.stop()

# ─── 页面标题 ─────────────────────────────────────────

st.markdown(
    '<h2 style="font-family:Georgia,serif;">🏠 首页资产总览</h2>',
    unsafe_allow_html=True,
)
snapshot_name = st.session_state.get(KEY_CURRENT_SNAPSHOT, "")
if snapshot_name:
    st.markdown(
        f'<p style="color:{COLOR_META};font-size:14px;">当前快照: {snapshot_name}</p>',
        unsafe_allow_html=True,
    )

# ─── 关键指标计算 ─────────────────────────────────────

total_assets = calc_total_assets(df)
total_profit = calc_total_profit(df)
total_return = calc_total_return(df)
coverage = calc_coverage(df)
product_count = calc_product_count(df)
platform_count = calc_platform_count(df)
max_ratio = calc_max_single_ratio(df)
equity_ratio = calc_equity_ratio(df)
total_cost = calc_total_cost(df)

# ─── KPI 卡片 第一行 ──────────────────────────────────

profit_level = "profit" if total_profit >= 0 else "loss"
row1 = render_kpi_row([
    render_kpi_card("总资产", _fmt_money(total_assets), alert_level="normal"),
    render_kpi_card("总持有收益", f"{'+' if total_profit >= 0 else ''}{_fmt_money(total_profit)}",
                    alert_level=profit_level),
    render_kpi_card("总收益率", _fmt_pct(total_return), alert_level=profit_level,
                    delta="ⓘ 简单持有期收益率"),
    render_kpi_card("收益统计覆盖率", _fmt_pct(coverage),
                    alert_level="warning" if coverage < 0.5 else "normal"),
])
st.markdown(row1, unsafe_allow_html=True)

# ─── KPI 卡片 第二行 ─────────────────────────────────

max_ratio_level = "warning" if max_ratio > 0.2 else "normal"
row2 = render_kpi_row([
    render_kpi_card("产品数量", str(product_count), alert_level="normal"),
    render_kpi_card("平台数量", str(platform_count), alert_level="normal"),
    render_kpi_card("最大单品占比", _fmt_pct(max_ratio), alert_level=max_ratio_level,
                    delta=">20% 警示集中度" if max_ratio > 0.2 else ""),
    render_kpi_card("权益类占比", _fmt_pct(equity_ratio), alert_level="normal"),
])
st.markdown(row2, unsafe_allow_html=True)

# ─── KPI 卡片 第三行：基准对比 + 目标偏离 ─────────────

benchmark_config = load_benchmark_config(st.session_state)
if benchmark_config.get("start_value") and benchmark_config.get("end_value"):
    bm_return = calc_benchmark_return(benchmark_config)
    relative = calc_relative_return(total_return, bm_return)
    benchmark_label = f"基准 ({benchmark_config['name']})"
    benchmark_delta = f"相对收益 {_fmt_delta(relative)}"
    benchmark_level = "profit" if relative >= 0 else "loss"
else:
    bm_return = None
    benchmark_label = "基准对比"
    benchmark_delta = "未配置基准指数"
    benchmark_level = "normal"

target_alloc = st.session_state.get(KEY_TARGET_ALLOCATION, {})
if target_alloc:
    current_dist = calc_asset_class_distribution(df)
    total_val = sum(current_dist.values())
    current_pct = {k: v / total_val for k, v in current_dist.items()} if total_val > 0 else {}
    deviations = 0
    for cls_name, target_pct in target_alloc.items():
        actual = current_pct.get(cls_name, 0)
        if abs(actual - target_pct) > 0.05:
            deviations += 1
    target_label = "目标配置偏离"
    target_delta = f"{deviations} 个大类偏离 > ±5%" if deviations > 0 else "全部大类在目标范围内"
    target_level = "warning" if deviations > 0 else "normal"
else:
    target_label = "目标配置偏离"
    target_delta = "未设定目标配置"
    target_level = "normal"

row3 = render_kpi_row([
    render_kpi_card(benchmark_label, _fmt_pct(total_return), alert_level=benchmark_level,
                    delta=benchmark_delta),
    render_kpi_card(target_label, "", alert_level=target_level, delta=target_delta),
])
st.markdown(row3, unsafe_allow_html=True)

# ─── 图表区域 ────────────────────────────────────────

st.markdown("---")

# 第一行：平台占比 + 资产大类占比
col1, col2 = st.columns(2)
with col1:
    platform_dist = calc_platform_distribution(df)
    fig_platform = plot_pie(
        list(platform_dist.keys()), list(platform_dist.values()),
        "平台资产占比", CHART_COLORS,
    )
    st.plotly_chart(fig_platform, use_container_width=True)

with col2:
    class_dist = calc_asset_class_distribution(df)
    sorted_classes = sorted(class_dist.items(), key=lambda x: x[1], reverse=True)
    class_labels = [c[0] for c in sorted_classes]
    class_values = [c[1] for c in sorted_classes]
    class_colors = [ASSET_CLASS_COLORS.get(c, CHART_COLORS[-1]) for c in class_labels]
    fig_class = plot_pie(class_labels, class_values, "资产大类占比", class_colors)
    st.plotly_chart(fig_class, use_container_width=True)

# 第二行：目标配置对比 + 持仓 Top 10
col3, col4 = st.columns(2)
with col3:
    if target_alloc:
        current_pcts = {k: v / total_assets for k, v in class_dist.items()} if total_assets > 0 else {}
        fig_bullet = plot_bullet(
            {k: current_pcts.get(k, 0) for k in target_alloc},
            target_alloc,
            "当前 vs 目标配置",
        )
    else:
        fig_bullet = plot_bullet({}, {}, "当前 vs 目标配置")
    st.plotly_chart(fig_bullet, use_container_width=True)

with col4:
    top10 = calc_top10_holdings(df)
    if not top10.empty:
        fig_holdings = plot_horizontal_bar(
            top10["product_name"].tolist(),
            top10["current_value"].tolist(),
            "产品持仓 Top 10", COLOR_ACCENT,
        )
        st.plotly_chart(fig_holdings, use_container_width=True)
    else:
        st.info("暂无持仓数据")

# 第三行：收益贡献瀑布图 + 基准对比
col5, col6 = st.columns(2)
with col5:
    class_dist_all = calc_asset_class_distribution(df)
    profit_by_class = {}
    for cls_name in class_dist_all:
        mask = df["asset_class"] == cls_name
        cls_profit = df.loc[mask, "holding_profit"].sum() if "holding_profit" in df.columns else 0
        cls_profit = cls_profit if not (isinstance(cls_profit, float) and cls_profit != cls_profit) else 0.0
        profit_by_class[cls_name] = float(cls_profit)

    cats = list(profit_by_class.keys())
    vals = list(profit_by_class.values())
    # 过滤全部为 0 的情况
    if any(abs(v) > 0.01 for v in vals):
        fig_waterfall = plot_waterfall(cats, vals, "收益贡献度分解")
        st.plotly_chart(fig_waterfall, use_container_width=True)
    else:
        st.info("暂无收益数据，无法生成瀑布图")

with col6:
    if bm_return is not None:
        fig_bench = plot_dual_bar(
            ["投资组合"], [total_return], [bm_return],
            "组合 vs 基准收益",
            name1="投资组合", name2=benchmark_config.get("name", "基准"),
        )
        st.plotly_chart(fig_bench, use_container_width=True)
    else:
        st.info("请前往设置页配置基准指数以启用基准对比图")

# 亏损产品 Top 10
top_losses = calc_top10_loss(df)
if not top_losses.empty and len(top_losses) > 0:
    st.markdown("### 亏损产品 Top 10")
    fig_loss = plot_horizontal_bar(
        top_losses["product_name"].tolist(),
        [abs(v) for v in top_losses["holding_profit"].tolist()],
        "亏损产品 Top 10", COLOR_LOSS,
    )
    st.plotly_chart(fig_loss, use_container_width=True)

# ─── 数据质量提示 ────────────────────────────────────

st.markdown("---")
report = generate_validation_report(df)
s = report["summary"]
st.markdown(
    f'<div class="chart-card">'
    f'<strong>数据质量</strong>'
    f'<div style="color:{COLOR_META};font-size:14px;margin-top:8px;">'
    f'收益覆盖率: {_fmt_pct(coverage)} &nbsp;|&nbsp; '
    f'校验阻断: <span style="color:red;">{s["error_count"]}</span> &nbsp;|&nbsp; '
    f'校验警告: <span style="color:orange;">{s["warning_count"]}</span> &nbsp;|&nbsp; '
    f'自动修复: <span style="color:green;">{s["fix_count"]}</span>'
    f'</div></div>',
    unsafe_allow_html=True,
)
