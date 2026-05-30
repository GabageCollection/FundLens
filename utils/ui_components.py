"""UI 组件 — KPI 指标卡片，配合 assets/style.css 中的 .kpi-card 样式。

所有函数返回 HTML 字符串，由调用方通过 st.markdown(html, unsafe_allow_html=True) 渲染。
"""

from utils.design_tokens import COLOR_LOSS, COLOR_PROFIT, COLOR_WARNING


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


def render_kpi_row(cards: list[str]) -> str:
    """单行排列多个 KPI 卡片（4 列网格布局）。

    参数:
        cards: KPI 卡片 HTML 字符串列表，最多 4 个

    返回:
        包裹在 grid-4 容器中的 HTML 字符串
    """
    grid_html = '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px;">'
    for card in cards:
        grid_html += card
    grid_html += "</div>"
    return grid_html
