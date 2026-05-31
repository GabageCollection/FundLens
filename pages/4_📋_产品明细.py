"""产品明细页面 — 完整资产表，含筛选、搜索、排序和导出功能。"""

import streamlit as st
import pandas as pd
import io
from datetime import datetime

from utils.constants import KEY_SNAPSHOT_DATA
from utils.exporter import export_to_excel, export_to_csv

st.set_page_config(page_title="FundLens - 产品明细", page_icon="📋", layout="wide")

df = st.session_state.get(KEY_SNAPSHOT_DATA)

if df is None:
    st.info("👈 请先通过侧边栏选择快照")
    st.stop()

st.markdown('<h2 style="font-family:Georgia,serif;">📋 产品明细</h2>', unsafe_allow_html=True)

# ─── 筛选器 ────────────────────────────────────────

with st.container():
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    filter_cols = st.columns(6)

    # 平台筛选
    if "platform" in df.columns:
        platforms = ["全部"] + sorted(df["platform"].dropna().unique().tolist())
        selected_platform = filter_cols[0].selectbox("平台", platforms, key="filter_platform")
    else:
        selected_platform = "全部"

    # 资产大类筛选
    if "asset_class" in df.columns:
        classes = ["全部"] + sorted(df["asset_class"].dropna().unique().tolist())
        selected_class = filter_cols[1].selectbox("资产大类", classes, key="filter_class")
    else:
        selected_class = "全部"

    # 产品类型筛选
    if "product_type" in df.columns:
        types = ["全部"] + sorted(df["product_type"].dropna().unique().tolist())
        selected_type = filter_cols[2].selectbox("产品类型", types, key="filter_type")
    else:
        selected_type = "全部"

    # 市场区域筛选
    if "market_region" in df.columns:
        regions = ["全部"] + sorted(df["market_region"].dropna().unique().tolist())
        selected_region = filter_cols[3].selectbox("市场区域", regions, key="filter_region")
    else:
        selected_region = "全部"

    # 资金用途筛选
    if "usage_purpose" in df.columns:
        purposes = ["全部"] + sorted(df["usage_purpose"].dropna().unique().tolist())
        selected_purpose = filter_cols[4].selectbox("资金用途", purposes, key="filter_purpose")
    else:
        selected_purpose = "全部"

    # 收益状态筛选
    if "holding_profit" in df.columns:
        profit_status = ["全部", "盈利 (收益 > 0)", "亏损 (收益 < 0)", "无成本数据"]
        selected_profit = filter_cols[5].selectbox("收益状态", profit_status, key="filter_profit")
    else:
        selected_profit = "全部"

    # 搜索框
    search = st.text_input("🔍 搜索产品名称或代码", placeholder="输入关键词...", key="search_detail")

    st.markdown("</div>", unsafe_allow_html=True)

# ─── 筛选逻辑 ───────────────────────────────────────

filtered_df = df.copy()

if selected_platform != "全部" and "platform" in filtered_df.columns:
    filtered_df = filtered_df[filtered_df["platform"] == selected_platform]

if selected_class != "全部" and "asset_class" in filtered_df.columns:
    filtered_df = filtered_df[filtered_df["asset_class"] == selected_class]

if selected_type != "全部" and "product_type" in filtered_df.columns:
    filtered_df = filtered_df[filtered_df["product_type"] == selected_type]

if selected_region != "全部" and "market_region" in filtered_df.columns:
    filtered_df = filtered_df[filtered_df["market_region"] == selected_region]

if selected_purpose != "全部" and "usage_purpose" in filtered_df.columns:
    filtered_df = filtered_df[filtered_df["usage_purpose"] == selected_purpose]

if selected_profit != "全部" and "holding_profit" in filtered_df.columns:
    if selected_profit == "盈利 (收益 > 0)":
        filtered_df = filtered_df[filtered_df["holding_profit"].notna() & (filtered_df["holding_profit"] > 0)]
    elif selected_profit == "亏损 (收益 < 0)":
        filtered_df = filtered_df[filtered_df["holding_profit"].notna() & (filtered_df["holding_profit"] < 0)]
    elif selected_profit == "无成本数据":
        filtered_df = filtered_df[filtered_df["holding_profit"].isna()]

# 搜索
if search:
    mask = pd.Series(False, index=filtered_df.index)
    if "product_name" in filtered_df.columns:
        mask |= filtered_df["product_name"].str.contains(search, case=False, na=False)
    if "product_code" in filtered_df.columns:
        mask |= filtered_df["product_code"].str.contains(search, case=False, na=False)
    filtered_df = filtered_df[mask]

# ─── 数据表格 ───────────────────────────────────────

st.markdown(f"共 **{len(filtered_df)}** 条记录")

# 准备展示列
display_cols = {}
if "product_name" in filtered_df.columns:
    display_cols["产品名称"] = "product_name"
if "platform" in filtered_df.columns:
    display_cols["平台"] = "platform"
if "asset_class" in filtered_df.columns:
    display_cols["资产大类"] = "asset_class"
if "product_type" in filtered_df.columns:
    display_cols["产品类型"] = "product_type"
if "current_value" in filtered_df.columns:
    display_cols["当前金额"] = "current_value"
if "cost_amount" in filtered_df.columns:
    display_cols["持有成本"] = "cost_amount"
if "holding_profit" in filtered_df.columns:
    display_cols["持有收益"] = "holding_profit"
if "holding_return" in filtered_df.columns:
    display_cols["收益率"] = "holding_return"

display_df = filtered_df[list(display_cols.values())].copy()
display_df = display_df.rename(columns={v: k for k, v in display_cols.items()})

# 格式化金额列
if "当前金额" in display_df.columns:
    display_df["当前金额"] = display_df["当前金额"].apply(lambda x: f"¥{x:,.2f}" if pd.notna(x) else "—")
if "持有成本" in display_df.columns:
    display_df["持有成本"] = display_df["持有成本"].apply(lambda x: f"¥{x:,.2f}" if pd.notna(x) and x > 0 else "—")
if "持有收益" in display_df.columns:
    display_df["持有收益"] = display_df["持有收益"].apply(
        lambda x: f"{'+' if x >= 0 else ''}¥{x:,.2f}" if pd.notna(x) else "—"
    )
if "收益率" in display_df.columns:
    display_df["收益率"] = display_df["收益率"].apply(
        lambda x: f"{x*100:+.2f}%" if pd.notna(x) else "—"
    )

st.dataframe(display_df, use_container_width=True, hide_index=True, height=600)

# ─── 导出按钮 ───────────────────────────────────────

st.markdown("---")
col1, col2, _ = st.columns([1, 1, 4])

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

if col1.button("📥 导出 Excel", use_container_width=True):
    buffer = io.BytesIO()
    with pd.ExcelWriter(buffer, engine="openpyxl") as writer:
        display_df.to_excel(writer, index=False, sheet_name="产品明细")
    st.download_button(
        label="📥 下载 Excel 文件",
        data=buffer.getvalue(),
        file_name=f"FundLens_产品明细_{timestamp}.xlsx",
        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )

if col2.button("📥 导出 CSV", use_container_width=True):
    csv_data = display_df.to_csv(index=False, encoding="utf-8-sig").encode("utf-8-sig")
    st.download_button(
        label="📥 下载 CSV 文件",
        data=csv_data,
        file_name=f"FundLens_产品明细_{timestamp}.csv",
        mime="text/csv",
    )
