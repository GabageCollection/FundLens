"""首页资产总览 — 核心看板，10 KPI 卡片 + 6 图表 + 数据质量提示。"""

import os
from pathlib import Path

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
from utils.constants import (
    KEY_BENCHMARK_CONFIG, KEY_BLUR_MODE, KEY_CURRENT_SNAPSHOT,
    KEY_SNAPSHOT_DATA, KEY_TARGET_ALLOCATION,
)
from utils.design_tokens import (
    ASSET_CLASS_COLORS, CHART_COLORS, COLOR_ACCENT,
    COLOR_LOSS, COLOR_META, COLOR_MUTED, COLOR_PROFIT, COLOR_WARNING,
)
from utils.ui_components import (
    render_data_quality_badges,
    render_kpi_card,
)

st.set_page_config(page_title="FundLens - 首页概览", page_icon="🏠", layout="wide")


def _fmt_money(val: float, blur: bool = False) -> str:
    if blur:
        return "¥***"
    return f"¥{val:,.0f}"


def _fmt_pct(val: float) -> str:
    return f"{val * 100:.1f}%"


# ─── 数据加载 ──────────────────────────────────────────

df = st.session_state.get(KEY_SNAPSHOT_DATA)

if df is None:
    st.markdown(
        '<div class="empty-state"><h3>暂无资产快照数据</h3>'
        '<p>请先通过侧边栏选择快照，或前往数据导入页面上传 Excel 文件</p></div>',
        unsafe_allow_html=True,
    )
    st.stop()

# ─── 指标计算 ─────────────────────────────────────────

total_assets = calc_total_assets(df)
total_profit = calc_total_profit(df)
total_return = calc_total_return(df)
coverage = calc_coverage(df)
product_count = calc_product_count(df)
platform_count = calc_platform_count(df)
max_ratio = calc_max_single_ratio(df)
equity_ratio = calc_equity_ratio(df)
total_cost = calc_total_cost(df)

# 模糊模式
blur = st.session_state.get(KEY_BLUR_MODE, False)

# 找出最大单品名称
top_holdings = calc_top10_holdings(df)
max_single_name = top_holdings.iloc[0]["product_name"] if not top_holdings.empty else "—"

# 平台名称列表
platform_dist_map = calc_platform_distribution(df)
platform_names = " · ".join(platform_dist_map.keys())

# 基准对比
benchmark_config = load_benchmark_config(st.session_state)
if benchmark_config.get("start_value") and benchmark_config.get("end_value"):
    bm_return = calc_benchmark_return(benchmark_config)
    relative = calc_relative_return(total_return, bm_return)
    bm_label = benchmark_config.get("name", "基准")
else:
    bm_return = None
    relative = None
    bm_label = "未配置"

# 目标配置偏离
target_alloc = st.session_state.get(KEY_TARGET_ALLOCATION, {})
if target_alloc:
    class_dist_map = calc_asset_class_distribution(df)
    total_val = sum(class_dist_map.values())
    current_pcts = {k: v / total_val for k, v in class_dist_map.items()} if total_val > 0 else {}
    over_count = 0
    for cls_name, target_pct in target_alloc.items():
        actual = current_pcts.get(cls_name, 0)
        if abs(actual - target_pct) > 0.05:
            over_count += 1
else:
    over_count = 0

# 收益覆盖率信息（用于数据质量卡片）
cost_missing_count = 0
if "cost_amount" in df.columns:
    cost_missing_count = df["cost_amount"].isna().sum()
cost_missing_products = []
if cost_missing_count > 0 and "product_name" in df.columns:
    missing_mask = df["cost_amount"].isna()
    cost_missing_products = df.loc[missing_mask, "product_name"].tolist()

# 亏损超 10% 产品数
loss_over10_count = 0
loss_over10_names = []
if "holding_return" in df.columns:
    loss_mask = df["holding_return"].notna() & (df["holding_return"] < -0.10)
    loss_over10_count = loss_mask.sum()
    if loss_over10_count > 0:
        loss_over10_names = df.loc[loss_mask, "product_name"].tolist()

# ─── 页面标题 ─────────────────────────────────────────

snapshot_name = st.session_state.get(KEY_CURRENT_SNAPSHOT, "")
date_str = df.iloc[0]["statistic_date"] if "statistic_date" in df.columns and len(df) > 0 else ""
date_text = str(date_str)[:10] if date_str and str(date_str) != "nan" else ""

st.markdown(
    '<div class="row-between" style="margin-bottom:var(--space-6);">'
    '<div>'
    '<h2 style="font-size:var(--text-3xl);margin-bottom:var(--space-1);">当前资产总览</h2>'
    f'<p style="color:var(--meta);font-size:var(--text-sm);">统计日期: {date_text}'
    f'{" · 快照: " + Path(snapshot_name).stem if snapshot_name else ""}</p>'
    '</div>'
    '</div>',
    unsafe_allow_html=True,
)

# 模糊模式切换
new_blur = st.toggle("🔒 模糊模式", value=blur, key="blur_toggle")
if new_blur != blur:
    st.session_state[KEY_BLUR_MODE] = new_blur
blur = new_blur

# ─── KPI 第一行：核心指标 ──────────────────────────────

profit_sign = "+" if total_profit >= 0 else ""
profit_level = "profit" if total_profit >= 0 else "loss"
return_sign = "+" if total_return >= 0 else ""

row1 = (
    render_kpi_card("总资产", _fmt_money(total_assets, blur), delta=f"全部 {product_count} 个产品")
    + render_kpi_card("总持有收益", f"{profit_sign}{_fmt_money(total_profit, blur)}",
                      delta="基于有成本数据的产品", alert_level=profit_level)
    + render_kpi_card("总收益率", f"{return_sign}{_fmt_pct(total_return)}",
                      delta="简单持有期收益率", alert_level=profit_level)
    + render_kpi_card("收益统计覆盖率", _fmt_pct(coverage),
                      delta="有成本资产 / 总资产")
)
st.markdown(
    f'<div class="grid-4" style="margin-bottom:var(--space-6);">{row1}</div>',
    unsafe_allow_html=True,
)

# ─── KPI 第二行：参考指标 ──────────────────────────────

row2 = (
    render_kpi_card("产品数量", f"{product_count} 个")
    + render_kpi_card("平台数量", f"{platform_count} 个", delta=platform_names)
    + render_kpi_card("最大单品占比", _fmt_pct(max_ratio),
                      delta=max_single_name if max_ratio > 0.2 else "",
                      alert_level="warning" if max_ratio > 0.2 else "normal")
    + render_kpi_card("权益类占比", _fmt_pct(equity_ratio),
                      delta="权益类资产 / 总资产")
)
st.markdown(
    f'<div class="grid-4" style="margin-bottom:var(--space-6);">{row2}</div>',
    unsafe_allow_html=True,
)

# ─── KPI 第三行：基准 + 目标（2 列）────────────────────

if relative is not None:
    benchmark_value = f"{'跑赢 ' if relative >= 0 else '跑输 '}{abs(relative) * 100:.2f}%"
    benchmark_level = "profit" if relative >= 0 else "loss"
    benchmark_sub = f"总收益率 {return_sign}{_fmt_pct(total_return)} vs 基准 {_fmt_pct(bm_return)}"
else:
    benchmark_value = "未配置"
    benchmark_level = "normal"
    benchmark_sub = "请前往设置页配置基准指数"

target_value = f"{over_count} 个大类偏离" if target_alloc else "未设定"
target_level = "warning" if over_count > 0 else "normal"
target_sub = "偏离超过 ±5% 的资产大类数量" if target_alloc else "请前往设置页设定目标配置比例"

row3 = (
    render_kpi_card(f"基准对比 ({bm_label})", benchmark_value,
                    delta=benchmark_sub, alert_level=benchmark_level)
    + render_kpi_card("目标配置偏离", target_value,
                      delta=target_sub, alert_level=target_level)
)
st.markdown(
    f'<div class="grid-2" style="margin-bottom:var(--space-6);">{row3}</div>',
    unsafe_allow_html=True,
)

# ─── 图表第一行：平台占比 + 资产大类占比 ───────────── ─

st.markdown('<div class="chart-row">', unsafe_allow_html=True)

st.markdown('<div class="chart-card"><h4>平台资产占比</h4><div class="chart-container">', unsafe_allow_html=True)
fig_platform = plot_pie(
    list(platform_dist_map.keys()), list(platform_dist_map.values()),
    "", CHART_COLORS,
)
st.plotly_chart(fig_platform, width='stretch')
st.markdown('</div></div>', unsafe_allow_html=True)

class_dist = calc_asset_class_distribution(df)
sorted_classes = sorted(class_dist.items(), key=lambda x: x[1], reverse=True)
class_labels = [c[0] for c in sorted_classes]
class_values = [c[1] for c in sorted_classes]
class_colors = [ASSET_CLASS_COLORS.get(c, CHART_COLORS[-1]) for c in class_labels]

st.markdown('<div class="chart-card"><h4>资产大类占比</h4><div class="chart-container">', unsafe_allow_html=True)
fig_class = plot_pie(class_labels, class_values, "", class_colors)
st.plotly_chart(fig_class, width='stretch')
st.markdown('</div></div>', unsafe_allow_html=True)

st.markdown('</div>', unsafe_allow_html=True)

# ─── 当前 vs 目标配置（全宽）──────────────────────────

st.markdown('<div class="chart-card" style="margin-bottom:var(--space-6);">', unsafe_allow_html=True)
st.markdown('<h4>当前 vs 目标配置对比</h4>', unsafe_allow_html=True)
if target_alloc:
    fig_bullet = plot_bullet(
        {k: current_pcts.get(k, 0) for k in target_alloc},
        target_alloc, "",
    )
    st.plotly_chart(fig_bullet, width='stretch')
else:
    st.info("未设定目标配置。请前往设置页设定后即可查看对比图。")
st.markdown('</div>', unsafe_allow_html=True)

# ─── 图表第二行：收益瀑布图 + 基准对比 ────────────────

st.markdown('<div class="chart-row">', unsafe_allow_html=True)

st.markdown('<div class="chart-card"><h4>收益贡献瀑布图</h4><div class="chart-container">', unsafe_allow_html=True)
profit_by_class = {}
for cls_name in class_dist:
    mask = df["asset_class"] == cls_name
    p = df.loc[mask, "holding_profit"].sum() if "holding_profit" in df.columns else 0
    profit_by_class[cls_name] = float(p) if not (isinstance(p, float) and p != p) else 0.0
cats = list(profit_by_class.keys())
vals = list(profit_by_class.values())
if any(abs(v) > 0.01 for v in vals):
    fig_waterfall = plot_waterfall(cats, vals, "")
    st.plotly_chart(fig_waterfall, width='stretch')
else:
    st.info("暂无收益数据，无法生成瀑布图")
st.markdown('</div></div>', unsafe_allow_html=True)

st.markdown('<div class="chart-card"><h4>基准对比</h4><div class="chart-container">', unsafe_allow_html=True)
if bm_return is not None:
    fig_bench = plot_dual_bar(
        ["总收益率", bm_label], [total_return, bm_return], [total_return, bm_return],
        "", name1="总收益率", name2=bm_label,
    )
    st.plotly_chart(fig_bench, width='stretch')
    rel_text = f"相对收益: {relative*100:+.2f}% ({'跑赢' if relative >= 0 else '跑输'})"
    st.markdown(
        f'<p style="text-align:center;color:{COLOR_PROFIT if relative >= 0 else COLOR_LOSS};'
        f'font-size:var(--text-sm);font-weight:600;">{rel_text}</p>',
        unsafe_allow_html=True,
    )
else:
    st.info("请前往设置页配置基准指数以启用基准对比图")
st.markdown('</div></div>', unsafe_allow_html=True)

st.markdown('</div>', unsafe_allow_html=True)

# ─── 图表第三行：产品持仓前十 + 亏损产品前十 ──────────

st.markdown('<div class="chart-row">', unsafe_allow_html=True)

st.markdown('<div class="chart-card"><h4>产品持仓 Top 10</h4><div class="chart-container">', unsafe_allow_html=True)
top10_holdings = calc_top10_holdings(df)
if not top10_holdings.empty:
    fig_holdings = plot_horizontal_bar(
        top10_holdings["product_name"].tolist(),
        top10_holdings["current_value"].tolist(),
        "", COLOR_ACCENT,
    )
    st.plotly_chart(fig_holdings, width='stretch')
else:
    st.info("暂无持仓数据")
st.markdown('</div></div>', unsafe_allow_html=True)

st.markdown('<div class="chart-card"><h4>亏损产品 Top 10</h4><div class="chart-container">', unsafe_allow_html=True)
top_losses = calc_top10_loss(df)
if not top_losses.empty:
    fig_loss = plot_horizontal_bar(
        top_losses["product_name"].tolist(),
        [abs(v) for v in top_losses["holding_profit"].tolist()],
        "", COLOR_LOSS,
    )
    st.plotly_chart(fig_loss, width='stretch')
else:
    st.markdown(
        '<div style="text-align:center;padding:var(--space-12);color:var(--meta);font-size:var(--text-sm);">暂无亏损产品</div>',
        unsafe_allow_html=True,
    )
st.markdown('</div></div>', unsafe_allow_html=True)

st.markdown('</div>', unsafe_allow_html=True)

# ─── 数据质量提示卡片 ──────────────────────────────────

st.markdown('<div class="card" style="margin-bottom:var(--space-6);">', unsafe_allow_html=True)
st.markdown('<h4 style="margin-bottom:var(--space-3);">数据质量提示</h4>', unsafe_allow_html=True)

badges = [{"text": f"收益覆盖率: {_fmt_pct(coverage)}", "variant": "success"}]

if cost_missing_count > 0:
    names = "、".join(cost_missing_products[:3])
    badges.append({
        "text": f"{cost_missing_count} 个产品缺少成本数据（{names}），不参与收益率统计",
        "variant": "warn"
    })

badges.append({"text": "收益率类型: 简单持有期收益率", "variant": "muted"})

if loss_over10_count > 0:
    names = "、".join(loss_over10_names[:3])
    badges.append({
        "text": f"{loss_over10_count} 个产品亏损率超过 10%（{names}）",
        "variant": "warn"
    })

st.markdown(render_data_quality_badges(badges), unsafe_allow_html=True)
st.markdown('</div>', unsafe_allow_html=True)
