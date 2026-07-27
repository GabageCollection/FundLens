# OCR 表格解析重构设计：表头锚定 + 列归属

日期：2026-07-28
状态：已获用户批准
范围：`engine/src/fundlens_engine/ocr/`（`layout.py`、`alipay_parser.py`、`ths_parser.py`）及对应测试

## 背景与痛点

用户用两张真实截图实测当前识别（支付宝「全部持有」基金列表、同花顺「中国银河证券-持仓」ETF 列表），痛点为：具体字段错误、字段错位/串行、噪声行混入结果。

根因：现有 parser 按"逐行 + 行内 token 顺序"解析，与真实版式结构性不匹配：

- **支付宝**：「持有收益」「累计收益」是表头列标题而非行内标签，数据行只有纯数字；现有逻辑丢掉两个收益字段，且「占比 34.68%」行被误判为标签行。
- **同花顺**：真实版式为两行一个持仓（第一行：名称/盈亏/持仓/成本；第二行：市值/盈亏%/可用/现价），表头为「市值/盈亏/持仓/可用/成本/现价」，与现有假设（一行一持仓、表头"名称/市值"）不符；每个持仓下方内嵌分时图，产生大量噪声 token（"最新：2.223 -1.419% 额：1.90亿 换：1.90%"、坐标轴价格与百分比、09:30/11:30/15:00 时间戳）。

## 方案

表头锚定 + 列归属：先定位表头行，用表头各列标题的 x 坐标把页面切成列区间；所有数据 token 按 x 中心归入对应列；再按行重组为持仓记录。字段归属由列坐标决定，与行内 token 顺序无关，从根上解决串行。

已排除的备选：方案 B（现有逐行逻辑打补丁，治标不治本）、方案 C（无锚点通用 x 聚类，列语义不稳定、过度工程）。

## 已确认的决策

1. 同花顺正收益不带 + 号（如 盈亏 40.70、0.602%）：**无符号视为正数**，附 warning `ocr.sign_assumed_positive`，由人工确认环节把关。支付宝维持无符号即 blocking。
2. 支付宝「日收益」列和「占比」行**忽略**：FundLens 用快照差额描述资产变化，占比由 FundLens 统一重算。
3. Dart 侧字段名与契约不变。

## 第 1 节：共享 layout 层与数据结构

### `layout.py` 扩展

```python
@dataclass
class ColumnLayout:
    """表头锚定的列区间。每列有语义名和 x 区间 [left, right)。"""
    columns: list[tuple[str, int, int]]  # (语义名, 左界, 右界)

    def column_of(self, token: OcrToken) -> str | None:
        """按 token 中心 x 返回所属列名；落不进任何列返回 None。"""
```

- `anchor_columns(lines, header_texts) -> ColumnLayout | None`：在 lines 中找表头行（含指定锚点词），用各锚点 token 的 x 中心为列中心，相邻列中心的中点为列边界；首列左界为 0，末列右界为页面宽。找不到表头返回 None，parser 报 blocking，不猜测。
- 名称列为首列：x 从 0 到第二列左界，名称和标签 token 都落这里。

### 噪声过滤增强（`is_noise`）

- 时间戳：`^\d{1,2}:\d{2}$`（09:30、11:30、15:00）
- 行情摘要：`最新:`/`最新：` 开头，或含 `额:` `换:` 的模式
- "行情"、"行情>"、排序/筛选控件词（"金额/占比排序"、"全部"）
- 表头词不是噪声——它是锚点；表头行匹配后该行 token 不再进入数据流。

### 数据结构（不变）

仍输出 `DraftRow` + `OcrField`，字段名沿用现有约定：

- 支付宝：`product_name / current_value / holding_profit / cumulative_profit / platform_tags`
- 同花顺：`product_name / current_value / holding_profit / profit_ratio / cost_price / quantity`，新增 `latest_price`（现价，可选字段不阻塞）

## 第 2 节：支付宝 parser（状态机重写）

锚点词：`{"名称/金额"（或"名称"）, "日收益", "持有收益", "累计收益"}`。找不到表头 → 空结果 + 页级 blocking `ocr.layout_unknown`。

行序列状态机（每个持仓固定四行结构）：

```
ExpectName ──文本行(无money)──> 记 product_name → ExpectTags
ExpectTags ──文本行(无money)──> 记 platform_tags → ExpectNumbers
           ──数值行(直接出现)──> 跳过标签 → ExpectNumbers（标签可缺）
ExpectNumbers ──含money的行──> 按列拆分：
              · 首列 → current_value（取该列第一个 money token）
              · "持有收益"列 → holding_profit
              · "累计收益"列 → cumulative_profit
              · "日收益"列 → 丢弃
              → ExpectRatio
ExpectRatio ──含"占比"前缀的行──> 整行忽略 → ExpectName（下一个持仓）
           ──文本行──> 直接 ExpectName（占比行可缺）
```

规则：

- 字段归属只看列区间，不看行内顺序；OCR 粘字/换序不影响归属。
- 名称行整行文本归 product_name（含 "(QDII)C" 等尾随字符）。
- 数值行里落不进任何收益列的多余 money token → 忽略 + warning `ocr.extra_token`，不串位。
- 标签行原样拼接进 `platform_tags`，仅展示参考。

校验：必需字段 `product_name / current_value`；`holding_profit / cumulative_profit` 无显式 +/− → blocking `ocr.sign_missing`（不变）；置信度阈值不变（名称 0.85 / 金额 0.90 / 标签 0.70）。

## 第 3 节：同花顺 parser（两行合并 + 图表区过滤）

锚点词：`{"市值", "盈亏", "持仓/可用"（或"持仓"）, "成本/现价"（或"成本"）}`。找不到 → blocking `ocr.layout_unknown`。

### 第一步：图表区剔除（行分组之前）

- 锚点：含 `最新:` 的 token（每个图表顶部必有"最新：2.223 -1.419% 额：1.90亿 换：1.90%"行）。
- 区间：从锚点行顶开始，到下一个持仓名称行或下一个数据行为止；区间内所有 token 全部丢弃。
- 列表底部图表可能被截断——区间截到页面底，规则一致。
- 时间戳/`最新:`/"行情" 同时进 `is_noise` 双保险。

### 第二步：两行合并状态机

```
ExpectLine1 ──含名称token的行──> 按列拆分：
   · 名称列(首列)      → product_name
   · "盈亏"列         → holding_profit（如 -474.80）
   · "持仓/可用"列    → quantity（第一行=持仓，如 5800）
   · "成本/现价"列    → cost_price（第一行=成本，如 2.305）
   → ExpectLine2
ExpectLine2 ──下一行──> 按列拆分：
   · 名称列(首列)      → current_value（市值，如 12,893.40）
   · "盈亏"列         → profit_ratio（如 -3.552%）
   · "成本/现价"列    → latest_price（现价，如 2.223）
   · "持仓/可用"列    → 可用数量，丢弃
   → 完成 DraftRow → ExpectLine1
```

- 两行靠行序区分，不靠内容——避免 "HS300ETF" 这类含数字名称的歧义。
- ExpectLine2 遇到新名称行（第二行缺失）→ 当前 row 记 blocking `ocr.field_missing`，退回 ExpectLine1 处理新行，不丢持仓、不连锁失败。

### 第三步：符号规则

- `holding_profit`、`profit_ratio` 带显式 +/− → 正常。
- 无符号 → 视为正数，字段保留原值 + warning `ocr.sign_assumed_positive`。
- 仅同花顺放宽 `sign_missing` blocking；支付宝维持 blocking。

校验：必需 `product_name / current_value / holding_profit / cost_price / quantity`；`profit_ratio`、`latest_price` 可选（warning 级）。置信度阈值沿用现有（名称 0.85 / 金额 0.90 / 比率 0.70）。

## 第 4 节：错误处理与测试策略

错误全部通过 `DraftRow.issues` 表达，parser 不抛异常（契约不变）：

| 场景 | 行为 |
|---|---|
| 找不到表头锚点 | 空 rows + 页级 blocking `ocr.layout_unknown` |
| 必需字段缺失 | blocking `ocr.field_missing`（不变） |
| 支付宝收益无符号 | blocking `ocr.sign_missing`（不变） |
| 同花顺盈亏无符号 | 视为正数 + warning `ocr.sign_assumed_positive`（新） |
| 置信度低于阈值 | blocking/warning `ocr.low_confidence`（阈值不变） |
| 行内多余 money token | 忽略 + warning `ocr.extra_token` |
| 同花顺第二行缺失 | 该行 blocking，后续正常解析 |

测试（真实截图不进仓库，只用脱敏合成 token 流）：

1. 合成 token fixture 按两张截图真实版式手写 `OcrToken` 流（坐标按截图实际比例构造）：
   - 支付宝：完整 6 持仓（正负收益、四行齐全、缺标签行、缺占比行）、表头缺失、低置信度。
   - 同花顺：3 持仓（无符号正收益、截断图表、含数字名称 "HS300ETF"、短名称 "纳指"）、图表噪声全部剔除验证、第二行缺失。
   - 错位回归：行内 token 顺序打乱但列坐标正确，验证字段归属不受顺序影响。
2. `anchor_columns` 单测：表头缺锚点词、锚点 x 乱序。
3. `is_noise` 单测：时间戳、`最新:` 行、"行情"、状态栏。
4. 门禁：`python -m pytest engine/tests -q`、`python -m ruff check engine`、`python -m mypy engine/src` 全绿；Flutter 冒烟测试照常。

## 不做的事（YAGNI）

- 不识别日收益/占比/可用数量
- 不做通用券商/平台适配
- 不引入颜色判断（符号只来自显式字符或列语义+人工确认）
- 不改动 Dart 侧字段契约
