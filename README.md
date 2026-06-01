# FundLens — 多平台资产快照分析

面向个人投资者的本地化资产分析工具。导入 Excel 快照，统一统计支付宝/同花顺资产，提供配置监控、基准对比和收益分解。

> **所有数据仅在本地处理，不上传至任何外部服务器。**

## 功能

- **资产总览** — 总资产/总收益/收益率等核心指标 + 6 张图表 + 数据质量提示
- **资产配置** — 多维度环形图 + 目标 vs 当前对比 + 单产品集中度监控
- **收益分析** — 基准对比 + 收益贡献瀑布图 + 盈亏排行
- **产品明细** — 多维度筛选、搜索、排序 + Excel/CSV 导出
- **数据导入** — 上传 Excel 快照，自动清洗和校验
- **三级校验** — 阻断错误 🔴 / 警告提示 🟡 / 自动修复 🟢
- **模糊模式** — 一键隐藏敏感金额，适合截图分享
- **全中文界面** — 侧边栏导航、菜单项、页面标题均已汉化

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/GabageCollection/FundLens.git
cd FundLens

# 创建虚拟环境（推荐）
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 启动应用
streamlit run app.py
```

浏览器打开 `http://localhost:8501`，上传 Excel 快照即可开始使用。

> 如果还没有快照文件，可以在数据导入页面下载标准空白模板。

## 使用流程

1. **导入快照** — 在"数据导入"页面上传 Excel 文件，系统自动清洗和校验
2. **查看看板** — 首页概览呈现总资产、收益、集中度等核心指标
3. **配置分析** — 资产配置页查看多维度分布和目标偏离
4. **收益分析** — 收益分析页查看基准对比和收益分解
5. **产品明细** — 产品明细页筛选、搜索、导出数据
6. **设定基准** — 设置页配置基准指数和目标配置比例

## Excel 快照格式

上传的 Excel 文件需包含 `asset_snapshot` Sheet，关键字段：

| 字段 | 必填 | 说明 |
|------|------|------|
| `statistic_date` | 是 | 统计日期 |
| `platform` | 是 | 平台（支付宝/同花顺/其他） |
| `asset_class` | 是 | 资产大类（现金类/固收类/权益类/跨境类等） |
| `product_type` | 是 | 产品类型（纯债基金/固收+/QDII/宽基 ETF 等） |
| `product_name` | 是 | 产品名称 |
| `current_value` | 是 | 当前金额（唯一强制金额字段） |
| `cost_amount` | 否 | 持有成本（留空则不参与收益率统计） |

系统会自动计算持有收益和收益率，偏差超过 1 元会警告。

## 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | Streamlit 1.58+ |
| 数据处理 | Pandas 2.0+ |
| 可视化 | Plotly 5.15+ |
| Excel 读写 | OpenPyXL 3.1+ |
| 语言 | Python 3.10+ |

## 项目结构

```
FundLens/
├── app.py                  # 主入口（侧边栏、导航、全局状态）
├── requirements.txt        # 依赖声明
├── data/
│   ├── sample/             # 标准空白模板
│   └── uploaded/           # 用户上传的快照
├── utils/                  # 工具模块
│   ├── analyzer.py         # 指标计算与聚合
│   ├── benchmarks.py       # 基准对比
│   ├── charts.py           # Plotly 图表工厂
│   ├── data_cleaner.py     # 数据清洗
│   ├── data_loader.py      # Excel 读取
│   ├── design_tokens.py    # 设计令牌（颜色常量）
│   ├── exporter.py         # Excel/CSV 导出
│   ├── file_manager.py     # 文件管理
│   ├── ui_components.py    # HTML 组件（KPI 卡片等）
│   └── validator.py        # 三级校验
├── pages/                  # Streamlit 多页面
│   ├── 1_🏠_首页概览.py
│   ├── 2_📊_资产配置.py
│   ├── 3_📈_收益分析.py
│   ├── 4_📋_产品明细.py
│   ├── 5_📥_数据导入.py
│   ├── 6_🔍_数据校验.py
│   └── 7_⚙️_设置.py
└── assets/
    └── style.css           # 全局样式
```

## 设计原则

- **以快照为核心** — 记录季度资产状态，不追踪每日流水
- **数据与计算分离** — Excel 只填原始数据，收益由系统自动计算
- **兼容与容错** — 只要有"当前金额"即可参与统计
- **客观呈现** — 提示集中度和偏离，不给出买卖建议

## License

MIT
