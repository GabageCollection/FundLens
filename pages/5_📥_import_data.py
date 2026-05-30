"""数据导入页面 — 上传 Excel 资产快照，预览并确认导入."""

import logging
from pathlib import Path

import pandas as pd
import streamlit as st

from utils.data_loader import read_asset_snapshot
from utils.file_manager import get_snapshot_list, save_uploaded_file

logger = logging.getLogger(__name__)

st.set_page_config(
    page_title="FundLens - 数据导入",
    page_icon="📥",
    layout="wide",
)


def _format_amount(val) -> str:
    """Format a numeric value as CNY with thousand separators, or return '—'."""
    if pd.isna(val) or val is None:
        return "—"
    try:
        return f"¥{float(val):,.2f}"
    except (ValueError, TypeError):
        return str(val)


def _format_profit(val) -> str:
    """Format profit/loss with sign prefix."""
    if pd.isna(val) or val is None:
        return "—"
    val = float(val)
    sign = "+" if val >= 0 else ""
    return f"{sign}¥{abs(val):,.2f}"


def _format_return(val) -> str:
    """Format return rate as percentage."""
    if pd.isna(val) or val is None:
        return "—"
    val = float(val)
    sign = "+" if val >= 0 else ""
    return f"{sign}{val * 100:.2f}%"


# ─── Page header ────────────────────────────────────────────
st.markdown(
    '<h2 style="font-family:Georgia,serif;">📥 数据导入</h2>',
    unsafe_allow_html=True,
)
st.markdown(
    '<p style="color:#87867f;">上传 Excel 资产快照，系统自动清洗、校验并生成分析看板</p>',
    unsafe_allow_html=True,
)

# ─── Step indicator ─────────────────────────────────────────
step_order = ["上传 Excel", "预览与校验", "导入确认"]
# Determine current step based on state
if "import_uploaded_file" not in st.session_state:
    current_step = 0
elif st.session_state.get("import_step", 0) < 2:
    current_step = st.session_state.get("import_step", 1)
else:
    current_step = 2

step_cols = st.columns(len(step_order))
for i, (col, label) in enumerate(zip(step_cols, step_order)):
    if i < current_step:
        cls = "import-step done"
    elif i == current_step:
        cls = "import-step active"
    else:
        cls = "import-step"
    col.markdown(
        f'<div class="{cls}">{i + 1}. {label}</div>',
        unsafe_allow_html=True,
    )

st.markdown("<br>", unsafe_allow_html=True)

# ─── Upload section ─────────────────────────────────────────
st.markdown('<div class="chart-card">', unsafe_allow_html=True)
st.markdown("#### 上传资产快照")

uploaded_file = st.file_uploader(
    "拖拽或点击上传 .xlsx 文件，需包含 asset_snapshot Sheet",
    type=["xlsx"],
    key="file_uploader",
    label_visibility="collapsed",
)

# Download template button
template_path = Path(__file__).resolve().parent.parent / "data" / "sample" / "FundLens_Asset_Snapshot_Template.xlsx"
if template_path.exists():
    with open(template_path, "rb") as f:
        st.download_button(
            label="📥 下载标准模板",
            data=f,
            file_name="FundLens_Asset_Snapshot_Template.xlsx",
            mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )

st.markdown("</div>", unsafe_allow_html=True)

# ─── Process uploaded file ──────────────────────────────────
if uploaded_file is not None and (
    "import_uploaded_file" not in st.session_state
    or st.session_state.get("import_uploaded_name") != uploaded_file.name
):
    try:
        saved_path = save_uploaded_file(uploaded_file)
        st.session_state["import_uploaded_file"] = str(saved_path)
        st.session_state["import_uploaded_name"] = uploaded_file.name
        st.session_state["import_step"] = 1
        st.rerun()
    except Exception as e:
        st.error(f"文件保存失败: {e}")

# ─── Preview & summary (shown after upload) ─────────────────
if "import_uploaded_file" in st.session_state:
    filepath = st.session_state["import_uploaded_file"]

    try:
        df = read_asset_snapshot(filepath)
    except Exception as e:
        st.error(f"读取文件失败: {e}")
        df = None

    if df is not None:
        # ─── Import summary ───
        st.markdown('<div class="chart-card">', unsafe_allow_html=True)
        st.markdown("#### 导入摘要")

        total_rows = len(df)
        # Coverage calculations
        has_cost = df["cost_amount"].notna() & (df["cost_amount"] > 0)
        profit_coverage = (
            df.loc[has_cost, "current_value"].sum() / df["current_value"].sum() * 100
            if df["current_value"].sum() > 0
            else 0
        )
        has_fee = df["annual_fee_rate"].notna()
        fee_coverage = has_fee.sum() / total_rows * 100 if total_rows > 0 else 0

        summary_cols = st.columns(4)
        summary_cols[0].markdown(
            f'<div class="validation-stat v-fix"><div class="stat-num">{total_rows}</div>'
            f'<div class="stat-label">成功读取</div></div>',
            unsafe_allow_html=True,
        )
        summary_cols[1].markdown(
            '<div class="validation-stat v-error"><div class="stat-num">—</div>'
            '<div class="stat-label">阻断错误</div></div>',
            unsafe_allow_html=True,
        )
        summary_cols[2].markdown(
            '<div class="validation-stat v-warn"><div class="stat-num">—</div>'
            '<div class="stat-label">警告提示</div></div>',
            unsafe_allow_html=True,
        )
        summary_cols[3].markdown(
            '<div class="validation-stat v-fix"><div class="stat-num">—</div>'
            '<div class="stat-label">自动修复</div></div>',
            unsafe_allow_html=True,
        )

        # Coverage info row
        coverage_html = (
            f'<div style="display:flex;gap:24px;flex-wrap:wrap;font-size:14px;color:#5e5d59;margin-top:16px;">'
            f'<span>收益统计覆盖率: <strong>{profit_coverage:.1f}%</strong></span>'
            f'<span>费用统计覆盖率: <strong>{fee_coverage:.1f}%</strong></span>'
            f'<span>基准配置: <strong>待配置</strong></span>'
            f'<span>目标配置: <strong>待设定</strong></span>'
            f"</div>"
        )
        st.markdown(coverage_html, unsafe_allow_html=True)
        st.markdown("</div>", unsafe_allow_html=True)

        # ─── Data preview ───
        st.markdown('<div class="chart-card">', unsafe_allow_html=True)
        st.markdown(
            f'<div style="display:flex;justify-content:space-between;align-items:center;'
            f'margin-bottom:16px;"><h4 style="margin:0;">数据预览</h4>'
            f'<span style="font-size:14px;color:#87867f;">共 {total_rows} 条记录</span></div>',
            unsafe_allow_html=True,
        )

        # Build preview table
        preview_cols = [
            "platform", "asset_class", "product_type", "product_name",
            "current_value", "cost_amount",
        ]
        # Auto-calculate holding profit and return for display
        if "cost_amount" in df.columns and "current_value" in df.columns:
            df["_holding_profit"] = df["current_value"] - df["cost_amount"]
            df["_holding_return"] = df.apply(
                lambda r: r["_holding_profit"] / r["cost_amount"]
                if pd.notna(r["cost_amount"]) and r["cost_amount"] > 0
                else None,
                axis=1,
            )
            preview_cols += ["_holding_profit", "_holding_return"]

        available_cols = [c for c in preview_cols if c in df.columns]
        preview_df = df[available_cols].head(100)

        # Column labels
        col_labels = {
            "platform": "平台",
            "asset_class": "资产大类",
            "product_type": "产品类型",
            "product_name": "产品名称",
            "current_value": "当前金额",
            "cost_amount": "持有成本",
            "_holding_profit": "持有收益",
            "_holding_return": "收益率",
        }

        # Build HTML table
        table_html = '<div style="max-height:400px;overflow:auto;"><table class="data-table"><thead><tr>'
        for col in available_cols:
            cls = ' class="num"' if col in ("current_value", "cost_amount", "_holding_profit", "_holding_return") else ""
            table_html += f"<th{cls}>{col_labels.get(col, col)}</th>"
        table_html += "</tr></thead><tbody>"

        for _, row in preview_df.iterrows():
            table_html += "<tr>"
            for col in available_cols:
                val = row[col]
                if col == "current_value":
                    table_html += f'<td class="num">{_format_amount(val)}</td>'
                elif col == "cost_amount":
                    table_html += f'<td class="num">{_format_amount(val)}</td>'
                elif col == "_holding_profit":
                    cls = "num profit-cell" if pd.notna(val) and val > 0 else "num loss-cell" if pd.notna(val) and val < 0 else "num"
                    table_html += f'<td class="{cls}">{_format_profit(val)}</td>'
                elif col == "_holding_return":
                    cls = "num profit-cell" if pd.notna(val) and val > 0 else "num loss-cell" if pd.notna(val) and val < 0 else "num"
                    table_html += f'<td class="{cls}">{_format_return(val)}</td>'
                else:
                    table_html += f"<td>{str(val) if pd.notna(val) else '—'}</td>"
            table_html += "</tr>"

        table_html += "</tbody></table></div>"
        st.markdown(table_html, unsafe_allow_html=True)
        st.markdown("</div>", unsafe_allow_html=True)

        # ─── Action buttons ───
        col1, col2, _ = st.columns([1, 1, 4])
        if col1.button("✅ 确认导入，进入看板", type="primary", use_container_width=True):
            # Set as current snapshot
            from utils.constants import KEY_CURRENT_SNAPSHOT, KEY_SNAPSHOT_DATA

            st.session_state[KEY_CURRENT_SNAPSHOT] = filepath
            st.session_state[KEY_SNAPSHOT_DATA] = df.drop(columns=["_holding_profit", "_holding_return"], errors="ignore")
            st.session_state["import_uploaded_file"] = None
            st.session_state["import_step"] = 0
            st.success("导入成功！请前往首页概览查看分析看板。")
            st.rerun()

        if col2.button("🔍 查看校验详情", use_container_width=True):
            st.switch_page("pages/6_🔍_validation.py")
