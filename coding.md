# FundLens 编码规范

> 适用技术栈：Python 3.10+ / Streamlit / Pandas / Plotly / OpenPyXL
> 本规范用于约束 FundLens 项目的代码风格、命名、结构和最佳实践。

---

## 1. Python 基础规范

### 1.1 代码风格

- 严格遵循 **PEP 8**
- 缩进：**4 个空格**，禁止 Tab
- 行宽上限：**100 字符**（非严格的 79）
- 文件末尾保留一个空行
- 行尾不留空白字符

### 1.2 引号

- 字符串统一使用**双引号** `"`
- 仅在字符串内部包含双引号时使用单引号 `'`
- 文档字符串（docstring）使用三双引号 `"""`

### 1.3 导入顺序

```python
# 1. 标准库
import os
from pathlib import Path

# 2. 第三方库
import pandas as pd
import streamlit as st
import plotly.express as px

# 3. 项目内部模块
from utils.data_loader import read_asset_snapshot
from utils.analyzer import calc_total_assets
```

- 每组之间空一行
- 不使用 `from module import *`
- 按字母序排列

### 1.4 命名规范

| 类型 | 规范 | 示例 |
|---|---|---|
| 模块/文件名 | `snake_case` | `data_cleaner.py` |
| 类名 | `PascalCase` | `ValidationReport` |
| 函数/方法 | `snake_case` | `calc_total_assets()` |
| 变量 | `snake_case` | `total_assets` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_SINGLE_RATIO` |
| 私有函数/变量 | 前缀 `_` | `_parse_date()` |

### 1.5 类型注解

- **所有函数必须添加类型注解**

```python
# 正确
def calc_total_assets(df: pd.DataFrame) -> float:
    return df["current_value"].sum()

# 正确
def load_snapshot(filepath: Path) -> pd.DataFrame | None:
    ...

# 错误 — 无类型注解
def calc_total_assets(df):
    return df["current_value"].sum()
```

### 1.6 错误处理

- 使用具体的异常类型，不使用裸 `except:`
- 仅在确实可恢复的地方捕获异常
- 不可恢复的错误直接让其抛出

```python
# 正确
try:
    df = pd.read_excel(filepath, sheet_name="asset_snapshot")
except FileNotFoundError:
    st.error(f"文件不存在: {filepath}")
    return None
except ValueError as e:
    st.error(f"Sheet 'asset_snapshot' 未找到: {e}")
    return None

# 错误
try:
    df = pd.read_excel(filepath)
except:
    pass
```

---

## 2. Streamlit 专有规范

### 2.1 页面文件命名

- 使用 Streamlit `pages/` 目录自动发现机制
- 文件名格式：`序号_图标_描述.py`，如 `1_🏠_overview.py`
- 图标使用 emoji，描述使用英文

### 2.2 页面配置

每个页面文件顶部设置页面属性：

```python
# pages/1_🏠_overview.py
import streamlit as st

st.set_page_config(
    page_title="FundLens - 首页概览",
    page_icon="🏠",
    layout="wide",
)
```

### 2.3 状态管理

- 使用 `st.session_state` 管理跨页面共享状态
- session_state key 统一使用 `snake_case`
- 关键的 key 定义为模块级常量：

```python
# app.py
KEY_CURRENT_SNAPSHOT = "current_snapshot"
KEY_SNAPSHOT_DATA = "snapshot_data"
KEY_BENCHMARK_CONFIG = "benchmark_config"
KEY_TARGET_ALLOCATION = "target_allocation"
KEY_BLUR_MODE = "blur_mode"
```

- 初始化放在 `app.py` 中一次性完成：

```python
if KEY_SNAPSHOT_DATA not in st.session_state:
    st.session_state[KEY_SNAPSHOT_DATA] = None
```

### 2.4 缓存

- 对计算密集型操作使用 `@st.cache_data`
- 缓存函数的输入参数应简单可哈希

```python
@st.cache_data(ttl=600)
def load_and_clean_snapshot(filepath: str) -> pd.DataFrame:
    ...
```

- 不在缓存函数内部使用 `st.` API

### 2.5 页面布局

- 优先使用 `layout="wide"`
- 使用 `st.columns()` 实现多列布局
- KPI 卡片行一行不超过 4 个
- 图表使用 `st.plotly_chart(use_container_width=True)`

---

## 3. Pandas 专有规范

### 3.1 DataFrame 操作

- 优先使用方法链（method chaining），避免中间变量
- 使用 `.loc[]` 和 `.iloc[]` 而非链式索引
- 避免在循环中逐行操作 DataFrame

```python
# 正确 — 方法链
result = (
    df.query("current_value > 0")
    .groupby("asset_class")["current_value"]
    .sum()
    .reset_index()
)

# 正确 — 向量化
df["holding_profit"] = df["current_value"] - df["cost_amount"]

# 错误 — 逐行循环
for idx, row in df.iterrows():
    df.at[idx, "holding_profit"] = row["current_value"] - row["cost_amount"]
```

### 3.2 空值处理

- 使用 `pd.NA` 而非 `None` 或 `np.nan`（pandas 2.0+）
- 使用 `.fillna()` / `.dropna()` 明确处理空值
- 金额字段空值统一填充为 `0`（仅在确认合理的场景）

### 3.3 数据类型

- 读取 Excel 后显式指定列类型：

```python
dtype_map = {
    "product_code": "string",    # 产品代码强制文本
    "platform": "string",
    "asset_class": "string",
    "current_value": "float64",
    "cost_amount": "float64",
}
df = df.astype(dtype_map)
```

### 3.4 字段名映射

使用常量字典做中英文字段映射：

```python
COLUMN_MAP = {
    "统计日期": "statistic_date",
    "平台": "platform",
    "资产大类": "asset_class",
    # ...
}
```

---

## 4. Plotly 专有规范

### 4.1 图表函数签名

每个图表函数接受 DataFrame 并返回 `plotly.graph_objects.Figure`：

```python
def plot_platform_distribution(df: pd.DataFrame) -> go.Figure:
    """平台资产占比饼图"""
    data = df.groupby("platform")["current_value"].sum().reset_index()
    fig = px.pie(data, values="current_value", names="platform", title="平台资产占比")
    return fig
```

### 4.2 配色方案

- 使用项目统一的配色常量（与 `前端设计/css/tokens.css` 保持一致）：

```python
# utils/charts.py (from utils/design_tokens.py)
COLOR_PROFIT = "#c43d3d"       # 暖红色 — 盈利（国内习惯：红=涨）
COLOR_LOSS = "#3d8c40"         # 绿色 — 亏损
COLOR_ACCENT = "#c96442"       # 陶土色主色
COLOR_WARNING = "#ff9800"      # 橙色警示
COLOR_BG = "#f5f4ed"           # 背景 — 暖羊皮纸
COLOR_SURFACE = "#faf9f5"      # 卡片/表面

# 图表色板（10 色）
CHART_COLORS = [
    "#c96442", "#5e5d59", "#d4a574", "#8b9a8b", "#b8a9a0",
    "#6b7b6b", "#d4c5bc", "#4d4c48", "#c4b5a5", "#3d3d3a",
]

# 资产大类固定配色（保证一致性）
ASSET_CLASS_COLORS = {
    "现金类": "#8b9a8b",    # muted sage
    "固收类": "#5e5d59",    # olive gray
    "固收增强类": "#b8a9a0", # warm stone
    "权益类": "#c96442",    # terracotta
    "跨境类": "#d4a574",    # warm sand
    "其他类": "#d4c5bc",    # warm blush
}
```

### 4.3 图表样式

- 所有图表统一使用 Plotly 模板

```python
def apply_fundlens_theme(fig: go.Figure) -> go.Figure:
    fig.update_layout(
        template="plotly_white",
        font=dict(family="Georgia, Arial, sans-serif"),
        margin=dict(l=20, r=20, t=40, b=20),
        paper_bgcolor="#f5f4ed",  # --bg
        plot_bgcolor="#faf9f5",   # --surface
    )
    return fig
```

- 饼图/环形图显示百分比标签
- 柱状图显示数值标签在柱顶

### 4.4 空数据降级

每个图表函数必须处理空数据：

```python
def plot_platform_distribution(df: pd.DataFrame) -> go.Figure:
    if df.empty or df["current_value"].sum() == 0:
        fig = go.Figure()
        fig.add_annotation(text="暂无数据", showarrow=False)
        return apply_fundlens_theme(fig)
    # 正常绘图逻辑...
```

---

## 5. 项目结构规范

### 5.1 模块职责

```
utils/
├── file_manager.py    # 文件 I/O：扫描、保存、加载
├── data_loader.py     # Excel 读取：Sheet 解析、字段映射
├── data_cleaner.py    # 数据清洗：金额清洗、收益自动计算
├── validator.py       # 数据校验：三级校验规则，返回结构化报告
├── analyzer.py        # 统计分析：分组聚合、指标计算
├── benchmarks.py      # 基准对比：基准收益率计算
├── charts.py          # 图表生成：Plotly 图表工厂函数
├── exporter.py        # 数据导出：Excel/CSV 导出（P1）
└── ui_components.py   # UI 组件：KPI 卡片、通用组件
```

### 5.2 模块依赖规则

- `utils/` 模块之间可以有依赖，但不形成循环
- `utils/` 模块**不得**导入 `pages/` 模块
- `pages/` 模块可以导入任意 `utils/` 模块
- `app.py` 只导入 `utils/` 和 `pages/`

### 5.3 函数设计

- 每个函数**只做一件事**
- 纯数据处理函数不应调用 `st.` API
- UI 相关逻辑放在 `pages/` 中，不放在 `utils/` 中
- 长度超过 40 行的函数应考虑拆分

---

## 6. 测试与调试规范

### 6.1 日志

- 使用 Python 标准 `logging` 模块，不使用 `print()`
- 日志级别：DEBUG（开发调试）、INFO（关键流程）、WARNING（异常数据）、ERROR（阻断错误）

```python
import logging

logger = logging.getLogger(__name__)

def clean_currency(value: str) -> float:
    logger.debug(f"清洗金额: {value}")
    ...
```

### 6.2 调试入口

每个 `utils/` 模块应包含 `if __name__ == "__main__":` 调试入口：

```python
# utils/analyzer.py
if __name__ == "__main__":
    import pandas as pd
    # 用示例数据测试
    from utils.data_loader import read_asset_snapshot

    df = read_asset_snapshot("data/sample/FundLens_Asset_Snapshot_Template.xlsx")
    print(f"总资产: {calc_total_assets(df):.2f}")
    print(f"总收益率: {calc_total_return(df):.2%}")
```

---

## 7. 文档与注释规范

### 7.1 文档字符串

- 仅对公开函数添加单行 docstring
- 不写多行 docstring，函数名 + 类型注解已足够说明

```python
# 正确 — 简洁一行
def calc_total_assets(df: pd.DataFrame) -> float:
    """所有资产当前金额之和"""
    return df["current_value"].sum()

# 不必要 — 多行 docstring
def calc_total_assets(df: pd.DataFrame) -> float:
    """计算总资产。
    
    Args:
        df: 资产快照 DataFrame
        
    Returns:
        总资产的浮点数值
    """
    return df["current_value"].sum()
```

### 7.2 行内注释

- 只在 WHY（为什么这么做）时写注释，不写 WHAT（做了什么）
- 代码已经讲清楚的事，不需要注释

```python
# 正确 — 解释 WHY
# Excel 可能将 000001 存储为数字 1，需补全前导零
code = str(int(code)).zfill(6)

# 错误 — 复述代码
# 将代码转为字符串
code = str(code)
```

### 7.3 文件头

项目文件不添加文件头注释（作者、日期等），这些信息由 git 管理。

---

## 8. 安全检查清单

| 检查项 | 说明 |
|---|---|
| 文件路径 | 确保只读取项目 `data/` 目录内的文件，禁止路径遍历 |
| 数据隐私 | 所有数据仅本地处理，代码中不包含任何网络上传逻辑 |
| 依赖安全 | `requirements.txt` 中的依赖版本固定，避免自动升级引入风险 |
| Git 安全 | `.gitignore` 中包含 `data/uploaded/`，避免用户数据被误提交 |

---

## 9. 常见反模式（禁止使用）

| 反模式 | 正确做法 |
|---|---|
| `except:` 裸异常 | 使用具体异常类型 |
| `from module import *` | 显式导入需要的符号 |
| 在 `utils/` 中调用 `st.` API | UI 逻辑放在 `pages/` 中 |
| 在 for 循环中逐行操作 DataFrame | 使用向量化操作 |
| 硬编码文件路径 | 使用相对于项目根目录的路径或配置常量 |
| `print()` 调试 | 使用 `logging` 模块 |
| 函数超过 60 行 | 拆分为更小的函数 |
| 在缓存函数内使用 `st.` | 保持缓存函数纯净 |
