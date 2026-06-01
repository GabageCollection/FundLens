"""UI 组件 — 通用组件渲染函数，配合 assets/style.css 样式。

所有函数返回 HTML 字符串，由调用方通过 st.markdown(html, unsafe_allow_html=True) 渲染。
"""

from utils.design_tokens import (
    COLOR_LOSS,
    COLOR_PROFIT,
    COLOR_WARNING,
)


def render_kpi_card(
    label: str,
    value: str,
    suffix: str = "",
    delta: str = "",
    alert_level: str = "normal",
) -> str:
    """渲染单个 KPI 指标卡片。

    参数:
        label: 指标名称（如"总资产"）
        value: 数值（已格式化字符串，如"¥71,000"）
        suffix: 数值后缀（如"%"）
        delta: 变化说明（如"跑赢基准 +3.5%"，可选）
        alert_level: normal | warning | profit | loss
            normal: 默认白底卡片
            warning: 橙色边框 + 暖色背景（用于集中度、偏离等警示）
            profit: 数值显示暖红色
            loss: 数值显示绿色
    """
    value_color = {
        "normal": "",
        "warning": "",
        "profit": COLOR_PROFIT,
        "loss": COLOR_LOSS,
    }.get(alert_level, "")

    card_class = "kpi-card"
    if alert_level == "warning":
        card_class += " warn-card"

    value_style = f' style="color:{value_color};"' if value_color else ""

    html = f'<div class="{card_class}">'
    html += f'<div class="kpi-label">{label}</div>'
    html += f'<div class="kpi-value"{value_style}>{value}{suffix}</div>'
    if delta:
        html += f'<div class="kpi-sub">{delta}</div>'
    html += "</div>"
    return html


def render_badge(text: str, variant: str = "muted") -> str:
    """渲染徽章组件。

    参数:
        text: 徽章文本
        variant: success | warn | error | muted

    返回:
        徽章 HTML 字符串
    """
    return f'<span class="badge badge-{variant}">{text}</span>'


def render_validation_stat(num: "int | str", label: str, variant: str) -> str:
    """渲染校验统计卡片。

    参数:
        num: 统计数字
        label: 标签文字
        variant: error | warn | fix

    返回:
        校验统计卡片 HTML 字符串
    """
    return (
        f'<div class="validation-stat v-{variant}">'
        f'<div class="stat-num">{num}</div>'
        f'<div class="stat-label">{label}</div>'
        '</div>'
    )


def render_import_step(steps: list[dict[str, str]], current: int) -> str:
    """渲染步骤指示器。

    参数:
        steps: 步骤列表，每个步骤为 {"label": "步骤名称"}
        current: 当前步骤索引（从0开始）

    返回:
        步骤指示器 HTML 字符串
    """
    html = '<div class="import-steps">'
    for i, step in enumerate(steps):
        step_class = "import-step"
        if i == current:
            step_class += " active"
        elif i < current:
            step_class += " done"
        html += f'<div class="{step_class}">{step["label"]}</div>'
    html += '</div>'
    return html


def render_data_quality_badges(badges: list[dict[str, str]]) -> str:
    """渲染数据质量徽章组。

    参数:
        badges: 徽章列表，每个徽章为 {"text": "徽章文本", "variant": "success|warn|error|muted"}

    返回:
        徽章组 HTML 字符串
    """
    html = '<div style="display:flex;gap:var(--space-4);flex-wrap:wrap;font-size:var(--text-sm);">'
    for badge in badges:
        html += render_badge(badge["text"], badge["variant"])
    html += '</div>'
    return html
