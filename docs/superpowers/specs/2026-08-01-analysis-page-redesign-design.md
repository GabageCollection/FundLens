# 资产分析页重构 — 设计文档

日期:2026-08-01
状态:已获用户确认(2026-08-01)

## 1. 背景与问题

当前"资产分析"页主体为 7/5 双栏栅格:左侧构成表(名称/金额/占比 + 4px 细条),右侧静态指标清单(最大单项持仓、最大资产类别、现金及存款占比、权益敞口占比、数据完整度、收益覆盖度、行情新鲜度)。存在三个问题:

1. **下半部分大面积留白**:构成表行数少、指标清单固定几行,卡片下方出现超过主体高度一半的空白;
2. **只有静态文字**:右侧清单一堆事实数字,没有结论、状态和可执行入口,缺乏决策价值;
3. **无数据质量前置判断**:当全部资产被归入"其他"时,页面会输出"最大资产类别:其他 100%"这种误导性结果,而非数据问题提示。

## 2. 目标(验收标准)

- 页面中不再出现超过主体高度一半的空白卡片;
- 所有百分比都能追溯到金额(或字段计数);
- 分类不足时优先提示数据问题,不输出误导性结论;
- 三个分析维度(资产类别/产品类型/来源平台)切换正常;
- 维度切换为可访问 Tabs:当前项状态清晰、支持键盘左右切换、切换时页面布局稳定、数据不足时显示原因;
- 图表同时显示金额和占比;类别少于等于 6 项时显示全部,过多时展示前 5 项并合并"其他";颜色基于品牌色同色系深浅,不使用随机彩虹色;具有空状态、Tooltip 和可读的坐标标签。

## 3. 方案选型

**采用方案 A:CustomPaint 自绘图表(沿用项目既有模式)。**

- 方案 B(引入 fl_chart 等第三方图表库):违反 CLAUDE.md"依赖版本在阶段 1 固定,后续阶段未经评审不得升级"的约束;第三方默认样式与暖墨体系差距大,需要大量硬覆盖。排除。
- 方案 C(纯 Widget 堆叠模拟条形):无法提供坐标轴、网格线、刻度标签,达不到"可读的坐标标签"要求。排除。

项目已有自绘先例:总览页 `asset_spectrum.dart`(分段条 + 键盘导航)、`trend_chart.dart`(折线图 + 刻度网格 + 图例),分析页图表沿用同一套 CustomPaint 模式。

## 4. 页面结构(8 + 4 栅格)

```
┌─ 资产构成(左 8 列)────────────────┐ ┌─ 分析结论(右 4 列)──────────────┐
│ 标题行                             │ │ 资产结构   已分类率 正常/需要处理  │
│ [Tabs] 资产类别 产品类型 来源平台    │ │ 集中度     最大单项  范围内/超出   │
│ ────────────────────────────────── │ │ 数据质量   完整度    正常/需要处理  │
│ 图表区(固定高度,含底部刻度带)        │ │ 收益覆盖   覆盖度    正常/提示     │
│ 横向条形图 / 堆叠比例条              │ │ 行情新鲜度 新鲜度    —/提示       │
│ 空状态/数据不足原因                 │ └────────────────────────────────┘
└───────────────────────────────────┘
```

- 沿用 `PageScaffold`(standard 档)与 `GridRow`(12 列,<960 堆叠);
- 左卡 8 列:图表标题 + 可访问 Tabs + 固定高度图表区;切换维度只更换图表内容(AnimatedSwitcher 淡切),卡片高度不变,布局稳定;
- 右卡 4 列:分析结论卡,5 项结论行,高度与左卡基本齐平,消除下半部分留白;
- 页面级状态(与总览页一致):空持仓 → 整页空状态卡 + 入口;加载中 → spinner;降级 → 错误文本;
- 页头 actions 不再放 SegmentedButton(维度选择移入图表卡)。

## 5. 可访问 Tabs

- Material `TabBar` + `TabController`,三项等宽(资产类别/产品类型/来源平台),内置于图表卡头部;
- 键盘左右方向键切换(Material TabBar 原生支持);Focus 为 2px 主色轮廓;选中项主色下划线指示器 + 深色文字 + Semantics selected;
- 切换仅重建图表内容,`AnimatedSwitcher` 淡切;图表区高度固定,无布局跳动。

## 6. 图表设计

### 6.1 行数据模型与纯函数

```dart
final class ChartBarRow {
  final String label;          // 展示名(资产类别/产品类型/来源平台标签)
  final DecimalValue amount;   // 该分组当前金额
  final DecimalValue share;    // 占总资产比例 0..1
  final bool isAggregate;      // 是否"其他"合并段
}
```

`buildChartRows(PortfolioSummary summary, AnalysisDimension dimension) → List<ChartBarRow>`:

- 从 `byAssetClass` / `byInstrumentType` / `bySource` 取金额;
- 金额降序;
- **≤6 项全部显示;>6 项取前 5 + 其余合并为"其他"聚合行**(金额与占比求和,复用 `asset_spectrum.dart` 的合并语义,聚合行标记 `isAggregate`)。

### 6.2 三种形态

| 维度 | 形态 | 说明 |
|---|---|---|
| 资产类别 | 横向条形图 | 每行:名称(左) + 条形 + 条端金额 + 行尾占比 |
| 产品类型 | 横向条形图 | 同上;9 种类型通常触发前 5 + 其他合并 |
| 来源平台 | 横向比例条 | 单条 100% 宽堆叠条 + 下方图例行(色点 + 平台名 + 金额 + 占比) |

### 6.3 标记规范(遵循 dataviz 技能)

- 条形自 **0 基线**增长(金额刻度,可等比);14px 高,**4px 圆角数据端、基线端为直角**;
- 堆叠比例条段间 **2px surface 间隔**;段与段不用描边分隔;
- 网格线与坐标轴:1px 实线、浅色(border 色)、弱化;底部刻度 ≥1 万显示 `12.3万` 紧凑格式;
- 行槽在固定高度图表区内均匀分布(每槽 ≥40px 点击热区);
- 金额与占比直接标注在行内(条形颜色之外必有文字),Tooltip 只是增强,不是唯一读取途径;
- 悬停/聚焦 Tooltip 与 Semantics label:「权益 金额 ¥30,000.00 占比 38.0%」;
- 文本一律使用文字 token(ink / muted / financialNumber),条形颜色不用于文字。

### 6.4 配色(品牌陶土同系,经校验器验证)

- 条形统一主色 `#B65233`(accent);聚合"其他"行用暖灰 `#736E64`(muted)——dataviz 校验器确认:纯陶土 5-6 档深浅的浅档读作灰色且对比不足,不可行;单色条 + 少量辅助色 + 文字二次编码为通过方案;
- 来源平台堆叠条 3 档:accent `#B65233` / 中调 `#D3896D` / 暖灰 `#736E64`,段间 2px surface 间隔 + 图例文字承载身份;
- 深浅色值以 `fundlens_tokens.dart` 新增 `chartBarShades` 常量为唯一准绳,组件不得硬编码;
- 不使用随机彩虹色;状态色(profit/loss/warn)仅用于结论卡状态标签,不用于数据系列。

### 6.5 空状态与数据不足

- 无持仓:整页空状态卡 + "添加资产"入口;
- 总资产为 0:图表区显示原因文本;
- 维度数据不足(如某平台无数据):图表区按维度显示原因;
- 全部资产为"其他":图表仍照实显示事实条(其他 100%),**结论卡**输出数据质量警告(见 §7.4),不输出误导性结论。

## 7. 分析结论卡

### 7.1 纯函数

```dart
final class ConclusionItem {
  final String name;        // 指标名称
  final String result;      // 当前结果(格式化金额/百分比/—)
  final ConclusionStatus status; // normal / attention / warning,或 null(无判断)
  final String explanation; // 一句话解释
  final OverviewInsightAction? action; // 可选修复入口(跳转目标)
  final String actionLabel; // 入口按钮文案
}

List<ConclusionItem> buildAnalysisConclusions({
  required PortfolioSummary summary,
  required DataQualitySummary quality,
  required List<Holding> holdings,
  required StructureThresholds thresholds,
});
```

### 7.2 五项结论

| 指标 | 结果 | 状态规则 | 解释示例 | 修复入口 |
|---|---|---|---|---|
| 资产结构 | 已分类率 = 1 − 其他占比 | =100% 正常;<100% 需要处理 | 「N 项持仓未归入明确类别,结构占比可能失真」 | <100%:「补充资产分类」→ 持仓页 |
| 集中度 | 最大单项持仓占比 | 对比 `maxSingleHoldingShare` 阈值:超出→warning;范围内→normal;未设→无状态 | 「单一产品的价格波动会明显影响总资产」 | 超出:「查看持仓」 |
| 数据质量 | 数据完整度 | =100% 正常;<100% 需要处理 | 「存在缺字段的持仓,建议核对数据状态」 | <100%:「查看数据状态」→ 导入与识别页 |
| 收益覆盖 | 收益覆盖度 | =100% 正常;<100% 提示 | 「¥X 的资产缺少成本,未纳入收益统计」 | <100%:「查看持仓」 |
| 行情新鲜度 | 行情新鲜度;无自动行情时为 — | =100% 正常;<100% 提示 | 「有 N 项自动行情持仓的行情未更新」 | <100%:「查看数据状态」 |

- 状态标签:chip 样式复用现有 `_StatusChip`(normal = 绿软底/绿字,warning = 红软底/红字,attention = 琥珀软底/琥珀字),颜色之外附文字;
- 修复入口按钮跳转复用总览页 `SelectDestinationIntent` 模式(holdings / importReview);
- 阈值规则保持现有语义:未设置阈值时不输出状态判断(仅显示实际值)。

### 7.3 移除项

「现金及存款占比」「权益敞口占比」两行随指标清单一并移除;对应阈值仍保留在 `StructureThresholds` 与设置页,后续可挂回。

### 7.4 全部为"其他"时的处理(验收重点)

当 `byAssetClass` 中其他类别金额为 0、全部资产归入"其他"时:

- **不输出**「最大资产类别:其他 100%」作为正常分析结果;
- 结论卡资产结构行输出:**「资产分类率 0%｜需要处理」+「全部资产暂时被归入『其他』,请补充资产类别后再进行结构分析」+「补充资产分类」入口**;
- 图表仍展示事实(其他 100% 条)。

## 8. 数据流与错误处理

- 全部派生自现有 providers:`portfolioSummaryProvider` / `dataQualityProvider` / `holdingsProvider` / `structureThresholdsProvider` / `freshQuoteHoldingIdsProvider`;无新存储、无网络;
- 展示层计算全部收口为纯函数(`buildChartRows` / `buildAnalysisConclusions`),可独立单测;
- 百分比要么来自金额比例,要么来自字段计数,均可追溯;
- 页面级 loading / degraded / empty 状态与总览页保持一致。

## 9. 主题与文件组织

- `fundlens_tokens.dart` 新增 `chartBarShades` 常量(陶土 3 档 + 聚合暖灰),组件不硬编码颜色;
- 新文件:
  - `features/analysis/analysis_chart.dart` — `ChartBarRow` 行模型、`buildChartRows` 纯函数、条形图 / 堆叠比例条 Widget;
  - `features/analysis/analysis_conclusions.dart` — `ConclusionItem` 模型、`buildAnalysisConclusions` 纯函数、结论卡 Widget;
- 重组 `features/analysis/analysis_page.dart`(Tabs 状态、8+4 布局、页面级状态);
- 删除 `features/analysis/composition_table.dart`、`features/analysis/concentration_panel.dart`(被图表与结论卡取代)。

## 10. 测试计划

- 纯函数测试(`apps/fundlens_windows/test/features/analysis/`):
  - `buildChartRows`:≤6 全显、>6 前 5 + 其他合并、金额降序、聚合金额/占比求和正确;
  - `buildAnalysisConclusions`:全部其他 → 分类率 0% + 需要处理 + 补充分类入口;阈值比较(超出/范围内/未设);收益覆盖;行情新鲜度;
- Widget 测试:
  - Tabs 左右方向键切换、切换后卡片高度不变;
  - 三个维度图表金额与占比同时呈现;来源平台图例文字;
  - 空状态文案;全部其他场景不出现误导性结论;
  - 现有 6 个用例适配新结构(维度切换、阈值判断、禁词、窄屏不溢出);
- 不加 golden(分析页无先例;防回归可后补)。

## 11. 不做的事(YAGNI)

- 不引入第三方图表库;
- 不实现矩形树图(用户已确认横向条形图);
- 不在本页新增"最大资产类别"结论行(集中度行只保留最大单项);
- 不做任何收益/风险量化指标(产品定位约束);
- 不新增设置项与阈值。
