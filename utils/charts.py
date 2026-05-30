"""Plotly 图表工厂 — 统一主题、饼图、柱状图、子弹图、瀑布图、双柱对比图。

所有函数接受数据并返回 plotly.graph_objects.Figure，配合 Streamlit st.plotly_chart 使用。
配色从 utils.design_tokens 导入，保持与 tokens.css 视觉基准一致。
"""

import plotly.graph_objects as go
import plotly.express as px
import pandas as pd

from utils.design_tokens import (
    ASSET_CLASS_COLORS, CHART_COLORS,
    COLOR_ACCENT, COLOR_BG, COLOR_LOSS, COLOR_MUTED, COLOR_PROFIT, COLOR_SURFACE, COLOR_WARNING,
)


def apply_fundlens_theme(fig: go.Figure) -> go.Figure:
    """统一 FundLens Plotly 图表主题：白色模板、Georgia 字体、暖羊皮纸背景。"""
    fig.update_layout(
        template="plotly_white",
        font=dict(family="Georgia, Arial, sans-serif", color=COLOR_MUTED),
        margin=dict(l=20, r=20, t=40, b=20),
        paper_bgcolor=COLOR_BG,
        plot_bgcolor=COLOR_SURFACE,
    )
    return fig


def _empty_figure(message: str = "暂无数据") -> go.Figure:
    """生成带提示信息的空白图表，用于空数据降级展示。"""
    fig = go.Figure()
    fig.add_annotation(text=message, showarrow=False, font=dict(size=16, color=COLOR_MUTED))
    return apply_fundlens_theme(fig)


def plot_pie(labels: list[str], values: list[float], title: str, colors: list[str] = None) -> go.Figure:
    """通用饼图/环形图。colors 默认为 CHART_COLORS。"""
    if not labels or not values or sum(values) == 0:
        return _empty_figure()
    if colors is None:
        colors = CHART_COLORS
    fig = go.Figure(data=[go.Pie(labels=labels, values=values, hole=0.4, marker=dict(colors=colors),
                                  textinfo="percent+label", textfont_size=12)])
    fig.update_layout(title=title, title_font_size=16)
    return apply_fundlens_theme(fig)


def plot_bar(x: list[str], y: list[float], title: str, color: str = COLOR_ACCENT,
             orientation: str = "v") -> go.Figure:
    """通用柱状图，支持纵向 (v) 和横向 (h)。"""
    if not x or not y or sum(y) == 0:
        return _empty_figure()
    if orientation == "h":
        fig = go.Figure(data=[go.Bar(y=x, x=y, marker_color=color, orientation="h", text=y,
                                      textposition="outside", texttemplate="¥%{text:,.0f}")])
    else:
        fig = go.Figure(data=[go.Bar(x=x, y=y, marker_color=color, text=y,
                                      textposition="outside")])
    fig.update_layout(title=title, title_font_size=16)
    return apply_fundlens_theme(fig)


def plot_horizontal_bar(x: list[str], y: list[float], title: str, color: str = COLOR_ACCENT) -> go.Figure:
    """横向柱状图，x 为类别名，y 为数值，按 y 升序排列使最大值在顶部。"""
    if not x or not y or sum(y) == 0:
        return _empty_figure()
    # 按 y 值升序排列（最大值在顶部）
    sorted_pairs = sorted(zip(x, y), key=lambda p: p[1])
    sorted_x = [p[0] for p in sorted_pairs]
    sorted_y = [p[1] for p in sorted_pairs]
    fig = go.Figure(data=[go.Bar(y=sorted_x, x=sorted_y, marker_color=color, orientation="h",
                                  text=[f"¥{v:,.0f}" for v in sorted_y], textposition="outside")])
    fig.update_layout(title=title, title_font_size=16)
    return apply_fundlens_theme(fig)


def plot_bullet(current_values: dict[str, float], target_values: dict[str, float],
                title: str) -> go.Figure:
    """子弹图 — 当前 vs 目标配置对比。偏离 ±5% 橙色高亮。"""
    if not current_values:
        return _empty_figure("未设定目标配置")

    classes = list(current_values.keys())
    current = [current_values.get(c, 0) for c in classes]
    target = [target_values.get(c, 0) for c in classes]

    fig = go.Figure()
    colors_bar = []
    for c, t in zip(current, target):
        if t == 0:
            colors_bar.append(COLOR_MUTED)
        elif abs(c - t) > 0.05:
            colors_bar.append(COLOR_WARNING)
        else:
            colors_bar.append(COLOR_ACCENT)

    fig.add_trace(go.Bar(name="当前", x=classes, y=current, marker_color=colors_bar,
                          text=[f"{v*100:.1f}%" for v in current], textposition="outside"))
    fig.add_trace(go.Scatter(name="目标", x=classes, y=target, mode="markers",
                              marker=dict(color=COLOR_MUTED, size=12, symbol="diamond")))
    fig.update_layout(title=title, title_font_size=16, barmode="group")
    return apply_fundlens_theme(fig)


def plot_waterfall(categories: list[str], values: list[float], title: str) -> go.Figure:
    """瀑布图 — 收益贡献度分解。正值用暖红色（盈利），负值用绿色（亏损）。"""
    if not categories or not values:
        return _empty_figure()

    fig = go.Figure(go.Waterfall(
        name="收益贡献",
        orientation="v",
        measure=["relative"] * len(categories) + ["total"],
        x=categories + ["总收益"],
        y=values + [sum(values)],
        text=[f"+¥{v:,.0f}" if v >= 0 else f"-¥{abs(v):,.0f}" for v in values] + [f"¥{sum(values):,.0f}"],
        textposition="outside",
        connector={"line": {"color": COLOR_MUTED}},
        increasing={"marker": {"color": COLOR_PROFIT}},
        decreasing={"marker": {"color": COLOR_LOSS}},
        totals={"marker": {"color": COLOR_ACCENT}},
    ))
    fig.update_layout(title=title, title_font_size=16)
    return apply_fundlens_theme(fig)


def plot_dual_bar(labels: list[str], values1: list[float], values2: list[float],
                  title: str, name1: str = "组合收益", name2: str = "基准收益") -> go.Figure:
    """双柱对比图 — 适合组合收益 vs 基准收益对比。"""
    if not labels:
        return _empty_figure()
    fig = go.Figure(data=[
        go.Bar(name=name1, x=labels, y=values1, marker_color=COLOR_ACCENT,
               text=[f"{v*100:.1f}%" for v in values1], textposition="outside"),
        go.Bar(name=name2, x=labels, y=values2, marker_color=CHART_COLORS[1],
               text=[f"{v*100:.1f}%" for v in values2], textposition="outside"),
    ])
    fig.update_layout(title=title, title_font_size=16, barmode="group")
    return apply_fundlens_theme(fig)


def plot_treemap(labels: list[str], values: list[float], parents: list[str] = None,
                 title: str = "") -> go.Figure:
    """树图 — 用于资产层级展示。parents 为空时所有节点为顶层。"""
    if not labels or not values or sum(values) == 0:
        return _empty_figure()
    if parents is None:
        parents = [""] * len(labels)
    df = pd.DataFrame({"label": labels, "value": values, "parent": parents})
    fig = px.treemap(df, path=["parent", "label"], values="value", title=title,
                     color_discrete_sequence=CHART_COLORS)
    return apply_fundlens_theme(fig)


def plot_grouped_bar(categories: list[str], groups: list[dict], title: str) -> go.Figure:
    """分组柱状图 — 适合多维度收益对比（如平台收益对比、大类收益对比）。

    参数:
        categories: X 轴类别标签列表（如 ["平台A", "平台B"]，每个 group 应有同名 key）
        groups: 每个 group 为 dict {name: str, values: list[float], color: str}
        title: 图表标题
    """
    if not categories or not groups:
        return _empty_figure()
    fig = go.Figure()
    for g in groups:
        fig.add_trace(go.Bar(
            name=g["name"], x=categories, y=g["values"],
            marker_color=g.get("color", CHART_COLORS[0]),
            text=[f"¥{v:,.0f}" for v in g["values"]], textposition="outside",
        ))
    fig.update_layout(title=title, title_font_size=16, barmode="group")
    return apply_fundlens_theme(fig)
