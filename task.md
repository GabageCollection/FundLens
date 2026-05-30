# FundLens v2.1 开发任务清单

> 基于《FundLens 项目设计文档 v2.1（竞品增强版）》制定
> 总预计工时：12 ~ 16 天（单人开发）
> 技术栈：Python 3.10+ / Streamlit / Pandas / Plotly / OpenPyXL

---

## 阶段总览

```
阶段一（2-3天）          阶段二（2-3天）          阶段三（2.5天）
基础框架 + 文件管理  →  数据清洗 + 校验  →  首页资产总览
     │                                            │
     └────────────────── 可并行 ──────────────────┘
                              │
              阶段四（3-3.5天）     阶段五（1-2天）
              资产配置 + 收益分析  →  产品明细 + 导出
                    │                      │
                    └────── 阶段六（2天） ──┘
                        设置页 + UI + 验收
```

---

## 前端设计参考

> FundLens v1.0 的 UI 实现以 `前端设计/` 目录中的 HTML 原型为**视觉基准**。
> 所有页面布局、配色、组件样式、间距和排版均需与原型保持一致。

### 原型文件对应关系

| 原型文件 | 对应 Streamlit 页面 | 关键参考点 |
|---|---|---|
| `前端设计/css/tokens.css` | `assets/style.css` | 100+ CSS 设计令牌（颜色、字体、间距、圆角、阴影、动效） |
| `前端设计/css/components.css` | `assets/style.css` | 所有共享组件样式（卡片、表格、按钮、徽章、筛选栏等） |
| `前端设计/js/sample-data.js` | 测试 fixture / 调试入口 | 8 条示例数据 + 指标计算逻辑，作为 Python 端验证基准 |
| `前端设计/overview.html` | `pages/1_🏠_overview.py` | KPI 卡片 3 行布局、环形图、目标配置对比、瀑布图、基准对比、持仓 Top 10 |
| `前端设计/allocation.html` | `pages/2_📊_allocation.py` | Tab 切换（总览/目标vs当前/详细维度）、子弹图、集中度图、费用图 |
| `前端设计/profit-analysis.html` | `pages/3_📈_profit_analysis.py` | 收益摘要条、算法说明提示框、平台/大类收益对比、瀑布图、盈亏排行 |
| `前端设计/detail-table.html` | `pages/4_📋_detail_table.py` | 多筛选器联动、搜索框、数据表格（含排序）、导出按钮 |
| `前端设计/import.html` | `pages/5_📥_import_data.py` | 步骤指示器、拖拽上传区、导入摘要统计卡片、数据预览表格 |
| `前端设计/validation.html` | `pages/6_🔍_validation.py` | 三级校验摘要统计、阻断/警告/修复分类表格、配置校验 |
| `前端设计/settings.html` | `pages/7_⚙️_settings.py` | 基准配置表单、目标配置滑块+输入框、图表偏好、隐私开关 |
| `前端设计/landing.html` | 不直接对应（产品介绍页） | 品牌色调参考、排版风格参考 |
| `前端设计/index.html` | `app.py` 侧边栏 | 导航卡片布局参考 |

### 设计令牌映射原则

将 `tokens.css` 中的 CSS 自定义属性映射为 Streamlit 可用的 Python 常量：

```python
# utils/design_tokens.py — 从 前端设计/css/tokens.css 提取

# Surface
COLOR_BG = "#f5f4ed"           # --bg
COLOR_SURFACE = "#faf9f5"      # --surface
COLOR_SURFACE_WARM = "#e8e6dc"  # --surface-warm

# Foreground
COLOR_FG = "#141413"            # --fg
COLOR_FG_2 = "#3d3d3a"          # --fg-2
COLOR_MUTED = "#5e5d59"         # --muted
COLOR_META = "#87867f"          # --meta

# Border
COLOR_BORDER = "#f0eee6"        # --border
COLOR_BORDER_SOFT = "#e8e6dc"   # --border-soft

# Accent (Claude terracotta)
COLOR_ACCENT = "#c96442"        # --accent
COLOR_ACCENT_HOVER = "#b55a3b"  # --accent-hover
COLOR_ACCENT_ACTIVE = "#a45034" # --accent-active

# Semantic
COLOR_SUCCESS = "#17a34a"       # --success
COLOR_WARN = "#ff9800"          # --warn
COLOR_DANGER = "#b53333"        # --danger

# Financial (Chinese convention: red = up/profit)
COLOR_PROFIT = "#c43d3d"        # --profit (warm red)
COLOR_LOSS = "#3d8c40"          # --loss (green)

# Chart palette (10 colors from tokens.css)
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

# Asset class fixed color mapping
ASSET_CLASS_COLORS = {
    "现金类": "#8b9a8b",    # muted sage
    "固收类": "#5e5d59",    # olive gray
    "固收增强类": "#b8a9a0", # warm stone
    "权益类": "#c96442",    # terracotta
    "跨境类": "#d4a574",    # warm sand
    "其他类": "#d4c5bc",    # warm blush
}

# Typography (mapped from tokens.css)
FONT_DISPLAY = "'Georgia', 'Times New Roman', serif"
FONT_BODY = "'Arial', system-ui, -apple-system, sans-serif"
FONT_MONO = "'JetBrains Mono', 'Consolas', monospace"
```

### 组件样式对标清单

Streamlit 自定义 CSS 需实现以下组件样式（参照 `components.css`）：

| CSS 类名 | 用途 | 实现优先级 |
|---|---|---|
| `.kpi-card` / `.kpi-label` / `.kpi-value` / `.kpi-sub` | KPI 指标卡片（4 列网格） | P0 |
| `.kpi-card.warn-card` | 橙色警示卡片（偏离/集中度 > 阈值） | P0 |
| `.kpi-value.profit` / `.kpi-value.loss` | 盈亏颜色区分 | P0 |
| `.chart-card` / `.chart-container` | 图表容器（白底 + 边框 + 圆角） | P0 |
| `.data-table` | 数据表格（含 hover、排序箭头、数字列对齐） | P0 |
| `.filters-bar` / `.filter-select` / `.search-input` | 多维度筛选器 + 搜索框 | P0 |
| `.badge-error` / `.badge-warn` / `.badge-success` / `.badge-muted` | 状态徽章（三级校验用） | P0 |
| `.validation-summary` / `.validation-stat` | 校验统计卡片 | P0 |
| `.upload-zone` | 拖拽上传区域 | P0 |
| `.empty-state` | 空状态引导（居中大图 + 文案） | P0 |
| `.target-bar-row` / `.target-bar-track` / `.target-bar-marker` | 目标配置对比条 | P0 |
| `.toggle-switch` / `.toggle-track` | 设置页开关组件 | P1 |
| `.modal-overlay` / `.modal` | 确认弹窗（删除快照等） | P1 |
| `.tabs` / `.tab-btn` | Tab 切换（资产配置页用） | P1 |
| `.import-steps` / `.import-step` | 导入步骤指示器 | P1 |
| `.btn` / `.btn-primary` / `.btn-sm` / `.btn-lg` | 按钮系统 | P1 |
| `.nav-item` / `.app-sidebar` / `.navbar` | 导航栏/侧边栏（Streamlit 原生可部分替代） | P2 |

---

## 阶段一：基础框架与文件管理

> 预计 2-3 天 | 优先级 P0 | 产出：可运行的项目骨架，支持 Excel 上传和快照切换

### 1.1 项目初始化

- [ ] 创建项目目录结构（参照设计文档 25 节）
- [ ] 编写 `requirements.txt`：
  ```
  streamlit>=1.28.0
  pandas>=2.0.0
  plotly>=5.15.0
  openpyxl>=3.1.0
  ```
- [ ] 创建 `app.py` 主入口，配置 Streamlit 页面标题/图标/布局
- [ ] 搭建侧边栏框架（导航 + 快照切换占位 + 上传入口占位）
- [ ] 创建 `utils/__init__.py` 和 `pages/__init__.py`
- [ ] 创建 `utils/design_tokens.py` — 从 `前端设计/css/tokens.css` 提取设计令牌为 Python 常量（颜色、字体、图表色板等，参考上方「设计令牌映射原则」）
- [ ] 创建 `assets/style.css` — 初始化空白样式文件，准备承载对标 `components.css` 的自定义样式

### 1.2 文件管理模块 (`utils/file_manager.py`)

- [ ] `scan_uploaded_files()` — 扫描 `data/uploaded/` 目录下所有 `.xlsx` 文件
- [ ] `extract_snapshot_info(filepath)` — 从 Excel 中提取统计日期和快照名称
- [ ] `save_uploaded_file(uploaded_file)` — 将 Streamlit UploadedFile 重命名保存至 `data/uploaded/`
- [ ] `load_snapshot(filepath)` — 读取 Excel 返回 Pandas DataFrame
- [ ] `get_snapshot_list()` — 返回可用快照列表 `[{name, date, path}]`

### 1.3 数据加载模块 (`utils/data_loader.py`)

- [ ] `read_asset_snapshot(filepath)` — 读取 `asset_snapshot` Sheet
- [ ] `map_columns(df)` — 中/英文字段名自动映射为内部英文名
- [ ] `detect_field_language(df)` — 自动检测表头是中文还是英文

### 1.4 数据导入页面 (`pages/5_📥_import_data.py`)

> **视觉参考**：`前端设计/import.html` — 步骤指示器、拖拽上传区、导入摘要统计卡片、数据预览表格。

- [ ] 文件上传组件（拖拽或点击上传 `.xlsx`，参考原型 `.upload-zone` 虚线边框 + hover 高亮）
- [ ] 步骤指示器（1.上传 → 2.预览与校验 → 3.导入确认，参考原型 `.import-steps`）
- [ ] 上传后自动保存并刷新快照列表
- [ ] 导入摘要统计（成功读取/阻断错误/警告/自动修复，参考原型 `.validation-stat`）
- [ ] 覆盖率信息展示（收益统计覆盖率、费用覆盖率、基准/目标配置状态）
- [ ] 原始数据预览表格（含系统计算列：holding_profit, holding_return）
- [ ] 下载标准模板按钮
- [ ] 「确认导入，进入看板」+「查看校验详情」操作按钮

### 1.5 侧边栏快照切换

- [ ] 在 `app.py` 侧边栏添加快照下拉选择框
- [ ] 使用 `st.session_state` 存储当前选中的快照路径和数据
- [ ] 切换快照时自动重新加载数据

**阶段一完成标准**：
- 上传一个 Excel → 自动保存到 `data/uploaded/` → 侧边栏下拉可切换 → 页面显示原始数据预览

---

## 阶段二：数据清洗与校验

> 预计 2-3 天 | 优先级 P0 | 产出：完整的数据清洗管线 + 三级校验报告

### 2.1 数据清洗模块 (`utils/data_cleaner.py`)

- [ ] `clean_currency(value)` — 去除千分位逗号 `12,000 → 12000`
- [ ] `clean_percentage(value)` — 百分号转小数 `4.35% → 0.0435` 或 `85% → 85`（根据字段类型）
- [ ] `clean_product_code(code)` — 产品代码补全前导零（如 `1 → 000001`），以文本格式存储
- [ ] `clean_empty_to_none(value)` — 空字符串/空白 → None
- [ ] `auto_calculate_holding_profit(row)` — 若 `cost_amount` 存在但 `holding_profit` 为空，自动计算
- [ ] `auto_calculate_holding_return(row)` — 若 `cost_amount` 和 `holding_profit` 存在但 `holding_return` 为空，自动计算
- [ ] `clean_dataframe(df)` — 对整表执行上述清洗流程

### 2.2 数据校验模块 (`utils/validator.py`)

三级校验规则实现：

**阻断错误（返回错误列表，有则拒绝导入）**：

- [ ] `check_missing_current_value(df)` — 当前金额为空
- [ ] `check_negative_current_value(df)` — 当前金额为负
- [ ] `check_negative_cost_amount(df)` — 持有成本为负
- [ ] `check_missing_product_name(df)` — 产品名称为空
- [ ] `check_missing_platform(df)` — 平台为空
- [ ] `check_missing_statistic_date(df)` — 统计日期为空
- [ ] `check_date_format(df)` — 日期格式非 `YYYY-MM-DD`

**警告提示（返回警告列表，允许导入但提醒确认）**：

- [ ] `check_missing_asset_class(df)` — 资产大类为空（自动归为"其他类"）
- [ ] `check_missing_product_type(df)` — 产品类型为空（自动归为"其他资产"）
- [ ] `check_profit_deviation(df)` — 持有收益与 `current_value - cost_amount` 偏差 > 1 元
- [ ] `check_abnormal_return(df)` — 收益率 > 100% 或 < -80%
- [ ] `check_product_code_number_format(df)` — 产品代码疑似数字格式（前导零丢失）
- [ ] `check_duplicate_records(df)` — 同一快照内（统计日期+平台+产品名称）重复
- [ ] `check_shares_price_mismatch(df)` — 份额×当前价格与当前金额偏差 > 5%
- [ ] `check_target_allocation_sum(settings)` — 目标配置比例总和不等于 100%

**自动修复（返回修复日志）**：

- [ ] `auto_fix_currency(df)` — 金额含逗号自动清洗
- [ ] `auto_fix_percentage(df)` — 收益率/管理费率/底层权益占比百分号自动转换
- [ ] `auto_fix_missing_cost(df)` — 缺少成本时自动计算收益/收益率

### 2.3 校验报告生成

- [ ] `generate_validation_report(df)` — 调用所有校验规则，输出结构化结果：
  ```python
  {
      "errors": [{"row": 3, "field": "current_value", "message": "当前金额不能为空"}],
      "warnings": [{"row": 7, "field": "asset_class", "message": "资产大类为空，已归为其他类"}],
      "fixes": [{"row": 2, "field": "current_value", "message": "已清除千分位逗号"}],
      "summary": {"total_rows": 32, "error_count": 0, "warning_count": 3, "fix_count": 6}
  }
  ```

### 2.4 数据校验页面 (`pages/6_🔍_validation.py`)

> **视觉参考**：`前端设计/validation.html` — 三级摘要统计卡片 + 阻断/警告/修复分类表格 + 配置校验。

- [ ] 三级分层校验摘要（阻断 🔴 / 警告 🟡 / 修复 🟢 统计卡片，参考原型 `.validation-stat`）
- [ ] 阻断错误详情表（规则名称 + 状态 + 说明，通过/失败区分）
- [ ] 警告提示详情表（规则名称 + 详情行号 + 建议操作）
- [ ] 自动修复日志表（规则名称 + 处理记录 + 结果状态）
- [ ] 配置校验表（基准配置状态 / 目标比例总和 / 大类引用检查）
- [ ] 支持按错误级别筛选
- [ ] 显示收益统计覆盖率

**阶段二完成标准**：
- 上传一个 Excel → 自动清洗 → 三级校验报告正确展示 → 覆盖率计算正确

---

## 阶段三：首页资产总览

> 预计 2.5 天 | 优先级 P0 | 产出：核心看板，一页看清资产全貌

### 3.1 统计分析模块 (`utils/analyzer.py`)

- [ ] `calc_total_assets(df)` — 总资产
- [ ] `calc_total_cost(df)` — 总持有成本（有成本资产）
- [ ] `calc_total_profit(df)` — 总持有收益
- [ ] `calc_total_return(df)` — 总收益率
- [ ] `calc_coverage(df)` — 收益统计覆盖率
- [ ] `calc_product_count(df)` — 产品数量
- [ ] `calc_platform_count(df)` — 平台数量
- [ ] `calc_max_single_ratio(df)` — 最大单品占比
- [ ] `calc_equity_ratio(df)` — 权益类占比
- [ ] `calc_platform_distribution(df)` — 按平台分组金额
- [ ] `calc_asset_class_distribution(df)` — 按资产大类分组金额
- [ ] `calc_top10_holdings(df)` — 持仓 Top 10
- [ ] `calc_top10_profit(df)` — 收益 Top 10
- [ ] `calc_top10_loss(df)` — 亏损 Top 10

### 3.2 基准对比模块 (`utils/benchmarks.py`)

- [ ] `load_benchmark_config()` — 从 session_state 加载基准配置
- [ ] `save_benchmark_config(name, start, end)` — 保存基准配置
- [ ] `calc_benchmark_return(config)` — 计算基准收益率
- [ ] `calc_relative_return(portfolio_return, benchmark_return)` — 相对收益

### 3.3 KPI 指标卡片组件 (`utils/ui_components.py`)

> **视觉参考**：`前端设计/overview.html` 中的 KPI 卡片三行布局、颜色区分逻辑。
> CSS 样式参考 `前端设计/css/components.css` 中的 `.kpi-card` / `.kpi-label` / `.kpi-value` / `.kpi-sub` 类。

- [ ] `render_kpi_card(label, value, suffix, delta, alert_level)` — 通用 KPI 卡片
  - `alert_level`: `normal` / `warning`（橙色边框，对应 `.warn-card`）/ `profit`（红色）/ `loss`（绿色）
- [ ] `render_kpi_row(cards)` — 单行排列多个卡片（4 列网格，对应 `.grid-4`）
- [ ] 卡片样式：圆角 (`var(--radius-sm) 8px`)、阴影 (`--elev-flat`)、响应式布局
- [ ] 金额数值使用 `font-display` 风格（Georgia serif），标注文字使用 `font-body`

### 3.4 首页页面 (`pages/1_🏠_overview.py`)

> **视觉参考**：`前端设计/overview.html` — 完整的页面布局、KPI 卡片顺序、图表排列方式、数据质量提示卡片。

- [ ] **第一行**：总资产、总持有收益、总收益率、收益统计覆盖率
- [ ] **第二行**：产品数量、平台数量、最大单品占比（>20% 橙色）、权益类占比
- [ ] **第三行**：基准对比（跑赢绿色/跑输红色 + 差值）、目标配置偏离（偏离大类数量 + 橙色警示）
- [ ] 平台资产占比图（Plotly 饼图/环形图，配色使用 `CHART_COLORS`）
- [ ] 资产大类占比图（Plotly 环形图，配色使用 `ASSET_CLASS_COLORS`）
- [ ] 当前 vs 目标配置对比图（Plotly 子弹图，若未设定目标则显示引导文案；偏离 ±5% 橙色高亮）
- [ ] 产品持仓 Top 10（横向柱状图）
- [ ] 收益贡献瀑布图
- [ ] 基准对比详情图（双柱对比）
- [ ] 亏损产品 Top 10（横向柱状图）
- [ ] 数据质量提示卡片（校验摘要 + 覆盖率，参考原型中的 `.card` + `.badge` 组合）
- [ ] 总收益率旁标注「简单持有期收益率」提示（ⓘ hover 说明）
- [ ] 空状态检测：无数据时展示引导卡片（参考原型 `.empty-state` 样式）

**阶段三完成标准**：
- 首页展示 10 个 KPI 卡片 + 6 个图表区域 → 数值与 Excel 手工核算一致 → 空状态和异常状态正确处理

---

## 阶段四：资产配置与收益分析

> 预计 3-3.5 天 | 优先级 P0 | 产出：多维度配置图表 + 深度收益分析

### 4.1 图表模块 (`utils/charts.py`)

> **配色参考**：使用 `utils/design_tokens.py` 中的 `CHART_COLORS`（10 色图表色板）和 `ASSET_CLASS_COLORS`（资产大类固定色）。
> **样式参考**：`前端设计/css/tokens.css` 中 `--chart-1` 到 `--chart-10` 定义。
> **Plotly 模板**：统一使用 `plotly_white` 模板，font-family 设为 Georgia/Arial，paper_bgcolor 设为 `#f5f4ed`。

- [ ] `apply_fundlens_theme(fig: go.Figure) -> go.Figure` — 统一 Plotly 图表主题（模板、字体、边距、背景色）
- [ ] `plot_pie(labels, values, title, colors)` — 通用饼图/环形图（使用 `CHART_COLORS`）
- [ ] `plot_bar(x, y, title, color, orientation)` — 通用柱状图（支持横向/纵向）
- [ ] `plot_bullet(current, target, labels)` — 子弹图（当前 vs 目标配置对比，偏离 ±5% 橙色）
- [ ] `plot_waterfall(categories, values, title)` — 瀑布图（收益贡献度分解，正值 terracotta / 负值 sage）
- [ ] `plot_dual_bar(label, value1, value2, title1, title2)` — 双柱对比图（基准对比：accent vs chart-2）
- [ ] `plot_treemap(labels, values, parents, title)` — 树图（可选，用于资产层级展示）
- [ ] 所有图表函数处理空数据降级（`go.Figure().add_annotation(text="暂无数据")`）

### 4.2 资产配置页面 (`pages/2_📊_allocation.py`)

> **视觉参考**：`前端设计/allocation.html` — Tab 切换、环形图网格布局（3 列）、子弹图、集中度分析图、费用估算图。

- [ ] Tab 切换（配置总览 / 目标 vs 当前 / 详细维度），参考原型 `.tabs` + `.tab-btn`
- [ ] **配置总览 Tab**：平台/大类/产品类型/市场区域/资金用途/风险等级 6 个环形图（3 列网格）
- [ ] **目标 vs 当前 Tab**：子弹图 + 偏离详情表格（偏离超 ±5% 橙色高亮 + ⚠ 图标）
- [ ] **详细维度 Tab**：流动性分布 + 平台×大类交叉分析
- [ ] 单产品集中度图（横向柱状图，>20% 橙色 + ⚠ 标记，20% 阈值虚线）
- [ ] 年化费用估算图表（P1，各资产大类年化费用柱状图 + 合计/占资产比）
- [ ] 集中度文字提示（中性提醒，不给出投资建议）

### 4.3 收益分析页面 (`pages/3_📈_profit_analysis.py`)

> **视觉参考**：`前端设计/profit-analysis.html` — 摘要统计条、算法说明提示框、平台/大类收益对比、瀑布图、基准对比、盈亏排行。

- [ ] 总持有收益 + 总收益率 + 收益统计覆盖率 + 相对收益摘要条（参考原型 `.summary-bar` + `.summary-stat`）
- [ ] **收益率算法说明提示框**（参考原型 `.algo-note`：橙色背景 + 边框，解释简单收益率 vs TWR/IRR）
- [ ] **基准对比图**（总收益率 vs 基准收益率双柱图 + 相对收益数值 + 基准点位变化标注）
- [ ] 平台收益对比（分组柱状图）
- [ ] 资产大类收益对比（分组柱状图）
- [ ] **收益贡献度瀑布图**（核心新增，从 0 → 各类收益贡献 → 总收益）
- [ ] 产品盈利 Top 10（红色柱状图）
- [ ] 产品亏损 Top 10（绿色柱状图）
- [ ] 收益率 Top 10（表格 + 柱状图）
- [ ] 亏损率 Top 10（表格 + 柱状图）
- [ ] 所有图表的空状态处理（成本数据不足时的降级展示）

**阶段四完成标准**：
- 配置页 10 个图表区域全部正确渲染 → 瀑布图正确展示贡献路径 → 目标配置对比高亮正确 → 费用图表正确

---

## 阶段五：产品明细与导出

> 预计 1-2 天 | 优先级 P0（表格）/ P1（导出）| 产出：可筛选搜索排序的完整数据表

### 5.1 产品明细页面 (`pages/4_📋_detail_table.py`)

> **视觉参考**：`前端设计/detail-table.html` — 多行筛选器、搜索框、数据表格（含排序箭头和 hover 效果）、导出按钮。

- [ ] 完整资产明细表（含系统计算列：holding_profit、holding_return）
- [ ] **筛选器**（多选下拉框，支持联动，参考原型 `.filters-bar` 布局）：
  - 平台 / 资产大类 / 产品类型 / 市场区域 / 资金用途 / 收益状态
- [ ] **搜索框**（产品名称模糊搜索 + 产品代码精确/模糊搜索）
- [ ] **排序**：点击表头按金额/收益/收益率升降序（排序箭头 `.sort-arrow` 样式）
- [ ] 表格样式：数字列右对齐+等宽数字 (`tabular-nums`)、盈亏颜色区分、hover 行高亮
- [ ] 筛选后数据行数统计（"共 N 条"）
- [ ] 导出按钮（P1）：导出当前筛选结果为 Excel/CSV

### 5.2 导出功能 (`utils/exporter.py`) — P1

- [ ] `export_to_excel(df, filepath)` — 导出为 `.xlsx`
- [ ] `export_to_csv(df, filepath)` — 导出为 `.csv`
- [ ] 导出时包含系统计算列和筛选状态说明

**阶段五完成标准**：
- 所有筛选器可联动 → 搜索可模糊匹配 → 排序正确 → 导出文件内容正确

---

## 阶段六：设置页 + UI 打磨 + 联调验收

> 预计 2 天 | 优先级 P0（设置）/ P1（美化）| 产出：完整可交付的 v1.0

### 6.1 设置页面 (`pages/7_⚙️_settings.py`)

> **视觉参考**：`前端设计/settings.html` — 双列布局（配置在左，偏好在右）、表单样式、滑块+输入框组合、开关组件。

- [ ] **基准指数配置**：
  - 基准名称输入（如"沪深300"）
  - 基准期初值（指数点位）
  - 基准期末值（指数点位）
  - 自动计算并显示基准收益率公式和结果
  - 保存/重置按钮
- [ ] **目标配置比例设定**：
  - 各资产大类滑块 + 输入框组合（参考原型 range + number input 联动）
  - 实时显示比例总和 + 不等于 100% 时橙色警告
  - 保存/重置按钮
- [ ] **图表主题偏好**：
  - 盈亏颜色：红涨绿跌（国内习惯）/ 绿涨红跌（国际习惯）
  - 浅色/深色模式（P1）
- [ ] **隐私与安全**：
  - 模糊模式开关（参考原型 `.toggle-switch`）
  - 数据安全说明文字
- [ ] **数据管理**：
  - 已保存快照列表
  - 删除快照按钮（带确认弹窗）
  - 全部数据导出/备份按钮
- [ ] **关于 FundLens**：版本号、技术栈、定位说明

### 6.2 UI 打磨 (`assets/style.css`)

> **视觉参考**：`前端设计/css/components.css`（完整组件库）+ `前端设计/css/tokens.css`（设计令牌）。
> 目标：将原型中的关键视觉特征移植到 Streamlit 自定义 CSS，实现**高信息密度金融仪表盘**风格。

#### 6.2.1 设计令牌注入

- [ ] 在 `style.css` 顶部定义 CSS 变量（从 `tokens.css` 提取，颜色值保持一致）
- [ ] `:root` 中设置 `--bg`, `--surface`, `--fg`, `--muted`, `--meta`, `--accent` 等

#### 6.2.2 KPI 卡片样式（对标 `.kpi-card` 系列）

- [ ] KPI 卡片容器：白底 (`--surface`) + 圆角 (`8px`) + 细边框 (`--border`) + 内边距
- [ ] KPI 标签 (`.kpi-label`)：小号灰色字体 (`--meta`)
- [ ] KPI 数值 (`.kpi-value`)：大号 display 字体、profit/loss/warn 颜色变量
- [ ] KPI 副标题 (`.kpi-sub`)：小号 muted 字体
- [ ] 橙色警示卡片 (`.warn-card`)：橙色边框 (`--warn`) + 暖色背景
- [ ] 4 列网格 (`.grid-4`)：响应式，小屏降为 2 列或 1 列

#### 6.2.3 图表容器样式（对标 `.chart-card`）

- [ ] 图表卡片：白底 + 边框 + 圆角 + 内边距
- [ ] 图表标题：`font-display`，`--text-lg` 大小
- [ ] 双列图表行：`grid-template-columns: 1fr 1fr`

#### 6.2.4 数据表格样式（对标 `.data-table`）

- [ ] 表头：小号大写字母 + muted 颜色 + 排序箭头
- [ ] 数据行：hover 浅色背景、底部细边框
- [ ] 数字列右对齐 + `font-variant-numeric: tabular-nums`
- [ ] 盈亏单元格颜色：profit-cell (red) / loss-cell (green)

#### 6.2.5 组件样式

- [ ] 筛选器/搜索框（对标 `.filters-bar`, `.filter-select`, `.search-input`）
- [ ] 状态徽章（对标 `.badge-error`, `.badge-warn`, `.badge-success`, `.badge-muted`）
- [ ] 上传区（对标 `.upload-zone`：虚线边框 + hover 高亮）
- [ ] 校验统计卡片（对标 `.validation-stat`：彩色背景 + 大数字）
- [ ] 空状态引导（对标 `.empty-state`：居中布局 + 引导文案）
- [ ] 按钮样式（对标 `.btn`, `.btn-primary`）
- [ ] 侧边栏样式（对标 `.app-sidebar`，减少 Streamlit 默认样式干扰）

### 6.3 空状态与边界处理

- [ ] 未导入数据时首页展示引导卡片
- [ ] 未配置基准时基准对比区展示引导文案
- [ ] 未设定目标配置时目标对比区展示引导文案
- [ ] 数据全空/部分空的降级展示
- [ ] 成本数据全缺时收益率相关图表不崩溃

### 6.4 模糊模式 / 数据脱敏

- [ ] 全局模糊模式开关（侧边栏顶部）
- [ ] 开启后金额显示为 `***` 或 `X.X万`
- [ ] 百分比保留但隐藏绝对金额

### 6.5 数据安全说明

- [ ] 侧边栏底部/页脚展示安全声明
- [ ] 首次启动时展示隐私提示（仅一次）

### 6.6 收益率算法说明标注

- [ ] 收益率数字旁添加 `ⓘ` 图标
- [ ] hover 或点击显示："当前为简单收益率 = 持有收益 / 持有成本。不反映资金投入的时间差异。"
- [ ] 在收益分析页面底部添加完整说明

### 6.7 联调与验收

- [ ] 将 `前端设计/js/sample-data.js` 中的 8 条示例数据转换为 Python test fixture（`tests/fixtures/sample_2026Q1.py`）
- [ ] 用 sample-data.js 中的 `computeMetrics()` 计算逻辑验证 Python 端 `analyzer.py` 的各项指标一致性
- [ ] 准备完整示例 Excel（覆盖设计文档 29 节列出的 17 种测试数据）
- [ ] 跑通完整流程：上传 → 校验 → 看板浏览 → 切换快照 → 设置基准 → 设置目标 → 导出
- [ ] 核对所有统计指标与 Excel 手工计算一致
- [ ] **前端设计合规检查**：对比 7 个 HTML 原型页面，检查实现页面的布局、配色、间距是否一致
- [ ] 测试边界情况（空文件、全缺成本、全缺分类、极大/极小数值）
- [ ] 性能测试（100+ 条资产记录时页面加载速度）

**阶段六完成标准**：
- 设置页三项配置可正常保存和读取 → UI 美观 → 空状态和异常不崩溃 → 完整流程无卡点 → 所有指标计算正确

---

## 文件与模块依赖关系

```
app.py  ← 主入口，依赖以下所有模块
├── utils/file_manager.py    ← 无依赖
├── utils/data_loader.py     ← 依赖 file_manager
├── utils/data_cleaner.py    ← 依赖 data_loader
├── utils/validator.py       ← 依赖 data_cleaner
├── utils/analyzer.py        ← 依赖 data_cleaner
├── utils/benchmarks.py      ← 依赖 session_state
├── utils/charts.py          ← 依赖 analyzer, benchmarks
├── utils/ui_components.py   ← 无依赖
├── utils/exporter.py        ← 依赖 data_cleaner（P1）
└── pages/
    ├── 1_🏠_overview.py     ← 依赖 analyzer, benchmarks, charts, ui_components
    ├── 2_📊_allocation.py   ← 依赖 analyzer, charts, benchmarks
    ├── 3_📈_profit_analysis.py ← 依赖 analyzer, charts, benchmarks
    ├── 4_📋_detail_table.py ← 依赖 data_cleaner, exporter (P1)
    ├── 5_📥_import_data.py  ← 依赖 file_manager, data_loader, data_cleaner, validator
    ├── 6_🔍_validation.py   ← 依赖 validator
    └── 7_⚙️_settings.py    ← 依赖 benchmarks, session_state
```

---

## 开发顺序建议

| 顺序 | 阶段 | 原因 |
|---|---|---|
| **1** | 阶段一 | 先把骨架跑起来，后续所有模块依赖文件管理和数据加载 |
| **2** | 阶段二 | 数据质量是所有分析的前提，先确保清洗和校验正确 |
| **3** | 阶段三 | 首页是核心价值页面，优先交付给用户可用 |
| **4** | 阶段四 | 深度分析，依赖 analyzer 和 charts 模块 |
| **5** | 阶段五 | 产品明细相对独立，可与阶段四并行 |
| **6** | 阶段六 | 设置页依赖全局状态，联调验收放在最后 |

---

## 关键技术决策备忘

| 决策 | 选择 | 理由 |
|---|---|---|
| **UI 视觉基准** | `前端设计/` HTML 原型（warm palette） | 原型已定义完整的组件样式和设计令牌，确保实现一致性 |
| **配色方案** | 陶土暖色系 (`#c96442` accent) + 10 色图表色板 | 来自 `tokens.css`，温暖且专业的金融看板风格 |
| **CSS 设计令牌** | `utils/design_tokens.py` + `assets/style.css` CSS 变量 | Python 端和 CSS 端双重定义，保证绘图和样式统一 |
| 数据存储 | 当前用 Pandas DataFrame + Excel 文件，后续迁移 SQLite | v1.0 保持简单，SQLite 是 P1 |
| 状态管理 | `st.session_state` | Streamlit 原生支持，足够用 |
| 图表库 | Plotly | 交互式（悬停、缩放、导出），Streamlit 原生支持 |
| 基准/设置存储 | `st.session_state`（单次会话），后续 SQLite 持久化 | 保持简单 |
| CSS 方案 | 单文件 `assets/style.css` + Streamlit 原生 style 参数 | 对标 `components.css` 的组件类 |
| 多页面 | Streamlit `pages/` 目录自动发现 | 原生支持，零配置 |
| **示例数据** | `前端设计/js/sample-data.js` 转为 Python test fixture | 8 条数据覆盖支付宝 + 同花顺 6 种资产大类，用作验收基准 |
