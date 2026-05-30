"""Design tokens extracted from 前端设计/css/tokens.css — warm palette (Claude Design System)."""

# ─── Surface ────────────────────────────────────────────────────
COLOR_BG = "#f5f4ed"
COLOR_SURFACE = "#faf9f5"
COLOR_SURFACE_WARM = "#e8e6dc"

# ─── Foreground ─────────────────────────────────────────────────
COLOR_FG = "#141413"
COLOR_FG_2 = "#3d3d3a"
COLOR_MUTED = "#5e5d59"
COLOR_META = "#87867f"

# ─── Border ─────────────────────────────────────────────────────
COLOR_BORDER = "#f0eee6"
COLOR_BORDER_SOFT = "#e8e6dc"

# ─── Accent (Claude terracotta) ─────────────────────────────────
COLOR_ACCENT = "#c96442"
COLOR_ACCENT_HOVER = "#b55a3b"
COLOR_ACCENT_ACTIVE = "#a45034"

# ─── Semantic ───────────────────────────────────────────────────
COLOR_SUCCESS = "#17a34a"
COLOR_WARNING = "#ff9800"
COLOR_DANGER = "#b53333"

# ─── Financial (Chinese convention: red = up/profit) ────────────
COLOR_PROFIT = "#c43d3d"
COLOR_LOSS = "#3d8c40"

# ─── Chart palette (10 colors from tokens.css) ──────────────────
CHART_COLORS = [
    "#c96442",  # chart-1  terracotta
    "#5e5d59",  # chart-2  olive gray
    "#d4a574",  # chart-3  warm sand
    "#8b9a8b",  # chart-4  muted sage
    "#b8a9a0",  # chart-5  warm stone
    "#6b7b6b",  # chart-6  deep sage
    "#d4c5bc",  # chart-7  warm blush
    "#4d4c48",  # chart-8  charcoal warm
    "#c4b5a5",  # chart-9  warm tan
    "#3d3d3a",  # chart-10 dark warm
]

# ─── Asset class fixed color mapping ────────────────────────────
ASSET_CLASS_COLORS: dict[str, str] = {
    "现金类": "#8b9a8b",
    "固收类": "#5e5d59",
    "固收增强类": "#b8a9a0",
    "权益类": "#c96442",
    "跨境类": "#d4a574",
    "其他类": "#d4c5bc",
}

# ─── Typography ─────────────────────────────────────────────────
FONT_DISPLAY = "'Georgia', 'Times New Roman', serif"
FONT_BODY = "'Arial', system-ui, -apple-system, sans-serif"
FONT_MONO = "'JetBrains Mono', 'Consolas', monospace"
