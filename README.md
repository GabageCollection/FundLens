# FundLens — 多平台资产快照分析

> 面向个人投资者的本地化资产分析工具。导入 Excel 快照，统一统计支付宝/同花顺资产，提供配置监控、基准对比和收益分解——所有数据仅在本地处理。

[![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)
[![Streamlit](https://img.shields.io/badge/Streamlit-1.58+-red.svg)](https://streamlit.io/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## 项目介绍

FundLens 帮助个人投资者以「资产快照」的方式定期审视资产全貌。用户将支付宝基金/理财、同花顺 ETF 等平台的资产数据填入 Excel 模板，系统自动完成清洗、校验、收益计算，并生成多维度分析看板。

**核心思路：** 不定期追踪每日流水，而是按季度记录资产快照，关注配置偏离和收益趋势。

### 适用场景

- 同时持有支付宝、同花顺等多个平台资产，需要一个统一视图
- 设定了资产配置目标（如权益类 60%），想监控实际偏离
- 需要对比自己的投资组合与基准指数（如沪深 300）的表现
- 定期审视资产状况，但不希望数据离开本地

### 功能边界

| 做 | 不做 |
|----|------|
| Excel 导入与数据清洗 | 自动登录投资平台 |
| 资产配置统计与可视化 | 自动同步行情数据 |
| 收益分析与基准对比 | 自动交易/调仓 |
| 产品明细筛选与导出 | 买卖建议 |
| 模糊模式（金额脱敏） | 多用户系统 / 云端部署 |

---

## 功能特性

### 📊 首页资产总览
10 个 KPI 卡片（总资产、总收益、收益率、覆盖率、产品/平台数量、最大单品占比、权益类占比、基准对比、目标偏离）+ 6 张图表 + 数据质量提示卡片

### 📈 资产配置分析
- 6 个维度的环形图：平台 / 资产大类 / 产品类型 / 市场区域 / 资金用途 / 风险等级
- 当前 vs 目标配置对比（Bullet 图 + 偏离详情表）
- 单产品集中度监控（占比 > 20% 橙色预警）
- 平台 × 大类交叉分析、年化费用估算

### 💰 收益分析
- 收益摘要条 + 基准对比图
- 收益贡献度瀑布图（按资产大类分解）
- 平台 & 资产大类收益分组对比
- 产品盈利/亏损 Top 10 + 收益率 Top/Bottom 10

### 📋 产品明细
- 6 维度筛选器：平台 / 资产大类 / 产品类型 / 市场区域 / 资金用途 / 收益状态
- 产品名称/代码模糊搜索
- 表格格式化展示（金额、收益、收益率着色）
- 一键导出 Excel / CSV

### 📥 数据导入 & 校验
- 三步导入流程：上传 → 预览 → 确认
- 自动清洗：金额逗号、百分号转换、收益自动计算
- 三级分层校验：阻断错误 🔴 / 警告提示 🟡 / 自动修复 🟢

### ⚙️ 设置
- 基准指数配置（起始值 / 结束值 / 名称）
- 目标配置比例设定（按资产大类，支持滑块 + 数值输入）
- 模糊模式开关
- 数据管理（清除快照缓存）

---

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| Web 框架 | Streamlit 1.58+ | 纯 Python 交互式 Web 应用 |
| 数据处理 | Pandas 2.0+ | DataFrame 操作、分组聚合 |
| 可视化 | Plotly 5.15+ | 交互式图表（环形图、柱状图、瀑布图、子弹图） |
| Excel | OpenPyXL 3.1+ | 读写 .xlsx 文件 |
| 语言 | Python 3.10+ | 类型注解、f-string、pathlib |

无外部数据库，无云端依赖，无浏览器插件。

---

## 项目结构

```
FundLens/
├── app.py                         # 主入口：侧边栏、导航、全局 session state
├── requirements.txt               # Python 依赖声明
├── README.md                      # 项目文档
├── .gitignore
├── .streamlit/
│   └── config.toml                # Streamlit 主题与服务器配置
├── data/
│   ├── sample/                    # Excel 标准空白模板
│   └── uploaded/                  # 用户上传的快照自动保存在此（已 gitignore）
├── assets/
│   └── style.css                  # 全局自定义样式（CSS 变量、组件类）
├── utils/                         # 工具模块（不依赖 st.* API）
│   ├── analyzer.py                # 14 个指标计算函数（总资产、收益、覆盖率等）
│   ├── benchmarks.py              # 基准配置读写 + 基准收益 / 相对收益计算
│   ├── charts.py                  # Plotly 图表工厂（7 种图表 + 主题 + 空数据降级）
│   ├── constants.py               # Session state key 常量
│   ├── data_cleaner.py            # 数据清洗：格式转换、收益自动计算
│   ├── data_loader.py             # Excel 读取与字段映射
│   ├── design_tokens.py           # 设计令牌（颜色常量，与 CSS 变量镜像）
│   ├── exporter.py                # Excel / CSV 导出
│   ├── file_manager.py            # 文件扫描、保存、加载
│   ├── template_generator.py      # Excel 标准模板生成
│   ├── ui_components.py           # 可复用 HTML 组件（KPI 卡片、徽章、步骤条等）
│   └── validator.py               # 三级校验规则引擎
├── pages/                         # Streamlit 功能页面
│   ├── 1_🏠_首页概览.py
│   ├── 2_📊_资产配置.py
│   ├── 3_📈_收益分析.py
│   ├── 4_📋_产品明细.py
│   ├── 5_📥_数据导入.py
│   ├── 6_🔍_数据校验.py
│   └── 7_⚙️_设置.py
├── tests/
│   ├── fixtures/
│   │   └── sample_2026Q1.py       # 示例数据 fixture
│   └── run_phase1_tests.py        # Playwright E2E 测试入口
└── docs/
    └── superpowers/
        └── plans/                 # 开发计划文档
```

---

## 安装与运行

### 前置要求

- Python 3.10 或更高版本
- pip（随 Python 安装）
- Git（可选，用于克隆仓库）

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/GabageCollection/FundLens.git
cd FundLens

# 2. 创建虚拟环境（推荐）
python -m venv .venv

# 3. 激活虚拟环境
# Windows:
.venv\Scripts\activate
# macOS / Linux:
source .venv/bin/activate

# 4. 安装依赖
pip install -r requirements.txt

# 5. 启动应用
streamlit run app.py
```

浏览器打开 `http://localhost:8501` 即可使用。

### 首次使用

如果还没有快照文件，有两种方式获取模板：

1. **在应用中下载：** 进入「数据导入」页面 → 点击「下载标准模板」
2. **直接使用仓库文件：** `data/sample/FundLens_Asset_Snapshot_Template.xlsx`

按模板填写资产数据后，回到数据导入页面上传即可。

---

## 环境变量配置

本项目无需额外环境变量配置，所有设置通过 Streamlit 的 `.streamlit/config.toml` 文件和应用内的「设置」页面完成。

`.streamlit/config.toml` 中的可配置项：

```toml
[theme]
base = "light"
primaryColor = "#c96442"        # 主题色（陶土色）
backgroundColor = "#f5f4ed"     # 页面背景
secondaryBackgroundColor = "#faf9f5"  # 卡片背景
textColor = "#141413"           # 主文字色

[server]
maxUploadSize = 200              # 上传文件大小上限（MB）
```

本地开发时，如需修改 Streamlit 端口或开启热重载之外的调试选项，可直接编辑该文件。更多配置项见 [Streamlit 官方文档](https://docs.streamlit.io/library/advanced-features/configuration)。

---

## 常见问题

### Q: 上传 Excel 后提示"未找到 asset_snapshot Sheet"

Excel 文件中 Sheet 名称必须为 `asset_snapshot`（区分大小写）。请检查 Sheet 名称是否正确，或下载标准模板重新填写。

### Q: 收益率显示为空或不准确

系统使用**简单持有期收益率** = 持有收益 / 持有成本。如果产品的 `cost_amount`（持有成本）字段为空或为 0，该产品不参与收益率统计。请在 Excel 中补填成本数据。

### Q: 切换快照后页面数据没有更新

数据更新是即时的。如果页面内容没有变化，请检查侧边栏是否正确选择了快照。如果问题持续，可以刷新浏览器页面（F5）。

### Q: 数据隐私是否安全？

**所有数据仅在本地处理，不会上传至任何外部服务器。** 用户上传的 Excel 文件保存在本地 `data/uploaded/` 目录（该目录已在 `.gitignore` 中排除）。Streamlit 默认监听 `localhost`，外部设备无法访问。

### Q: 可以在手机上使用吗？

FundLens 为桌面端设计，未做移动端适配。在局域网内可通过 `--server.address 0.0.0.0` 让其他设备访问，但 UI 体验不做保证。

### Q: 支持哪些平台的数据？

目前字段设计兼容支付宝、同花顺等主流平台。只要 Excel 中包含要求的字段（`platform`、`asset_class`、`current_value` 等），任意平台的资产数据均可导入。平台字段可填"支付宝""同花顺""其他"或自定义名称。

---

## 后续开发计划

以下方向基于项目设计文档和竞品分析报告提炼，欢迎贡献：

- [ ] **时间加权收益率（TWR）** — 当前使用简单收益率，后续支持考虑资金投入时间的 TWR/IRR
- [ ] **多快照时间序列对比** — 加载多个季度快照，绘制资产/收益变化趋势图
- [ ] **费用深度分析** — 管理费、托管费、申购费的综合统计与对比
- [ ] **自定义阈值告警** — 用户可设定最大单品占比、最大回撤等个性化告警阈值
- [ ] **PDF 报告导出** — 一键生成季度资产分析报告
- [ ] **单元测试覆盖** — 为 utils/ 模块补充完整的 pytest 用例
- [ ] **Docker 部署支持** — 提供 Dockerfile，便于在 NAS 或服务器上运行
- [ ] **多语言支持** — 当前仅支持中文，可扩展英文界面

> 功能性改进建议请先开 Issue 讨论，避免重复工作。

---

## 贡献指南

欢迎提交 Issue 和 Pull Request！

### 提交 Issue

- 使用清晰的标题描述问题
- 附上复现步骤、预期行为和实际行为
- 如果是数据相关问题，请提供脱敏后的示例数据

### 提交 Pull Request

1. Fork 本仓库
2. 创建特性分支：`git checkout -b feature/your-feature`
3. 遵循项目的[编码规范](coding.md)（Python 类型注解、PEP 8、双引号）
4. 确保 `utils/` 模块不依赖 `st.*` API
5. 提交前运行 `python -m py_compile` 检查语法
6. 提交 PR 时说明改动内容与动机

### 本地开发

```bash
pip install -r requirements.txt
streamlit run app.py

# 运行 E2E 测试（需先启动 streamlit 服务）
pip install pytest-playwright
playwright install chromium
py tests/run_phase1_tests.py
```

---

## License

MIT License — 详见 [LICENSE](LICENSE) 文件。

> 注意：仓库根目录暂未包含独立的 LICENSE 文件，上述声明以 README 中的 MIT 标识为准。如需在法律上明确许可证条款，建议后续添加正式的 LICENSE 文件。
