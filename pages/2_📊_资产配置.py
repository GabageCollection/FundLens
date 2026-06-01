"""资产配置页面 — Tab 切换：配置总览 / 目标 vs 当前 / 详细维度。"""

import streamlit as st
import pandas as pd

from utils.analyzer import (
    calc_asset_class_distribution, calc_platform_distribution,
    calc_max_single_ratio, calc_total_assets, calc_top10_holdings,
)
from utils.charts import plot_pie, plot_bullet, plot_horizontal_bar, plot_grouped_bar
from utils.constants import KEY_SNAPSHOT_DATA, KEY_TARGET_ALLOCATION
from utils.design_tokens import ASSET_CLASS_COLORS, CHART_COLORS, COLOR_ACCENT

st.set_page_config(page_title="FundLens - 资产配置", page_icon="📊", layout="wide")

df = st.session_state.get(KEY_SNAPSHOT_DATA)
target_alloc = st.session_state.get(KEY_TARGET_ALLOCATION, {})

if df is None:
    st.info("👈 请先通过侧边栏选择快照")
    st.stop()

st.markdown(
    '<h2 style="font-family:var(--font-display);font-size:var(--text-3xl);margin-bottom:var(--space-2);">📊 资产配置</h2>',
    unsafe_allow_html=True,
)
st.markdown(
    '<p style="color:var(--meta);font-size:var(--text-base);margin-bottom:var(--space-6);">多维度配置分析、目标对比和集中度监控</p>',
    unsafe_allow_html=True,
)

# ─── Tab 切换 ───────────────────────────────────────

tab1, tab2, tab3 = st.tabs(["配置总览", "目标 vs 当前", "详细维度"])

# ─── Tab 1: 配置总览 ────────────────────────────────

with tab1:
    st.markdown('<h3 style="font-family:var(--font-display);font-size:var(--text-xl);margin-bottom:var(--space-4);">配置总览</h3>', unsafe_allow_html=True)

    # 计算多维度分布
    total = calc_total_assets(df)

    # 平台分布
    platform_dist = calc_platform_distribution(df)
    # 大类分布
    class_dist = calc_asset_class_distribution(df)
    # 产品类型分布
    if "product_type" in df.columns:
        type_dist = df.groupby("product_type")["current_value"].sum().to_dict()
    else:
        type_dist = {}
    # 市场区域分布
    if "market_region" in df.columns:
        region_dist = df.groupby("market_region")["current_value"].sum().to_dict()
    else:
        region_dist = {}
    # 资金用途分布
    if "usage_purpose" in df.columns:
        usage_dist = df.groupby("usage_purpose")["current_value"].sum().to_dict()
        # 过滤空值
        usage_dist = {k: v for k, v in usage_dist.items() if pd.notna(k) and k}
    else:
        usage_dist = {}
    # 风险等级分布
    if "risk_level" in df.columns:
        risk_dist = df.groupby("risk_level")["current_value"].sum().to_dict()
    else:
        risk_dist = {}

    st.markdown('<div class="grid-3">', unsafe_allow_html=True)

    if platform_dist:
        st.markdown('<div class="chart-card"><h4>按平台</h4><div class="chart-container">', unsafe_allow_html=True)
        fig = plot_pie(list(platform_dist.keys()), list(platform_dist.values()), "", CHART_COLORS)
        st.plotly_chart(fig, width='stretch')
        st.markdown('</div></div>', unsafe_allow_html=True)

    if class_dist:
        st.markdown('<div class="chart-card"><h4>按资产大类</h4><div class="chart-container">', unsafe_allow_html=True)
        class_colors = [ASSET_CLASS_COLORS.get(c, CHART_COLORS[-1]) for c in class_dist]
        fig = plot_pie(list(class_dist.keys()), list(class_dist.values()), "", class_colors)
        st.plotly_chart(fig, width='stretch')
        st.markdown('</div></div>', unsafe_allow_html=True)

    if type_dist:
        st.markdown('<div class="chart-card"><h4>按产品类型</h4><div class="chart-container">', unsafe_allow_html=True)
        fig = plot_pie(list(type_dist.keys()), list(type_dist.values()), "", CHART_COLORS)
        st.plotly_chart(fig, width='stretch')
        st.markdown('</div></div>', unsafe_allow_html=True)

    st.markdown('</div>', unsafe_allow_html=True)

    st.markdown('<div class="grid-3" style="margin-top:var(--space-6);">', unsafe_allow_html=True)

    if region_dist:
        st.markdown('<div class="chart-card"><h4>按市场区域</h4><div class="chart-container">', unsafe_allow_html=True)
        fig = plot_pie(list(region_dist.keys()), list(region_dist.values()), "", CHART_COLORS)
        st.plotly_chart(fig, width='stretch')
        st.markdown('</div></div>', unsafe_allow_html=True)

    if usage_dist:
        st.markdown('<div class="chart-card"><h4>按资金用途</h4><div class="chart-container">', unsafe_allow_html=True)
        fig = plot_pie(list(usage_dist.keys()), list(usage_dist.values()), "", CHART_COLORS)
        st.plotly_chart(fig, width='stretch')
        st.markdown('</div></div>', unsafe_allow_html=True)

    if risk_dist:
        st.markdown('<div class="chart-card"><h4>按风险等级</h4><div class="chart-container">', unsafe_allow_html=True)
        fig = plot_pie(list(risk_dist.keys()), list(risk_dist.values()), "", CHART_COLORS)
        st.plotly_chart(fig, width='stretch')
        st.markdown('</div></div>', unsafe_allow_html=True)

    st.markdown('</div>', unsafe_allow_html=True)

# ─── Tab 2: 目标 vs 当前 ───────────────────────────

with tab2:
    st.markdown("### 目标 vs 当前配置")

    class_dist = calc_asset_class_distribution(df)
    total_assets = calc_total_assets(df)

    if target_alloc:
        current_pcts = {k: v / total_assets for k, v in class_dist.items()} if total_assets > 0 else {}
        fig = plot_bullet(current_pcts, target_alloc, "当前 vs 目标配置")
        st.plotly_chart(fig, width='stretch')

        # 偏离详情表
        st.markdown("#### 偏离详情")
        rows = []
        for cls_name, target_pct in target_alloc.items():
            actual = current_pcts.get(cls_name, 0)
            deviation = actual - target_pct
            status = "⚠ 偏离" if abs(deviation) > 0.05 else "✓ 正常"
            rows.append({
                "资产大类": cls_name, "目标": f"{target_pct*100:.1f}%",
                "当前": f"{actual*100:.1f}%", "偏离": f"{deviation*100:+.1f}%", "状态": status,
            })
        st.dataframe(pd.DataFrame(rows), width='stretch', hide_index=True)
    else:
        st.info("未设定目标配置。请前往设置页设定各资产大类的目标配置比例。")

    # 单产品集中度
    st.markdown("### 单产品集中度")
    max_ratio = calc_max_single_ratio(df)
    st.markdown(
        f'<div class="kpi-card{" warn-card" if max_ratio > 0.2 else ""}">'
        f'<div class="kpi-label">最大单品占比</div>'
        f'<div class="kpi-value" style="color:var(--{"warn" if max_ratio > 0.2 else "meta"});">'
        f'{max_ratio*100:.1f}%</div>'
        f'<div class="kpi-sub">{"⚠ 占比超过 20%，建议关注集中度风险" if max_ratio > 0.2 else "集中度正常"}</div></div>',
        unsafe_allow_html=True,
    )

    top10 = calc_top10_holdings(df)
    if not top10.empty:
        fig = plot_horizontal_bar(top10["product_name"].tolist(), top10["current_value"].tolist(),
                                   "产品持仓详情", COLOR_ACCENT)
        st.plotly_chart(fig, width='stretch')

    # 集中度提示
    if max_ratio > 0.2:
        top_name = top10.iloc[0]["product_name"] if not top10.empty else "某产品"
        st.warning(f"⚠ {top_name} 占比 {max_ratio*100:.1f}%，超过 20% 阈值。本系统不提供投资建议，请根据自身风险偏好判断。")

# ─── Tab 3: 详细维度 ───────────────────────────────

with tab3:
    st.markdown("### 详细维度分析")

    # 流动性分布
    if "liquidity" in df.columns:
        st.markdown("#### 流动性分布")
        liq_dist = df.groupby("liquidity")["current_value"].sum().to_dict()
        if liq_dist:
            fig = plot_pie(list(liq_dist.keys()), list(liq_dist.values()), "流动性分布", CHART_COLORS[:3])
            st.plotly_chart(fig, width='stretch')

    # 平台 × 大类交叉分析
    if "platform" in df.columns and "asset_class" in df.columns:
        st.markdown("#### 平台 × 大类交叉分析")
        cross = df.groupby(["platform", "asset_class"])["current_value"].sum().reset_index()
        cross_pivot = cross.pivot(index="platform", columns="asset_class", values="current_value").fillna(0)
        st.dataframe(cross_pivot.style.format("{:,.0f}"), width='stretch')

    # 年化费用估算
    if "annual_fee_rate" in df.columns:
        st.markdown("#### 年化费用估算")
        df_fee = df[df["annual_fee_rate"].notna() & (df["annual_fee_rate"] > 0)].copy()
        if not df_fee.empty:
            df_fee["annual_fee"] = df_fee["current_value"] * df_fee["annual_fee_rate"]
            fee_by_class = df_fee.groupby("asset_class")["annual_fee"].sum().to_dict()

            classes = list(fee_by_class.keys())
            values = list(fee_by_class.values())
            total_fee = sum(values)
            fee_ratio = (total_fee / total * 100) if total > 0 else 0

            colors = [ASSET_CLASS_COLORS.get(c, CHART_COLORS[-1]) for c in classes]
            fig = plot_horizontal_bar(classes, values, "年化费用估算", COLOR_ACCENT)
            st.plotly_chart(fig, width='stretch')

            st.markdown(f"年化费用合计: **¥{total_fee:,.0f}**（占总资产 {fee_ratio:.2f}%）")
        else:
            st.info("暂无费用数据")
