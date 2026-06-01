# CLAUDE.md

> FundLens 项目上下文指引文件，供 AI 助手参考。

---

## 项目概述

FundLens 是一个面向个人投资者的**本地化多平台资产快照分析系统**。基于 Excel 快照数据，统一统计支付宝基金/理财资产与同花顺 ETF 资产，提供当前资产总览、目标配置偏离监控、基准对比、收益贡献度分解和产品明细管理。

**技术栈**：Python 3.10+ / Streamlit / Pandas / Plotly / OpenPyXL

---

## 常用命令

```bash
# 启动开发服务器（默认 http://localhost:8501）
streamlit run app.py

# 运行 Playwright E2E 测试（需先启动 streamlit 服务）
py tests/run_phase1_tests.py

# 安装依赖
pip install -r requirements.txt
```

---

## 关键文档索引

| 文档 | 路径 | 用途 |
|---|---|---|
| **项目设计文档（权威参考）** | `FundLens_项目设计文档_综合完善版_v2.0.md` | 完整的功能设计、数据模型、页面结构、指标体系 |
| **竞品分析报告** | `FundLens_竞品分析报告.md` | 竞品对比、功能差距分析、改进建议来源 |
| **开发任务清单** | `task.md` | 分阶段开发任务、模块依赖、工时估算 |
| **编码规范** | `coding.md` | Python/Streamlit/Pandas/Plotly 编码标准 |

---

## 开发原则

### 功能边界
- **做**：Excel 导入、数据清洗校验、资产配置统计、收益分析、基准对比、目标配置偏离监控、产品明细筛选搜索、统计导出
- **不做**：自动登录平台、自动同步行情、自动交易、投资建议（买入/卖出/调仓）、多用户系统、云端部署、移动端适配

### 设计原则
1. **以资产快照为核心** — 不追踪每日流水，记录季度资产状态
2. **基础数据与计算数据分离** — Excel 只填原始数据，收益/收益率由系统自动计算
3. **资产兼容与容错** — 不强制所有资产都有份额/净值，只要有"当前金额"即可参与统计
4. **客观呈现，不做决策代劳** — 可提示集中度/偏离，不给出买卖建议
5. **目标驱动配置** — 展示当前 vs 目标配置对比，偏离超过 ±5% 橙色提醒

### 核心指标
- 总资产、总持有收益、总收益率、收益统计覆盖率
- 基准对比（相对收益 = 总收益率 - 基准收益率）
- 最大单品占比（>20% 警示）、目标配置偏离度（>±5% 警示）

---

## 项目结构

```
FundLens/
├── app.py                    # 主入口（侧边栏、全局状态、快照切换）
├── requirements.txt          # streamlit, pandas, plotly, openpyxl
├── data/
│   ├── sample/               # 标准空白模板
│   └── uploaded/             # 用户上传的快照自动保存在此
├── utils/
│   ├── constants.py           # Session state key 常量
│   ├── design_tokens.py       # 设计令牌（颜色常量，CSS 变量镜像）
│   ├── file_manager.py        # 文件扫描、保存、加载
│   ├── data_loader.py         # Excel 读取与字段映射
│   ├── data_cleaner.py        # 格式清洗、自动计算收益
│   ├── validator.py           # 三级校验规则
│   ├── analyzer.py            # 分组聚合、指标计算
│   ├── benchmarks.py          # 基准对比
│   ├── charts.py              # Plotly 图表工厂
│   ├── ui_components.py       # 通用 HTML 组件（KPI 卡片、徽章、校验统计、步骤指示器）
│   ├── exporter.py            # 统计导出
│   └── template_generator.py  # Excel 标准模板生成
├── pages/
│   ├── 1_🏠_首页概览.py           # 首页概览
│   ├── 2_📊_资产配置.py           # 资产配置
│   ├── 3_📈_收益分析.py           # 收益分析
│   ├── 4_📋_产品明细.py           # 产品明细
│   ├── 5_📥_数据导入.py           # 数据导入
│   ├── 6_🔍_数据校验.py           # 数据校验
│   └── 7_⚙️_设置.py              # 设置
├── assets/
│   └── style.css             # 自定义样式（对标 前端设计/css/components.css）
├── tests/
│   └── fixtures/
│       └── sample_2026Q1.py  # 示例数据 fixture（从 前端设计/js/sample-data.js 转换）
└── 前端设计/                  # HTML/CSS/JS 原型（视觉基准，不参与运行时）
    ├── css/tokens.css         # 设计令牌 → 对应 utils/design_tokens.py
    ├── css/components.css     # 组件样式 → 对应 assets/style.css
    └── ...
```

---

## 数据模型要点

### 核心表 `asset_snapshot`

| 关键字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| statistic_date | date | 是 | 统计日期 |
| platform | string | 是 | 支付宝 / 同花顺 / 其他 |
| asset_class | string | 是 | 现金类/固收类/固收增强类/权益类/跨境类/其他类 |
| product_type | string | 是 | 纯债基金/固收+/QDII/宽基 ETF 等 |
| current_value | float | 是 | 当前金额（唯一强制金额字段） |
| cost_amount | float | 否 | 持有成本（为空则不参与收益率计算） |
| usage_purpose | string | 否 | 活钱/稳健/长期/保障/不分类 |
| annual_fee_rate | float | 否 | 年化管理费率 |

### 收益计算规则
- `holding_profit = current_value - cost_amount`（系统自动计算）
- 偏差 Δ ≤ 1 元以用户填写为准，Δ > 1 元警告并修正
- 总收益率仅基于有成本数据的资产计算
- 使用**简单收益率**，UI 中标注说明

### 分类体系（三维 + 可选）
- 资产大类 (asset_class) — 产品类型 (product_type) — 市场区域 (market_region)
- 资金用途 (usage_purpose) — 活钱/稳健/长期/保障（可选维度）

---

## 关键数据校验规则

三级分层：
- **阻断错误 🔴**：当前金额为空/为负、成本为负、产品名称为空、平台为空、日期缺失
- **警告提示 🟡**：收益偏差 > 1 元、收益率 > 100% 或 < -80%、分类缺失、重复记录、前导零丢失
- **自动修复 🟢**：金额逗号清洗、百分号转换、自动计算收益

---

## Session State Key 常量

```python
KEY_CURRENT_SNAPSHOT = "current_snapshot"
KEY_SNAPSHOT_DATA = "snapshot_data"
KEY_BENCHMARK_CONFIG = "benchmark_config"
KEY_TARGET_ALLOCATION = "target_allocation"
KEY_BLUR_MODE = "blur_mode"
```

---

## 配色常量

> 与 `前端设计/css/tokens.css` 保持一致，采用暖色调（Claude Design System）。

```python
# Surface
COLOR_BG = "#f5f4ed"           # 背景 — 暖羊皮纸
COLOR_SURFACE = "#faf9f5"      # 卡片/表面
COLOR_SURFACE_WARM = "#e8e6dc"  # 暖表面（hover 等）

# Foreground
COLOR_FG = "#141413"            # 主文字
COLOR_MUTED = "#5e5d59"         # 次要文字
COLOR_META = "#87867f"          # 辅助文字

# Border
COLOR_BORDER = "#f0eee6"        # 边框

# Accent — 陶土色
COLOR_ACCENT = "#c96442"

# Semantic
COLOR_PROFIT = "#c43d3d"       # 暖红色 — 盈利（国内习惯：红=涨）
COLOR_LOSS = "#3d8c40"         # 绿色 — 亏损
COLOR_WARNING = "#ff9800"       # 橙色警示
COLOR_SUCCESS = "#17a34a"       # 绿色成功
COLOR_DANGER = "#b53333"        # 红色危险

# Chart palette (10 colors)
CHART_COLORS = [
    "#c96442", "#5e5d59", "#d4a574", "#8b9a8b", "#b8a9a0",
    "#6b7b6b", "#d4c5bc", "#4d4c48", "#c4b5a5", "#3d3d3a",
]

# 资产大类固定配色
ASSET_CLASS_COLORS = {
    "现金类": "#8b9a8b",
    "固收类": "#5e5d59",
    "固收增强类": "#b8a9a0",
    "权益类": "#c96442",
    "跨境类": "#d4a574",
    "其他类": "#d4c5bc",
}
```

---

## 双色彩系统：Python 常量 vs CSS 变量

项目使用两套并行的色彩系统，各自有不同的适用场景：

| 场景 | 使用 | 示例 |
|---|---|---|
| **Plotly 图表**（`utils/charts.py`） | Python 常量 `COLOR_*` | `COLOR_PROFIT`, `CHART_COLORS` |
| **st.markdown 内联 HTML**（所有页面） | CSS 变量 `var(--*)` | `var(--accent)`, `var(--meta)`, `var(--warn)` |
| **Python 条件逻辑中的颜色判断** | Python 常量 `COLOR_*` | `COLOR_PROFIT if relative >= 0 else COLOR_LOSS` |
| **st.markdown HTML 样式** | CSS 变量 | `style="color:var(--meta);font-size:var(--text-sm);"` |

CSS 变量定义在 `assets/style.css` 的 `:root` 块中，包括颜色、字号（`--text-xs` ~ `--text-4xl`）、间距（`--space-1` ~ `--space-12`）、圆角、动效等。
Python 颜色常量定义在 `utils/design_tokens.py` 中，仅颜色常量被实际导入使用；字号/间距 Python 常量未被使用（页面直接写 CSS 变量字符串）。

⚠️ **规则**：在 `st.markdown(unsafe_allow_html=True)` 的 HTML 字符串中只用 CSS 变量，不要引用 Python 颜色常量（会导致 NameError 且无法被 linter 捕获）。

---

## 开发约定

- 参考 `coding.md` 中的完整编码规范
- 函数必须添加类型注解
- 使用 `logging` 而非 `print()`
- `utils/` 模块不得调用 `st.` API
- 文件名使用 `snake_case`，类名使用 `PascalCase`
- 所有图表函数须处理空数据降级展示
