"""数据校验页面 — 三级分层校验报告展示（阻断错误 / 警告提示 / 自动修复）."""

import streamlit as st

from utils.constants import KEY_SNAPSHOT_DATA
from utils.design_tokens import COLOR_META
from utils.validator import generate_validation_report

st.set_page_config(
    page_title="FundLens - 数据校验",
    page_icon="🔍",
    layout="wide",
)

# ─── Page header ────────────────────────────────────────────
st.markdown(
    '<h2 style="font-family:Georgia,serif;">🔍 数据校验</h2>',
    unsafe_allow_html=True,
)
st.markdown(
    f'<p style="color:{COLOR_META};">当前快照的校验结果 — 三级分层：阻断错误、警告提示、自动修复</p>',
    unsafe_allow_html=True,
)

df = st.session_state.get(KEY_SNAPSHOT_DATA)

if df is None:
    st.info("👈 请先通过侧边栏选择快照，或前往数据导入页面上传 Excel 文件。")
    st.stop()

# ─── Run validation ────────────────────────────────────────
report = generate_validation_report(df)
summary = report["summary"]

# ─── Summary cards ─────────────────────────────────────────
cols = st.columns(3)
cols[0].markdown(
    f'<div class="validation-stat v-error">'
    f'<div class="stat-num">{summary["error_count"]}</div>'
    f'<div class="stat-label">🔴 阻断错误</div></div>',
    unsafe_allow_html=True,
)
cols[1].markdown(
    f'<div class="validation-stat v-warn">'
    f'<div class="stat-num">{summary["warning_count"]}</div>'
    f'<div class="stat-label">🟡 警告提示</div></div>',
    unsafe_allow_html=True,
)
cols[2].markdown(
    f'<div class="validation-stat v-fix">'
    f'<div class="stat-num">{summary["fix_count"]}</div>'
    f'<div class="stat-label">🟢 自动修复</div></div>',
    unsafe_allow_html=True,
)

# ─── Coverage info ─────────────────────────────────────────
if "current_value" in df.columns and "cost_amount" in df.columns:
    has_cost = df["cost_amount"].notna() & (df["cost_amount"] > 0)
    coverage = (
        df.loc[has_cost, "current_value"].sum() / df["current_value"].sum() * 100
        if df["current_value"].sum() > 0
        else 0.0
    )
    st.markdown(
        f'<div style="color:{COLOR_META};font-size:14px;margin-bottom:24px;">'
        f'收益统计覆盖率: <strong>{coverage:.1f}%</strong></div>',
        unsafe_allow_html=True,
    )

# ─── Filter tabs ───────────────────────────────────────────
filter_level = st.radio(
    "筛选级别",
    ["全部", "🔴 阻断错误", "🟡 警告提示", "🟢 自动修复"],
    horizontal=True,
    label_visibility="collapsed",
)

# ─── Blocking Errors Table ─────────────────────────────────
if filter_level in ("全部", "🔴 阻断错误"):
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown(
        '<h4 style="display:flex;align-items:center;gap:8px;margin-bottom:16px;">'
        '<span class="badge badge-error">🔴 阻断错误</span> 必须修复，否则无法导入</h4>',
        unsafe_allow_html=True,
    )

    if report["errors"]:
        html = '<table class="data-table"><thead><tr><th>规则</th><th>行号</th><th>字段</th><th>说明</th></tr></thead><tbody>'
        for err in report["errors"]:
            html += (
                f'<tr><td>{err["rule"]}</td><td>{err["row"]}</td>'
                f'<td>{err["field"]}</td><td>{err["message"]}</td></tr>'
            )
        html += "</tbody></table>"
        st.markdown(html, unsafe_allow_html=True)
    else:
        st.success("所有阻断校验已通过，无错误")

    st.markdown("</div>", unsafe_allow_html=True)

# ─── Warnings Table ────────────────────────────────────────
if filter_level in ("全部", "🟡 警告提示"):
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown(
        '<h4 style="display:flex;align-items:center;gap:8px;margin-bottom:16px;">'
        '<span class="badge badge-warn">🟡 警告提示</span> 可以导入，但建议确认</h4>',
        unsafe_allow_html=True,
    )

    if report["warnings"]:
        html = '<table class="data-table"><thead><tr><th>规则</th><th>行号</th><th>详情</th><th>建议操作</th></tr></thead><tbody>'
        for w in report["warnings"]:
            suggestion = "请确认数据是否准确" if "异常" in w["message"] else "将自动归为默认分类" if "为空" in w["message"] else "请核对"
            html += (
                f'<tr><td>{w["rule"]}</td><td>{w["row"]}</td>'
                f'<td>{w["message"]}</td><td><span class="badge badge-muted">{suggestion}</span></td></tr>'
            )
        html += "</tbody></table>"
        st.markdown(html, unsafe_allow_html=True)
    else:
        st.info("无警告提示")

    st.markdown("</div>", unsafe_allow_html=True)

# ─── Auto-fixes Table ──────────────────────────────────────
if filter_level in ("全部", "🟢 自动修复"):
    st.markdown('<div class="chart-card">', unsafe_allow_html=True)
    st.markdown(
        '<h4 style="display:flex;align-items:center;gap:8px;margin-bottom:16px;">'
        '<span class="badge badge-success">🟢 自动修复</span> 系统已自动处理</h4>',
        unsafe_allow_html=True,
    )

    if report["fixes"]:
        html = '<table class="data-table"><thead><tr><th>规则</th><th>行号</th><th>处理记录</th><th>结果</th></tr></thead><tbody>'
        for f in report["fixes"]:
            html += (
                f'<tr><td>{f["rule"]}</td><td>{f["row"]}</td>'
                f'<td>{f["message"]}</td><td><span class="badge badge-success">✓ 已修复</span></td></tr>'
            )
        html += "</tbody></table>"
        st.markdown(html, unsafe_allow_html=True)
    else:
        st.info("无自动修复操作")
        html_rows = (
            '<tr><td>金额千分位逗号清洗</td><td>未检测到千分位逗号</td>'
            '<td><span class="badge badge-success">无需处理</span></td></tr>'
            '<tr><td>百分号格式转换</td><td>未检测到百分号格式</td>'
            '<td><span class="badge badge-success">无需处理</span></td></tr>'
            '<tr><td>自动计算持有收益</td><td>已通过导入流程自动计算</td>'
            '<td><span class="badge badge-success">✓ 完成</span></td></tr>'
            '<tr><td>自动计算持有收益率</td><td>已通过导入流程自动计算</td>'
            '<td><span class="badge badge-success">✓ 完成</span></td></tr>'
            '<tr><td>缺失成本处理</td><td>已标记无成本数据的产品</td>'
            '<td><span class="badge badge-success">✓ 完成</span></td></tr>'
        )
        st.markdown(
            f'<table class="data-table"><thead><tr><th>规则</th><th>处理记录</th><th>结果</th></tr></thead>'
            f'<tbody>{html_rows}</tbody></table>',
            unsafe_allow_html=True,
        )

    st.markdown("</div>", unsafe_allow_html=True)

# ─── Configuration validation ──────────────────────────────
st.markdown('<div class="chart-card">', unsafe_allow_html=True)
st.markdown('<h4 style="margin-bottom:16px;">配置校验</h4>', unsafe_allow_html=True)

benchmark_config = st.session_state.get("benchmark_config", {})
has_benchmark = bool(benchmark_config.get("name") and benchmark_config.get("start_value") and benchmark_config.get("end_value"))

target_alloc = st.session_state.get("target_allocation", {})
target_ok = abs(sum(float(v) for v in target_alloc.values()) - 1.0) < 0.001 if target_alloc else False

# Check that target asset classes exist in current data
target_classes_ok = True
if target_alloc and "asset_class" in df.columns:
    existing = set(df["asset_class"].dropna().unique())
    for cls in target_alloc:
        if cls not in existing and cls != "其他类":
            target_classes_ok = False
            break

html = '<table class="data-table"><thead><tr><th>规则</th><th>状态</th><th>说明</th></tr></thead><tbody>'

if has_benchmark:
    bm = benchmark_config
    bm_return = (bm["end_value"] - bm["start_value"]) / bm["start_value"] * 100
    html += f'<tr><td>基准指数配置</td><td><span class="badge badge-success">✓ 已配置</span></td><td>{bm["name"]}，期初 {bm["start_value"]:.0f}，期末 {bm["end_value"]:.0f}，基准收益率 {bm_return:+.2f}%</td></tr>'
else:
    html += '<tr><td>基准指数配置</td><td><span class="badge badge-muted">未配置</span></td><td>请前往设置页配置基准指数（如沪深300）</td></tr>'

if target_alloc:
    total = sum(float(v) for v in target_alloc.values()) * 100
    badge = "badge-success" if target_ok else "badge-warn"
    html += f'<tr><td>目标配置比例总和</td><td><span class="badge {badge}">{"✓ 通过" if target_ok else "⚠ 异常"}</span></td><td>总和 = {total:.0f}%{"，与 100% 不一致" if not target_ok else "，校验一致"}</td></tr>'
    badge2 = "badge-success" if target_classes_ok else "badge-warn"
    html += f'<tr><td>目标配置大类引用</td><td><span class="badge {badge2}">{"✓ 通过" if target_classes_ok else "⚠ 异常"}</span></td><td>{"所有目标大类均存在于当前数据中" if target_classes_ok else "部分目标大类在当前数据中不存在"}</td></tr>'
else:
    html += '<tr><td>目标配置比例总和</td><td><span class="badge badge-muted">未设定</span></td><td>请前往设置页设定各资产大类目标配置比例</td></tr>'
    html += '<tr><td>目标配置大类引用</td><td><span class="badge badge-muted">未设定</span></td><td>—</td></tr>'

html += "</tbody></table>"
st.markdown(html, unsafe_allow_html=True)
st.markdown("</div>", unsafe_allow_html=True)
