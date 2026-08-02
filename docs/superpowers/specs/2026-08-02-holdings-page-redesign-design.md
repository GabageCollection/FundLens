# 全部持仓页改造设计 — 高效数据管理页面

日期：2026-08-02
状态：已获用户批准（设计展示后确认"没有"修改）
分支：feat/holdings-page-redesign

## 1. 背景与目标

当前"全部持仓"页存在三个问题：

1. **表格没有充分利用横向空间**：滚动区列全部写死 px（总和约 760px），1920px 宽度下右侧出现大片空白。
2. **缺失数据表达模糊**：所有空值统一显示"—"，用户无法区分"缺少成本""暂无行情""不适用"等不同含义。
3. **筛选功能不清晰**：顶部仅有搜索框和语义不明确的"组合、交易、平台"列预设分段按钮，无类别/平台/状态筛选，无排序控件。

目标：改造为高效数据管理页面——完整工具栏、12 字段填满宽度的表格、明确的缺失数据文案、行详情抽屉、批量操作、清晰的空状态与计数。

## 2. 范围

**做**：工具栏重组、表格列宽 flex 化与 12 字段、表头排序、缺失数据文案与数据状态派生、行详情抽屉、批量多选操作、空状态与计数、键盘可访问性。

**不做**（用户裁决或既有约束）：

- **交易记录**：CLAUDE.md 规定 V1 不实现交易流水，Holding 模型无交易数据。用户裁决：详情抽屉**省略交易记录区块**。
- **账户字段**：Holding 模型无账户字段。用户裁决：用 `platformTags` 做**组合标签筛选**（无标签持仓归入"未标记"），不做数据库迁移。
- **分页**：保留现有 ListView.builder 虚拟滚动，不加分页器。
- 不引入任何新依赖（file_picker 10.3.7 已在 pubspec 中）。

## 3. 架构选择

**方案 A（已选）：保留双区虚拟表格架构，列宽 flex 化 + 交互扩展。**

现有 `holding_grid.dart` 已是"名称冻结区 + 横向滚动区"双 ListView 结构，滚动同步（reentrancy-guarded）可靠。改造点：

- 冻结区从"名称 260 + 当前金额"改为"复选框 40 + 产品名称（flex，min 200）"；当前金额移入滚动区。
- 滚动区列定义从固定 px 改为 `min-width + flex 权重`：容器宽度超出各列 min 总和时按权重分满（1920 无空白）；不足时整体横向滚动，冻结区保持固定。
- 新增：排序表头、复选框列、数据状态列、行点击/hover/焦点。

否决的备选：B 单行 Row 全列布局（名称列固定无法实现）；C Material DataTable（无虚拟滚动、无固定列）。

## 4. 工具栏

替代 PageScaffold actions 区，自左向右：

1. **搜索框**：宽 260，hint"搜索产品名称或代码"，前缀搜索图标。匹配 productName（包含）与 productCode（小写包含），沿用现有逻辑。
2. **筛选下拉 × 4**：资产类别 / 来源平台 / 数据状态 / 组合标签。MenuAnchor 多选列表（复选）。
   - 按钮文本即选中状态：未选显示标签名（如"资产类别"），已选显示摘要（如"类别：权益"、"平台：支付宝+2"）。
   - 组合标签选项 = 当前持仓中出现过的全部 platformTags 去重 + "未标记"（platformTags 为空的持仓）。
3. **排序下拉**：与表头排序共享同一状态（见 §5.3）。
4. **[添加持仓]**：FilledButton，打开现有 `showHoldingEditorDialog`，保存后 SnackBar"已保存"。

删除 `HoldingColumnPreset` 分段按钮及其在 `HoldingFilterState` 中的字段。

工具栏下方常显"**共 X 项持仓**"（X = 筛选后数量）。

## 5. 表格

### 5.1 列定义（13 列）

| 列 | 区域 | min-width | flex | 对齐 | 可排序 |
|---|---|---|---|---|---|
| 复选框 | 冻结 | 40 | — | 中 | 否 |
| 产品名称 | 冻结 | 200 | 2 | 左 | 是 |
| 资产类别 | 滚动 | 88 | 1 | 左 | 否 |
| 来源平台 | 滚动 | 96 | 1 | 左 | 否 |
| 当前金额 | 滚动 | 120 | 1.2 | 右 | 是 |
| 资产占比 | 滚动 | 96 | 1 | 右 | 是 |
| 份额 | 滚动 | 110 | 1 | 右 | 是 |
| 现价 | 滚动 | 100 | 1 | 右 | 是 |
| 覆盖成本 | 滚动 | 120 | 1.2 | 右 | 是 |
| 持仓盈亏 | 滚动 | 120 | 1.2 | 右 | 是 |
| 持仓收益率 | 滚动 | 110 | 1 | 右 | 是 |
| 估值日期 | 滚动 | 104 | 1 | 左 | 是 |
| 数据状态 | 滚动 | 96 | 1 | 左 | 否 |

- 数字列右对齐、tabular-nums、千分位（复用 `HoldingValueFormatter`）。
- 资产占比 = holding.currentValue ÷ 组合总资产（由 provider 基于可见全集计算，不是筛选后子集；分母与总览页口径一致：全部持仓总金额）。占比显示为 `12.34%`。
- 持仓盈亏/收益率：红盈利绿亏损 + 显式 +/- 符号（既有约定）。

### 5.2 列宽分配

冻结区宽 = 40 + max(200, 名称列分配宽)。滚动区各列实际宽 = min + 剩余空间 × (flex ÷ Σflex)，剩余空间 = 容器宽 − 冻结区宽 − Σmin；剩余空间 ≤ 0 时各列取 min，整体横向滚动。

### 5.3 排序

- 状态：`HoldingSort = (SortField field, bool ascending)`；SortField ∈ {name, currentValue, share, quantity, currentPrice, cost, profit, returnRate, valuationDate}。
- 表头点击：默认 → 降序（名称为升序）→ 反向 → 默认，三态循环；箭头指示当前方向。
- 排序时空值恒排末尾（无论升降序）。
- 工具栏排序下拉列出全部 9 个字段 × 方向（如"当前金额 · 从高到低"），与表头共享状态。
- 默认排序：当前金额降序。

### 5.4 表头与行

- 表头固定（不随垂直滚动），高 48。
- 行高 56（`FundLensTokens.rowHeight`，落在 52–56 要求内）。
- 行 hover 显示 canvas 底色；点击打开详情抽屉；复选框点击不触发行点击（不冒泡）。
- 行可聚焦：焦点 2px 主色轮廓，Enter 打开抽屉，复选框 Space 切换。

## 6. 缺失数据文案与数据状态派生

### 6.1 单元格缺失文案

| 字段 | 条件 | 文案 |
|---|---|---|
| 份额 | valuationMethod == manualAmount | 不适用 |
| 份额 | 行情类（automaticQuote/quantityTimesPrice）且 quantity == null | 暂无行情 |
| 现价 | valuationMethod == manualAmount | 不适用 |
| 现价 | 行情类且 currentPrice == null | 暂无行情 |
| 覆盖成本 | costAmount == null | 缺少成本 |
| 持仓盈亏 | effectiveCostAmount == null | 缺少成本 |
| 持仓收益率 | effectiveCostAmount == null | 缺少成本 |
| 估值日期 | 行情类且 valuationDate == null | 暂无行情 |
| 估值日期 | manualAmount 且 valuationDate == null | 不适用 |
| 备注（抽屉内） | note == null | 未填写 |

不再出现统一"—"（导出 CSV 空字段沿用空串，不受影响）。

### 6.2 数据状态派生（纯函数）

`deriveHoldingDataStatus(Holding, {required Set<String> freshQuoteHoldingIds}) → HoldingDataStatus`，优先级从上到下：

1. **未填写**：用户提供的必填字段缺失——名称空 / 币种空 / 金额为负 / automaticQuote 缺产品代码或份额 / quantityTimesPrice 缺份额。
2. **暂无行情**：行情类（automaticQuote/quantityTimesPrice）且 currentPrice == null 或 valuationDate == null（价格与日期是行情侧数据，缺失归入行情问题而非"未填写"，保证两态各自可达）。
3. **等待更新**：automaticQuote 且 id ∉ freshQuoteHoldingIds。
4. **缺少成本**：effectiveCostAmount == null。
5. **正常**。

数据状态筛选器选项 = 上述 5 态多选。显示为 muted 色文字标签，不使用高饱和色块；盈亏红绿仅用于盈亏数值本身。

## 7. 详情抽屉

右侧滑出，宽 400，高度撑满，Esc 或点击遮罩关闭。分节：

1. **基本信息**：产品名称、产品代码、产品形态、资产类别、币种、备注。
2. **来源平台**：来源平台、数据出处、估值方式、组合标签。
3. **当前金额**：当前金额、资产占比。
4. **成本与收益**：覆盖成本、持仓盈亏、持仓收益率、当日盈亏、累计盈亏（累计只展示，标注"不纳入当前盈亏汇总"）。
5. **数据来源**：字段来源摘要（原始/推断/行情/人工修正，按 fieldProvenance 汇总为有来源标注的字段计数）。
6. **最后更新**：updatedAt（精确到分钟）、估值日期。

底部操作条：[编辑] [刷新行情] [删除]。

- 编辑：打开 `showHoldingEditorDialog(initial: holding)`；保存成功 → SnackBar"已保存"，watchAll 流自动更新该行与抽屉内容，不重置筛选/排序/滚动位置。
- 刷新行情：`holdingSupportsQuoteRefresh` 为 false 时禁用（Tooltip 说明"该资产类型不支持行情刷新"）；成功后 SnackBar 汇报结果。
- 删除：`showHoldingDeleteConfirmation` 二次确认（对话框明示产品名），确认后 `deleteByIds` 并关闭抽屉，SnackBar"已删除"。

## 8. 批量操作

- 复选框列：表头复选框全选/取消全选（部分选中时显示半选态）。
- 选中 ≥1 行时，表格上方浮现批量条：**已选 X 项 | [修改资产类别] [修改来源平台] [刷新行情] [导出] [删除] [取消选择]**。
- **修改资产类别 / 修改来源平台**：小对话框单选目标值 → `inTransaction` 内逐条 upsert（仅改目标字段 + provenance 标记 userCorrected + updatedAt）。完成后 SnackBar"已更新 X 项持仓"。
- **刷新行情**：`quoteRefreshService.refresh(选中项中可刷新的)`；SnackBar 汇报"更新 X / 保留 Y / 失败 Z"。服务未接线时禁用。
- **导出**：file_picker 保存对话框（默认文件名 `holdings-YYYYMMDD.csv`）→ 复用 `HoldingExportService.exportCsv(选中行, path)`。SnackBar"已导出到 <文件名>"。
- **删除**：确认对话框"确定删除选中的 X 项持仓吗？此操作不可撤销。"→ `deleteByIds`，SnackBar"已删除 X 项持仓"。
- 筛选/搜索变化不自动清空选择（用户可能连续操作）；删除/取消选择后清空。

## 9. 空状态

- **全库无持仓**（无任何筛选时）：居中"还没有持仓" + 说明 + [导入资产]（Actions 跳 importReview）+ [手动添加]（编辑器对话框）。
- **筛选/搜索无结果**：居中"没有符合条件的持仓" + [清除筛选]（重置 query/4 类筛选，保留排序）。

## 10. 键盘与可访问性

- 焦点顺序：搜索框 → 4 筛选下拉 → 排序下拉 → 添加持仓 → 表头各可排序列 → 表头复选框 → 逐行（复选框 → 行体）。
- 表头排序：Enter/Space 触发；行：Enter 开抽屉；复选框：Space；抽屉：Esc 关闭；批量条按钮均可 Tab 到达。
- 全部可点区域 ≥ 40×40；筛选按钮高 40；说明文字 ≥ 12px。

## 11. 文件结构

| 文件 | 动作 | 职责 |
|---|---|---|
| `features/holdings/holding_status.dart` | 新增 | `HoldingDataStatus` 枚举、`deriveHoldingDataStatus`、单元格缺失文案映射（纯函数） |
| `features/holdings/holding_filters.dart` | 重构 | 筛选状态（query/sources/assetClasses/statuses/tags/sort）；删 HoldingColumnPreset；visibleHoldingsProvider 组合过滤与排序 |
| `features/holdings/holding_toolbar.dart` | 新增 | 搜索框、4 筛选下拉、排序下拉、添加按钮、计数 |
| `features/holdings/holding_grid.dart` | 重构 | 13 列 flex 列宽、排序表头、复选框、行交互、虚拟滚动（保留双区同步） |
| `features/holdings/holding_detail_drawer.dart` | 新增 | 右侧抽屉 6 分节 + 3 操作 |
| `features/holdings/holding_batch_bar.dart` | 新增 | 批量条与 5 个批量动作 |
| `features/holdings/holdings_page.dart` | 重构 | 组装工具栏/批量条/表格/空状态/抽屉 |
| `features/holdings/holding_export_service.dart` | 复用 | 不改动 |
| `features/holdings/holding_editor_dialog.dart` | 复用 | 不改动 |

## 12. 测试策略

- **纯函数**：deriveHoldingDataStatus 全优先级路径（含并列条件取高优先级）；缺失文案映射全字段；筛选组合（query × 类别 × 平台 × 状态 × 标签 × 排序字段×方向）；占比计算（总资产为 0 时显示"不适用"）。
- **Widget**：工具栏选中摘要文本；表头点击三态循环；行点击开抽屉；抽屉三分操作（编辑 Toast/刷新禁用/删除二次确认）；批量条出现与各动作；空状态两入口；无结果清除筛选；1280/1440/1920 宽度无溢出（OverflowError 断言）；键盘遍历焦点顺序。
- **禁词测试**：页面文案不得含 建议/应当/调仓/再平衡/买入/卖出（find.textContaining findsNothing），与总览/分析页一致。
- **门禁**：`flutter test apps/fundlens_windows`、`flutter analyze`、`dart test packages/fundlens_core`。

## 13. 验收标准

1. 1920px 宽度下表格列分满容器，无右侧大片空白；1280px 下横向滚动且名称列固定。
2. 筛选、搜索、排序可任意组合使用，状态互通。
3. 缺失数据五种文案（缺少成本/暂无行情/不适用/等待更新/未填写）各按其条件出现，无统一"—"。
4. 键盘可访问搜索框、筛选器、表头排序和行操作。
5. 编辑后单行更新 + Toast，不整页刷新；删除必须二次确认。
6. 无持仓/无结果空状态分别有明确入口；常显"共 X 项持仓"。

## 14. 全局约束（引用 CLAUDE.md，不再展开）

Decimal 金额；间距仅 4/8/12/16/24/32/40/48；颜色取 FundLensTokens；红盈利绿亏损带符号；卡片圆角 12、1px 边框、无阴影；点击区 ≥40×40；说明文字 ≥12px；中文注释与文案；无新依赖；历史快照不可变（本页不触碰快照）；累计收益只展示。
