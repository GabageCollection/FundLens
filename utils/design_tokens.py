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

# Typography scale
TEXT_XS = "10px"
TEXT_SM = "14px"
TEXT_BASE = "16px"
TEXT_LG = "20px"
TEXT_XL = "25px"
TEXT_2XL = "32px"
TEXT_3XL = "52px"
TEXT_4XL = "64px"

# Line heights
LEADING_BODY = "1.6"
LEADING_TIGHT = "1.1"

# ─── Spacing ────────────────────────────────────────────────────
SPACE_1 = "4px"
SPACE_2 = "8px"
SPACE_3 = "12px"
SPACE_4 = "16px"
SPACE_5 = "20px"
SPACE_6 = "24px"
SPACE_8 = "32px"
SPACE_12 = "48px"

# Section spacing
SECTION_Y_DESKTOP = "96px"
SECTION_Y_TABLET = "64px"
SECTION_Y_PHONE = "48px"

# ─── Border Radius ──────────────────────────────────────────────
RADIUS_SM = "8px"
RADIUS_MD = "12px"
RADIUS_LG = "16px"
RADIUS_PILL = "9999px"

# ─── Layout ─────────────────────────────────────────────────────
CONTAINER_MAX = "1200px"
CONTAINER_GUTTER_DESKTOP = "24px"
CONTAINER_GUTTER_TABLET = "16px"
CONTAINER_GUTTER_PHONE = "12px"

# ─── Motion ─────────────────────────────────────────────────────
MOTION_FAST = "150ms"
MOTION_BASE = "200ms"
EASE_STANDARD = "cubic-bezier(0.2, 0, 0, 1)"

# ─── Elevation ──────────────────────────────────────────────────
ELEV_FLAT = "none"
ELEV_RING = "0 0 0 1px #f0eee6"
ELEV_RAISED = "rgba(0,0,0,0.05) 0px 4px 24px"

# ─── Focus ──────────────────────────────────────────────────────
FOCUS_RING = "0 0 0 3px rgba(56, 152, 236, 0.3)"
