# 资产分析页重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将资产分析页重构为"可访问 Tabs + 三种图表 + 分析结论卡"，消除下半部分留白并输出带状态与修复入口的结论，而非静态指标清单。

**Architecture:** 展示层全部收口为两个纯函数（`buildChartRows` / `buildAnalysisConclusions`）+ 两个纯 Widget（图表 / 结论卡），由 `AnalysisPage` 通过现有 Riverpod providers 组装。图表用 CustomPaint/Widget 自绘（项目无图表库，延续 `asset_spectrum.dart` / `trend_chart.dart` 先例）。

**Tech Stack:** Flutter Windows / Riverpod 3.x / fundlens_core 领域层（DecimalValue）/ Material TabBar / CustomPaint。

**Spec:** `docs/superpowers/specs/2026-08-01-analysis-page-redesign-design.md`（用户已确认 2026-08-01）

## Global Constraints

- 分支 `feat/analysis-page-redesign`，工作目录 `D:\cc project\FundLens\.claude\worktrees\analysis-redesign`；每任务一次提交。
- 所有金额、价格、份额、比例使用 `DecimalValue`；转 `double`/字符串只发生在渲染边界。
- 颜色、间距、字号一律取自 `FundLensTokens`（间距只允许 4/8/12/16/24/32/40/48），组件中不得硬编码颜色。
- 页面不得出现投资建议措辞；禁词：`建议`、`应当`、`调仓`、`再平衡`、`买入`、`卖出`。
- 代码注释与界面文案使用中文。
- 不引入第三方图表库与任何新依赖（依赖版本阶段 1 已固定）。
- Flutter 位于 `D:\flutter\bin`（`flutter.bat` 为 Windows 批处理，Git Bash 直接调用路径即可）。
- 单文件测试：`cd apps/fundlens_windows && /d/flutter/bin/flutter.bat test test/features/analysis/<file>`（分析页测试仅用 Fake 仓库，无需 sqlite3mc）。
- 全量测试须经 sqlite3mc 包装（在 `apps/fundlens_windows` 目录内执行）：`python ../../tools/with_sqlite3mc_server.py 8765 /d/flutter/bin/flutter.bat test`。

## File Structure

| 文件 | 职责 |
|---|---|
| `lib/features/analysis/analysis_chart.dart` (创建) | `AnalysisDimension` 枚举 + `dimensionLabels`、`ChartBarRow` 行模型、`buildChartRows` 纯函数、`HorizontalBarChart`（横向条形图）、`PlatformProportionBar`（来源平台堆叠比例条）、`ChartEmptyState` |
| `lib/features/analysis/analysis_conclusions.dart` (创建) | `ConclusionStatus` / `ConclusionItem` 模型、`buildAnalysisConclusions` 纯函数、`AnalysisConclusionsCard` 结论卡 |
| `lib/features/analysis/analysis_page.dart` (重组) | TabController + 8/4 栅格 + 页面级 loading/empty/degraded 状态；删除 `CompositionTable`/`ConcentrationPanel` 引用 |
| `lib/features/analysis/analysis_labels.dart` (修改) | 新增 `formatAxisAmount` 紧凑刻度格式函数 |
| `lib/theme/fundlens_tokens.dart` (修改) | 新增 `chartBarShades` 品牌陶土深浅常量 |
| `lib/features/analysis/composition_table.dart` (删除) | 被横向条形图取代 |
| `lib/features/analysis/concentration_panel.dart` (删除) | 被结论卡取代 |
| `test/features/analysis/analysis_chart_test.dart` (创建) | `buildChartRows` 纯函数测试 + 图表 widget 测试 |
| `test/features/analysis/analysis_conclusions_test.dart` (创建) | `buildAnalysisConclusions` 纯函数测试 + 结论卡 widget 测试 |
| `test/features/analysis/analysis_page_test.dart` (修改) | Tabs 键盘切换、布局稳定、空状态、全其他警告、旧用例适配 |

---

### Task 1: ChartBarRow 行模型 + buildChartRows 纯函数

**Files:**
- Create: `apps/fundlens_windows/lib/features/analysis/analysis_chart.dart`
- Test: `apps/fundlens_windows/test/features/analysis/analysis_chart_test.dart`

**Interfaces:**
- Consumes: `PortfolioSummary`（`byAssetClass`/`byInstrumentType`/`bySource`/`totalValue`，来自 `package:fundlens_core/fundlens_core.dart`）；`assetClassLabels`/`instrumentTypeLabels`/`sourcePlatformLabels`/`formatShare`（`analysis_labels.dart`）
- Produces: `AnalysisDimension` 枚举（assetClass/instrumentType/source）、`dimensionLabels` 常量、`ChartBarRow{label, amount, share, isAggregate}`、`buildChartRows(PortfolioSummary, AnalysisDimension) → List<ChartBarRow>`（后续 Task 3 的图表与 Task 5 的页面使用）

- [ ] **Step 1: 写失败测试**

创建 `apps/fundlens_windows/test/features/analysis/analysis_chart_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/analysis/analysis_chart.dart';

PortfolioSummary fakeSummary({
  Map<AssetClass, DecimalValue> byAssetClass = const {},
  Map<InstrumentType, DecimalValue> byInstrumentType = const {},
  Map<SourcePlatform, DecimalValue> bySource = const {},
  String totalValue = '10000',
}) {
  return PortfolioSummary(
    totalValue: DecimalValue.parse(totalValue),
    totalCost: DecimalValue.zero,
    totalFloatingProfit: DecimalValue.zero,
    totalReturn: null,
    returnCoverage: DecimalValue.zero,
    byAssetClass: byAssetClass,
    byInstrumentType: byInstrumentType,
    bySource: bySource,
    holdingShares: const {},
    largestHoldingShare: DecimalValue.zero,
    largestAssetClassShare: DecimalValue.zero,
    cashAndDepositShare: DecimalValue.zero,
    equityExposureShare: DecimalValue.zero,
  );
}

void main() {
  test('≤6 项全部显示且按金额降序,占比可追溯到金额', () {
    final summary = fakeSummary(
      byAssetClass: {
        AssetClass.cash: DecimalValue.parse('1000'),
        AssetClass.equity: DecimalValue.parse('3000'),
        AssetClass.gold: DecimalValue.parse('2000'),
      },
      totalValue: '6000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.map((r) => r.label).toList(), ['权益', '黄金', '现金']);
    expect(rows[0].amount.canonical, '3000');
    expect(rows[0].share.canonical, '0.5'); // 3000 ÷ 6000
    expect(rows.every((r) => !r.isAggregate), isTrue);
  });

  test('超过 6 项时取前 5 并合并其余为"其他"聚合行', () {
    final byAssetClass = <AssetClass, DecimalValue>{
      for (final (i, c) in AssetClass.values.indexed)
        c: DecimalValue.parse('${(i + 1) * 1000}'),
    }; // 7 类:1000..7000,其他=7000 最大
    final summary = fakeSummary(
      byAssetClass: byAssetClass,
      totalValue: '28000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.length, 6);
    expect(rows.last.label, '其他');
    expect(rows.last.isAggregate, isTrue);
    expect(rows.last.amount.canonical, '15000'); // 1000+2000+3000+4000+5000
    expect(rows.last.share.canonical, '0.53571429'); // 15000 ÷ 28000
  });

  test('产品类型 9 类触发合并', () {
    final byInstrumentType = <InstrumentType, DecimalValue>{
      for (final (i, t) in InstrumentType.values.indexed)
        t: DecimalValue.parse('${(i + 1) * 1000}'),
    };
    final summary = fakeSummary(
      byInstrumentType: byInstrumentType,
      totalValue: '45000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.instrumentType);
    expect(rows.length, 6);
    expect(rows.last.isAggregate, isTrue);
    expect(rows.first.label, '实物黄金'); // 9000 最大
  });

  test('来源平台 3 项全部显示', () {
    final summary = fakeSummary(
      bySource: {
        SourcePlatform.alipay: DecimalValue.parse('5000'),
        SourcePlatform.ths: DecimalValue.parse('3000'),
        SourcePlatform.manual: DecimalValue.parse('2000'),
      },
      totalValue: '10000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.source);
    expect(rows.map((r) => r.label).toList(), ['支付宝', '同花顺', '手工录入']);
    expect(rows.length, 3);
  });

  test('零金额项被过滤', () {
    final summary = fakeSummary(
      byAssetClass: {
        AssetClass.cash: DecimalValue.zero,
        AssetClass.equity: DecimalValue.parse('3000'),
      },
      totalValue: '3000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.length, 1);
    expect(rows.single.label, '权益');
  });

  test('总资产为 0 时占比为 0 而非除零', () {
    final summary = fakeSummary(
      byAssetClass: {AssetClass.equity: DecimalValue.parse('3000')},
      totalValue: '0',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.single.share.canonical, '0');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd apps/fundlens_windows && /d/flutter/bin/flutter.bat test test/features/analysis/analysis_chart_test.dart`
Expected: FAIL，`buildChartRows` 未定义。

- [ ] **Step 3: 最小实现**

创建 `apps/fundlens_windows/lib/features/analysis/analysis_chart.dart`：

```dart
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_tokens.dart';
import 'analysis_labels.dart';

/// 分析页的三个构成维度,展示形态见 Task 3。
enum AnalysisDimension { assetClass, instrumentType, source }

const dimensionLabels = <AnalysisDimension, String>{
  AnalysisDimension.assetClass: '资产类别',
  AnalysisDimension.instrumentType: '产品类型',
  AnalysisDimension.source: '来源平台',
};

/// 图表中的一行:分组名称、金额、占总资产比例与是否"其他"聚合行。
final class ChartBarRow {
  const ChartBarRow({
    required this.label,
    required this.amount,
    required this.share,
    this.isAggregate = false,
  });

  final String label;

  /// 该分组当前金额(DecimalValue,不在此处转浮点)。
  final DecimalValue amount;

  /// 占总资产比例 0..1。
  final DecimalValue share;

  /// 超过 6 项时占比最小的类别合并为"其他"聚合行。
  final bool isAggregate;
}

/// 按维度生成图表行:零金额过滤 → 金额降序 → ≤6 全显,>6 前 5 + 合并"其他"。
List<ChartBarRow> buildChartRows(
  PortfolioSummary summary,
  AnalysisDimension dimension,
) {
  final raw = <(String, DecimalValue)>[];
  switch (dimension) {
    case AnalysisDimension.assetClass:
      for (final entry in summary.byAssetClass.entries) {
        if (!entry.value.isZero) {
          raw.add((assetClassLabels[entry.key]!, entry.value));
        }
      }
    case AnalysisDimension.instrumentType:
      for (final entry in summary.byInstrumentType.entries) {
        if (!entry.value.isZero) {
          raw.add((instrumentTypeLabels[entry.key]!, entry.value));
        }
      }
    case AnalysisDimension.source:
      for (final entry in summary.bySource.entries) {
        if (!entry.value.isZero) {
          raw.add((sourcePlatformLabels[entry.key]!, entry.value));
        }
      }
  }
  raw.sort((a, b) => b.$2.compareTo(a.$2));

  final total = summary.totalValue;
  DecimalValue shareOf(DecimalValue amount) =>
      total.isZero ? DecimalValue.zero : amount.divide(total);

  if (raw.length <= 6) {
    return [
      for (final (label, amount) in raw)
        ChartBarRow(label: label, amount: amount, share: shareOf(amount)),
    ];
  }
  final kept = raw.take(5).toList();
  final mergedAmount = raw
      .skip(5)
      .fold(DecimalValue.zero, (sum, entry) => sum + entry.$2);
  return [
    for (final (label, amount) in kept)
      ChartBarRow(label: label, amount: amount, share: shareOf(amount)),
    ChartBarRow(
      label: '其他',
      amount: mergedAmount,
      share: shareOf(mergedAmount),
      isAggregate: true,
    ),
  ];
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS（6 个测试）。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/analysis/analysis_chart.dart apps/fundlens_windows/test/features/analysis/analysis_chart_test.dart
git commit -m "feat(analysis): buildChartRows 图表行纯函数(降序/前5+其他合并/零金额过滤)"
```

---

### Task 2: ConclusionItem 模型 + buildAnalysisConclusions 纯函数

**Files:**
- Create: `apps/fundlens_windows/lib/features/analysis/analysis_conclusions.dart`
- Test: `apps/fundlens_windows/test/features/analysis/analysis_conclusions_test.dart`

**Interfaces:**
- Consumes: `PortfolioSummary`、`DataQualitySummary`、`List<Holding>`、`StructureThresholds`（`structure_thresholds.dart`）；`AppDestination`（`app/app_shell.dart`）；`formatAmount`/`formatShare`（`analysis_labels.dart`）
- Produces: `ConclusionStatus{normal, attention, warning}`、`ConclusionItem{name, result, status, explanation, action, actionLabel}`、`buildAnalysisConclusions({summary, quality, holdings, thresholds}) → List<ConclusionItem>`（5 项，固定顺序：资产结构/集中度/数据质量/收益覆盖/行情新鲜度；Task 4 的结论卡与 Task 5 的页面使用）

**说明（与规格 §7.1 的微小偏差）：** 规格示意类型 `OverviewInsightAction` 改为全局 `AppDestination`（holdings/importReview），跳转仍走 `SelectDestinationIntent` 模式——避免分析页反向依赖总览页类型。

- [ ] **Step 1: 写失败测试**

创建 `apps/fundlens_windows/test/features/analysis/analysis_conclusions_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/app/app_shell.dart';
import 'package:fundlens_windows/features/analysis/analysis_conclusions.dart';
import 'package:fundlens_windows/features/analysis/structure_thresholds.dart';

Holding fixtureHolding({
  required String id,
  required AssetClass assetClass,
  String? costAmount,
  ValuationMethod valuationMethod = ValuationMethod.manualAmount,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: '持仓$id',
    currency: 'CNY',
    currentValue: DecimalValue.parse('1000'),
    costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
    valuationMethod: valuationMethod,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

PortfolioSummary fakeSummary({
  Map<AssetClass, DecimalValue> byAssetClass = const {},
  String totalValue = '1000',
  String returnCoverage = '1',
  String largestHoldingShare = '1',
}) {
  return PortfolioSummary(
    totalValue: DecimalValue.parse(totalValue),
    totalCost: DecimalValue.zero,
    totalFloatingProfit: DecimalValue.zero,
    totalReturn: null,
    returnCoverage: DecimalValue.parse(returnCoverage),
    byAssetClass: byAssetClass,
    byInstrumentType: const {},
    bySource: const {},
    holdingShares: const {},
    largestHoldingShare: DecimalValue.parse(largestHoldingShare),
    largestAssetClassShare: DecimalValue.zero,
    cashAndDepositShare: DecimalValue.zero,
    equityExposureShare: DecimalValue.zero,
  );
}

DataQualitySummary fakeQuality({
  String dataCompleteness = '1',
  String? quoteFreshness = '1',
}) {
  return DataQualitySummary(
    dataCompleteness: DecimalValue.parse(dataCompleteness),
    quoteFreshness: quoteFreshness == null
        ? null
        : DecimalValue.parse(quoteFreshness),
  );
}

void main() {
  test('全部资产归入"其他"时输出数据质量警告而非正常结论', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.other: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(),
      holdings: [
        fixtureHolding(id: 'h-1', assetClass: AssetClass.other),
      ],
      thresholds: const StructureThresholds(),
    );
    final structure = items[0];
    expect(structure.name, '资产结构');
    expect(structure.result, '0.0%'); // 分类率 = 1 − 100%
    expect(structure.status, ConclusionStatus.warning);
    expect(structure.explanation, contains('补充资产类别'));
    expect(structure.action, AppDestination.holdings);
    expect(structure.actionLabel, '补充资产分类');
    // 全其他场景不出现"最大资产类别"结论
    expect(items.map((i) => i.name), isNot(contains('最大资产类别')));
  });

  test('部分未分类输出需要处理与入口', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {
          AssetClass.equity: DecimalValue.parse('600'),
          AssetClass.other: DecimalValue.parse('400'),
        },
        totalValue: '1000',
      ),
      quality: fakeQuality(),
      holdings: [
        fixtureHolding(id: 'h-1', assetClass: AssetClass.equity),
        fixtureHolding(id: 'h-2', assetClass: AssetClass.other),
      ],
      thresholds: const StructureThresholds(),
    );
    expect(items[0].result, '60.0%');
    expect(items[0].status, ConclusionStatus.warning);
    expect(items[0].actionLabel, '补充资产分类');
  });

  test('全部分类完成时资产结构正常且无入口', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(),
      holdings: [
        fixtureHolding(id: 'h-1', assetClass: AssetClass.equity),
      ],
      thresholds: const StructureThresholds(),
    );
    expect(items[0].result, '100.0%');
    expect(items[0].status, ConclusionStatus.normal);
    expect(items[0].action, isNull);
  });

  test('集中度:未设阈值时不作判断,超出阈值时警告并提供入口', () {
    final noThreshold = buildAnalysisConclusions(
      summary: fakeSummary(largestHoldingShare: '0.8'),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
    );
    expect(noThreshold[1].status, isNull);

    final breached = buildAnalysisConclusions(
      summary: fakeSummary(largestHoldingShare: '0.8'),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: StructureThresholds(
        maxSingleHoldingShare: DecimalValue.parse('0.5'),
      ),
    );
    expect(breached[1].status, ConclusionStatus.warning);
    expect(breached[1].action, AppDestination.holdings);
    expect(breached[1].result, contains('持仓h-1'));
  });

  test('收益覆盖不足时提示并给出未覆盖金额', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
        totalValue: '1000',
        returnCoverage: '0.6',
      ),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
    );
    final coverage = items[3];
    expect(coverage.result, '60.0%');
    expect(coverage.status, ConclusionStatus.attention);
    expect(coverage.explanation, contains('400.00')); // 1000 − 600
    expect(coverage.action, AppDestination.holdings);
  });

  test('行情新鲜度:无自动行情时为 —,未全部更新时提示', () {
    final none = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(quoteFreshness: null),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
    );
    expect(none[4].result, '—');
    expect(none[4].status, isNull);

    final stale = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(quoteFreshness: '0.5'),
      holdings: [
        fixtureHolding(
          id: 'h-1',
          assetClass: AssetClass.equity,
          valuationMethod: ValuationMethod.automaticQuote,
        ),
      ],
      thresholds: const StructureThresholds(),
    );
    expect(stale[4].status, ConclusionStatus.attention);
    expect(stale[4].action, AppDestination.importReview);
  });

  test('五项结论顺序固定', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
    );
    expect(
      items.map((i) => i.name).toList(),
      ['资产结构', '集中度', '数据质量', '收益覆盖', '行情新鲜度'],
    );
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd apps/fundlens_windows && /d/flutter/bin/flutter.bat test test/features/analysis/analysis_conclusions_test.dart`
Expected: FAIL，`buildAnalysisConclusions` 未定义。

- [ ] **Step 3: 最小实现**

创建 `apps/fundlens_windows/lib/features/analysis/analysis_conclusions.dart`：

```dart
import 'package:fundlens_core/fundlens_core.dart';

import '../../app/app_shell.dart';
import 'analysis_labels.dart';
import 'structure_thresholds.dart';

/// 结论状态:正常(绿)/提示(琥珀)/需要处理(红)。
enum ConclusionStatus { normal, attention, warning }

/// 分析结论卡中的一行:指标名称、当前结果、状态标签、一句话解释与可选入口。
final class ConclusionItem {
  const ConclusionItem({
    required this.name,
    required this.result,
    this.status,
    required this.explanation,
    this.action,
    this.actionLabel,
  });

  final String name;

  /// 当前结果(已格式化的金额/百分比,或 '—')。
  final String result;

  /// 状态标签;null 表示不输出状态判断(如未设阈值)。
  final ConclusionStatus? status;

  /// 一句话解释(只陈述可测量的事实,不包含投资行为措辞)。
  final String explanation;

  /// 修复入口跳转目标;null 表示无需处理。
  final AppDestination? action;
  final String? actionLabel;
}

/// 基于当前持仓与组合汇总生成五项分析结论。
///
/// 只陈述事实与数据问题:分类不足时优先提示数据问题,不输出
/// "最大资产类别:其他 100%"这类误导性结论。
List<ConclusionItem> buildAnalysisConclusions({
  required PortfolioSummary summary,
  required DataQualitySummary quality,
  required List<Holding> holdings,
  required StructureThresholds thresholds,
}) {
  // 1. 资产结构:已分类率 = 1 − 其他占比。
  final otherAmount =
      summary.byAssetClass[AssetClass.other] ?? DecimalValue.zero;
  final classifiedRate = summary.totalValue.isZero
      ? DecimalValue.zero
      : DecimalValue.parse('1') -
            otherAmount.divide(summary.totalValue);
  final uncategorized =
      holdings.where((h) => h.assetClass == AssetClass.other).length;
  final classifiedResult = formatShare(classifiedRate);
  final ConclusionItem structure;
  if (classifiedRate.compareTo(DecimalValue.parse('1')) < 0) {
    structure = ConclusionItem(
      name: '资产结构',
      result: classifiedResult,
      status: ConclusionStatus.warning,
      explanation: uncategorized == holdings.length
          ? '全部资产暂时被归入"其他",请补充资产类别后再进行结构分析。'
          : '有 $uncategorized 项持仓未归入明确类别,结构占比可能失真。',
      action: AppDestination.holdings,
      actionLabel: '补充资产分类',
    );
  } else {
    structure = ConclusionItem(
      name: '资产结构',
      result: classifiedResult,
      status: ConclusionStatus.normal,
      explanation: '所有资产均已明确分类,结构占比真实可靠。',
    );
  }

  // 2. 集中度:最大单项持仓占比(仅当设置阈值时输出判断)。
  final largest = _largestHolding(holdings);
  final threshold = thresholds.maxSingleHoldingShare;
  final ConclusionStatus? concentrationStatus;
  final String concentrationExplanation;
  if (threshold == null) {
    concentrationStatus = null;
    concentrationExplanation = '未设置集中度阈值,仅展示实际占比。';
  } else if (summary.largestHoldingShare.compareTo(threshold) > 0) {
    concentrationStatus = ConclusionStatus.warning;
    concentrationExplanation = '单一产品的价格波动会明显影响总资产的变化幅度。';
  } else {
    concentrationStatus = ConclusionStatus.normal;
    concentrationExplanation = '最大单项持仓占比在你设置的阈值范围内。';
  }
  final concentration = ConclusionItem(
    name: '集中度',
    result: largest == null
        ? formatShare(summary.largestHoldingShare)
        : '${largest.productName} ${formatShare(summary.largestHoldingShare)}',
    status: concentrationStatus,
    explanation: concentrationExplanation,
    action: concentrationStatus == ConclusionStatus.warning
        ? AppDestination.holdings
        : null,
    actionLabel: concentrationStatus == ConclusionStatus.warning
        ? '查看持仓'
        : null,
  );

  // 3. 数据质量:字段完整度。
  final complete = quality.dataCompleteness.compareTo(DecimalValue.parse('1')) >= 0;
  final qualityItem = ConclusionItem(
    name: '数据质量',
    result: formatShare(quality.dataCompleteness),
    status: complete ? ConclusionStatus.normal : ConclusionStatus.attention,
    explanation: complete
        ? '持仓字段完整,可直接进行结构分析。'
        : '存在缺字段的持仓,建议核对数据状态。',
    action: complete ? null : AppDestination.importReview,
    actionLabel: complete ? null : '查看数据状态',
  );

  // 4. 收益覆盖:有成本资产金额占总资产比例。
  final covered = summary.totalValue * summary.returnCoverage;
  final uncovered = summary.totalValue - covered;
  final coveredFull = summary.returnCoverage.compareTo(DecimalValue.parse('1')) >= 0;
  final coverage = ConclusionItem(
    name: '收益覆盖',
    result: formatShare(summary.returnCoverage),
    status: coveredFull ? ConclusionStatus.normal : ConclusionStatus.attention,
    explanation: coveredFull
        ? '全部资产均纳入收益统计。'
        : '¥${formatAmount(uncovered)} 的资产缺少成本,未纳入收益统计。',
    action: coveredFull ? null : AppDestination.holdings,
    actionLabel: coveredFull ? null : '查看持仓',
  );

  // 5. 行情新鲜度:自动行情持仓中已刷新金额的占比。
  final freshness = quality.quoteFreshness;
  final ConclusionItem freshnessItem;
  if (freshness == null) {
    freshnessItem = ConclusionItem(
      name: '行情新鲜度',
      result: '—',
      explanation: '没有自动行情持仓,不涉及行情新鲜度。',
    );
  } else {
    final fresh = freshness.compareTo(DecimalValue.parse('1')) >= 0;
    final staleCount = holdings
        .where(
          (h) =>
              h.valuationMethod == ValuationMethod.automaticQuote &&
              !_freshQuoteIds.contains(h.id),
        )
        .length;
    freshnessItem = ConclusionItem(
      name: '行情新鲜度',
      result: formatShare(freshness),
      status: fresh ? ConclusionStatus.normal : ConclusionStatus.attention,
      explanation: fresh
          ? '自动行情持仓的行情均已更新。'
          : '有 $staleCount 项自动行情持仓的行情未更新,显示的是最近一次估值。',
      action: fresh ? null : AppDestination.importReview,
      actionLabel: fresh ? null : '查看数据状态',
    );
  }

  return [
    structure,
    concentration,
    qualityItem,
    coverage,
    freshnessItem,
  ];
}

Holding? _largestHolding(List<Holding> holdings) {
  if (holdings.isEmpty) return null;
  var best = holdings.first;
  for (final holding in holdings.skip(1)) {
    if (holding.currentValue.compareTo(best.currentValue) > 0) {
      best = holding;
    }
  }
  return best;
}
```

**注意：** 上述实现中"行情新鲜度"项的 stale 计数依赖 `freshQuoteHoldingIdsProvider` 的集合，但纯函数无法访问 provider。修正：函数签名增加 `Set<String> freshQuoteHoldingIds` 参数（Task 5 的页面调用时传入 `ref.watch(freshQuoteHoldingIdsProvider)`），实现中 `_freshQuoteIds` 替换为 `freshQuoteHoldingIds`；对应测试增加该参数。请按下述签名实现：

```dart
List<ConclusionItem> buildAnalysisConclusions({
  required PortfolioSummary summary,
  required DataQualitySummary quality,
  required List<Holding> holdings,
  required StructureThresholds thresholds,
  required Set<String> freshQuoteHoldingIds,
})
```

并在所有测试调用处补 `freshQuoteHoldingIds: const <String>{}`（行情新鲜度用例传 `{'h-1'}` 以得到"已更新"路径，不传则走"未更新"路径）。

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS（7 个测试）。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/analysis/analysis_conclusions.dart apps/fundlens_windows/test/features/analysis/analysis_conclusions_test.dart
git commit -m "feat(analysis): buildAnalysisConclusions 五项结论纯函数(全其他警告/阈值判断/修复入口)"
```

---

### Task 3: 图表 Widget（横向条形图 + 来源平台堆叠比例条）

**Files:**
- Modify: `apps/fundlens_windows/lib/theme/fundlens_tokens.dart`（追加 `chartBarShades`）
- Modify: `apps/fundlens_windows/lib/features/analysis/analysis_labels.dart`（追加 `formatAxisAmount`）
- Modify: `apps/fundlens_windows/lib/features/analysis/analysis_chart.dart`（追加图表 Widget）
- Test: `apps/fundlens_windows/test/features/analysis/analysis_chart_test.dart`（追加 widget 测试）

**Interfaces:**
- Consumes: Task 1 的 `ChartBarRow`/`AnalysisDimension`；`FundLensTokens.chartBarShades`；`formatCurrency`（`features/overview/overview_formatters.dart`）
- Produces: `HorizontalBarChart({rows, chartHeight = 240})`、`PlatformProportionBar({rows})`、`ChartEmptyState()`（Task 5 的页面使用）

- [ ] **Step 1: 写失败测试**

在 `apps/fundlens_windows/test/features/analysis/analysis_chart_test.dart` 追加（保留 Task 1 内容，顶部 import 补 `package:flutter/material.dart`、`package:fundlens_windows/theme/fundlens_theme.dart`、`package:fundlens_windows/theme/fundlens_tokens.dart`）：

```dart
Widget chartHarness(Widget child) => MaterialApp(
      theme: FundLensTheme.light,
      home: Scaffold(body: child),
    );

final testRows = [
  ChartBarRow(
    label: '权益',
    amount: DecimalValue.parse('30000'),
    share: DecimalValue.parse('0.38'),
  ),
  ChartBarRow(
    label: '现金',
    amount: DecimalValue.parse('12000'),
    share: DecimalValue.parse('0.152'),
  ),
  ChartBarRow(
    label: '其他',
    amount: DecimalValue.parse('8000'),
    share: DecimalValue.parse('0.101'),
    isAggregate: true,
  ),
];

testWidgets('条形图同时显示名称、金额与占比', (tester) async {
  await tester.pumpWidget(chartHarness(HorizontalBarChart(rows: testRows)));
  expect(find.text('权益'), findsOneWidget);
  expect(find.text('¥30,000.00'), findsOneWidget);
  expect(find.text('38.0%'), findsOneWidget);
  expect(find.text('现金'), findsOneWidget);
  expect(find.text('¥12,000.00'), findsOneWidget);
});

testWidgets('条形图聚合行使用暖灰色而非主色', (tester) async {
  await tester.pumpWidget(chartHarness(HorizontalBarChart(rows: testRows)));
  final aggregateBar = tester.widget<Container>(
    find.descendant(
      of: find.byType(HorizontalBarChart),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == FundLensTokens.muted,
      ),
    ),
  );
  expect(aggregateBar, isNotNull);
});

testWidgets('条形图每行提供 Tooltip 语义(金额与占比)', (tester) async {
  await tester.pumpWidget(chartHarness(HorizontalBarChart(rows: testRows)));
  final tooltip = tester.widget<Tooltip>(
    find.byWidgetPredicate(
      (w) => w is Tooltip && w.message.contains('权益'),
    ),
  );
  expect(tooltip.message, contains('金额'));
  expect(tooltip.message, contains('38.0%'));
});

testWidgets('条形图空状态显示原因', (tester) async {
  await tester.pumpWidget(chartHarness(const HorizontalBarChart(rows: [])));
  expect(find.textContaining('暂无有效资产数据'), findsOneWidget);
});

testWidgets('来源平台比例条显示图例(名称/金额/占比)', (tester) async {
  await tester.pumpWidget(
    chartHarness(
      PlatformProportionBar(
        rows: [
          ChartBarRow(
            label: '支付宝',
            amount: DecimalValue.parse('5000'),
            share: DecimalValue.parse('0.5'),
          ),
          ChartBarRow(
            label: '同花顺',
            amount: DecimalValue.parse('3000'),
            share: DecimalValue.parse('0.3'),
          ),
          ChartBarRow(
            label: '手工录入',
            amount: DecimalValue.parse('2000'),
            share: DecimalValue.parse('0.2'),
          ),
        ],
      ),
    ),
  );
  expect(find.text('支付宝'), findsOneWidget);
  expect(find.text('¥5,000.00'), findsOneWidget);
  expect(find.text('50.0%'), findsOneWidget);
  expect(find.text('同花顺'), findsOneWidget);
});

testWidgets('窄屏(400px)下图表不溢出', (tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    chartHarness(HorizontalBarChart(rows: testRows)),
  );
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: 同 Task 1 Step 2
Expected: FAIL，`HorizontalBarChart` 未定义。

- [ ] **Step 3: 实现**

3a. 在 `apps/fundlens_windows/lib/theme/fundlens_tokens.dart` 的 `categoryColors` 之后追加：

```dart
  /// 图表用品牌陶土同系深浅(经 dataviz validate_palette 校验,浅档
  /// 读作灰色故只保留两档):堆叠比例条第 1/2 段;条形图统一用
  /// [accent],聚合"其他"行用 [muted]。
  static const chartBarShades = <Color>[
    Color(0xFFB65233),
    Color(0xFFD3896D),
  ];
```

3b. 在 `apps/fundlens_windows/lib/features/analysis/analysis_labels.dart` 追加：

```dart
/// 坐标轴紧凑刻度:≥1 万显示 `12.3万`,仅用于渲染。
String formatAxisAmount(DecimalValue value) {
  final number = value.value.toDouble();
  if (number.abs() >= 10000) {
    return '${(number / 10000).toStringAsFixed(1)}万';
  }
  return number.toStringAsFixed(0);
}
```

3c. 在 `analysis_chart.dart` 追加（文件头部 import 补 `package:flutter/material.dart`、`../../theme/fundlens_theme.dart`、`../../theme/fundlens_tokens.dart`、`../overview/overview_formatters.dart`）：

```dart
/// 图表空状态:无行时显示原因而不是灰色占位。
class ChartEmptyState extends StatelessWidget {
  const ChartEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '暂无有效资产数据,添加或更新持仓后展示结构分析。',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

String _rowSemantics(ChartBarRow row) =>
    '${row.label} 金额 ${formatCurrency(row.amount)} '
    '占比 ${formatShare(row.share)}';

/// 横向条形图:行 = 名称 + 条形(自 0 基线) + 条端金额 + 行尾占比,
/// 底部 0/50%/100% 弱化网格竖线与紧凑刻度。
///
/// [chartHeight] 为行区高度(不含底部刻度带);行槽在行区内均匀分布,
/// 保持图表区固定高度,切换维度时布局稳定。
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.rows,
    this.chartHeight = 240,
  });

  final List<ChartBarRow> rows;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const ChartEmptyState();
    final theme = Theme.of(context);
    final numberStyle = theme.extension<FundLensTextStyles>()!.financialNumber;
    final maxAmount = rows.first.amount; // 已按金额降序
    final midAmount = maxAmount.isZero
        ? DecimalValue.zero
        : DecimalValue.parse(
            (maxAmount.value.toDouble() / 2).toStringAsFixed(0),
          );
    final axisStyle = theme.textTheme.bodySmall;

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              Column(
                children: [
                  for (final row in rows)
                    Expanded(
                      child: Tooltip(
                        message: _rowSemantics(row),
                        child: Semantics(
                          label: _rowSemantics(row),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 84,
                                child: Text(
                                  row.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: FundLensTokens.space3),
                              Expanded(child: _Bar(row: row, maxAmount: maxAmount)),
                              const SizedBox(width: FundLensTokens.space3),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  formatCurrency(row.amount),
                                  textAlign: TextAlign.right,
                                  style: numberStyle,
                                ),
                              ),
                              const SizedBox(width: FundLensTokens.space4),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  formatShare(row.share),
                                  textAlign: TextAlign.right,
                                  style: numberStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // 0/50%/100% 弱化网格竖线(跨整个行区)。
              IgnorePointer(
                child: CustomPaint(
                  painter: _GridLinesPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 20,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(formatAxisAmount(DecimalValue.zero), style: axisStyle),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(formatAxisAmount(midAmount), style: axisStyle),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(formatAxisAmount(maxAmount), style: axisStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单条条形:轨道(surfaceAlt)+ 自 0 基线的主色/暖灰条形。
class _Bar extends StatelessWidget {
  const _Bar({required this.row, required this.maxAmount});

  final ChartBarRow row;
  final DecimalValue maxAmount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount.isZero
        ? 0.0
        : row.amount.divide(maxAmount).value.toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: FundLensTokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: row.isAggregate
                        ? FundLensTokens.muted
                        : FundLensTokens.accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridLinesPainter extends CustomPainter {
  const _GridLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FundLensTokens.border
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final x = size.width * fraction;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridLinesPainter oldDelegate) => false;
}

/// 来源平台横向比例条:单条 100% 宽堆叠条(段间 2px surface 间隔) +
/// 图例行(色点 + 名称 + 金额 + 占比)。段色取品牌陶土同系三档。
class PlatformProportionBar extends StatelessWidget {
  const PlatformProportionBar({super.key, required this.rows});

  final List<ChartBarRow> rows;

  Color _colorFor(int index) => switch (index) {
        0 => FundLensTokens.accent,
        1 => FundLensTokens.chartBarShades[1],
        _ => FundLensTokens.muted,
      };

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const ChartEmptyState();
    final theme = Theme.of(context);
    final numberStyle = theme.extension<FundLensTextStyles>()!.financialNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: rows
              .map((row) => '${row.label} ${formatShare(row.share)}')
              .join(' · '),
          child: Semantics(
            label: rows
                .map((row) => '${row.label} ${formatShare(row.share)}')
                .join(' · '),
            child: SizedBox(
              height: 14,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final flexes = rows
                      .map((r) => (r.share.value.toDouble() * 1000).round())
                      .toList();
                  if (flexes.every((f) => f == 0)) {
                    return Container(
                      decoration: BoxDecoration(
                        color: FundLensTokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }
                  return Row(
                    children: [
                      for (final (i, row) in rows.indexed)
                        Expanded(
                          flex: flexes[i].clamp(1, 1000),
                          child: Container(
                            height: 14,
                            margin: i > 0
                                ? const EdgeInsets.only(left: 2)
                                : null,
                            decoration: BoxDecoration(
                              color: _colorFor(i),
                              borderRadius: BorderRadius.horizontal(
                                right: i == rows.length - 1
                                    ? const Radius.circular(4)
                                    : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: FundLensTokens.space3),
        for (final (i, row) in rows.indexed)
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _colorFor(i),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: FundLensTokens.space2),
                Expanded(
                  child: Text(row.label, style: theme.textTheme.bodyMedium),
                ),
                Text(formatCurrency(row.amount), style: numberStyle),
                const SizedBox(width: FundLensTokens.space4),
                SizedBox(
                  width: 52,
                  child: Text(
                    formatShare(row.share),
                    textAlign: TextAlign.right,
                    style: numberStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS（Task 1 的 6 个 + 本任务的 6 个 = 12 个）。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/theme/fundlens_tokens.dart apps/fundlens_windows/lib/features/analysis/analysis_labels.dart apps/fundlens_windows/lib/features/analysis/analysis_chart.dart apps/fundlens_windows/test/features/analysis/analysis_chart_test.dart
git commit -m "feat(analysis): 横向条形图与来源平台堆叠比例条(chartBarShades/刻度网格/Tooltip/空状态)"
```

---

### Task 4: 分析结论卡 Widget

**Files:**
- Modify: `apps/fundlens_windows/lib/features/analysis/analysis_conclusions.dart`（追加结论卡 Widget）
- Test: `apps/fundlens_windows/test/features/analysis/analysis_conclusions_test.dart`（追加 widget 测试）

**Interfaces:**
- Consumes: Task 2 的 `ConclusionItem`/`ConclusionStatus`；`SelectDestinationIntent`（`app/app_shell.dart`）；`FundLensTokens`
- Produces: `AnalysisConclusionsCard({required List<ConclusionItem> items})`（Task 5 的页面使用；内部点击入口通过 `Actions.maybeInvoke` 发 `SelectDestinationIntent`）

- [ ] **Step 1: 写失败测试**

在 `apps/fundlens_windows/test/features/analysis/analysis_conclusions_test.dart` 追加：

```dart
testWidgets('结论卡显示五项的名称/结果/解释与状态标签', (tester) async {
  final items = [
    ConclusionItem(
      name: '资产结构',
      result: '0.0%',
      status: ConclusionStatus.warning,
      explanation: '全部资产暂时被归入"其他",请补充资产类别后再进行结构分析。',
      action: AppDestination.holdings,
      actionLabel: '补充资产分类',
    ),
    ConclusionItem(name: '集中度', result: '持仓h-1 100.0%', explanation: '未设置集中度阈值,仅展示实际占比。'),
    ConclusionItem(
      name: '数据质量',
      result: '100.0%',
      status: ConclusionStatus.normal,
      explanation: '持仓字段完整,可直接进行结构分析。',
    ),
    ConclusionItem(name: '收益覆盖', result: '100.0%', explanation: '全部资产均纳入收益统计。'),
    ConclusionItem(name: '行情新鲜度', result: '—', explanation: '没有自动行情持仓,不涉及行情新鲜度。'),
  ];
  await tester.pumpWidget(
    MaterialApp(
      theme: FundLensTheme.light,
      home: Scaffold(
        body: AnalysisConclusionsCard(items: items),
      ),
    ),
  );
  expect(find.text('资产结构'), findsOneWidget);
  expect(find.text('0.0%'), findsOneWidget);
  expect(find.text('需要处理'), findsOneWidget); // warning chip 文案
  expect(find.textContaining('补充资产类别'), findsOneWidget);
  expect(find.text('补充资产分类'), findsOneWidget); // 修复入口按钮
  expect(find.text('正常'), findsOneWidget); // 数据质量 normal chip
  expect(find.text('持仓字段完整'), findsOneWidget);
});

testWidgets('状态 chip 在无状态时不渲染', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: FundLensTheme.light,
      home: Scaffold(
        body: AnalysisConclusionsCard(
          items: [
            ConclusionItem(
              name: '集中度',
              result: '50.0%',
              explanation: '未设置集中度阈值,仅展示实际占比。',
            ),
          ],
        ),
      ),
    ),
  );
  expect(find.text('正常'), findsNothing);
  expect(find.text('需要处理'), findsNothing);
});

testWidgets('点击修复入口发出 SelectDestinationIntent', (tester) async {
  AppDestination? dispatched;
  await tester.pumpWidget(
    MaterialApp(
      theme: FundLensTheme.light,
      home: Actions(
        actions: {
          SelectDestinationIntent: CallbackAction<SelectDestinationIntent>(
            onInvoke: (intent) {
              dispatched = intent.destination;
              return null;
            },
          ),
        },
        child: Scaffold(
          body: AnalysisConclusionsCard(
            items: [
              ConclusionItem(
                name: '资产结构',
                result: '0.0%',
                status: ConclusionStatus.warning,
                explanation: '全部资产暂时被归入"其他"。',
                action: AppDestination.holdings,
                actionLabel: '补充资产分类',
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('补充资产分类'));
  await tester.pump();
  expect(dispatched, AppDestination.holdings);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd apps/fundlens_windows && /d/flutter/bin/flutter.bat test test/features/analysis/analysis_conclusions_test.dart`
Expected: FAIL，`AnalysisConclusionsCard` 未定义。

- [ ] **Step 3: 实现**

在 `analysis_conclusions.dart` 追加（头部 import 补 `package:flutter/material.dart`、`../../theme/fundlens_tokens.dart`）：

```dart
/// 分析结论卡:五项结论,每项 = 名称 + 结果 + 状态标签 + 一句话解释,
/// 必要时附修复入口按钮(跳转目标页,不包含投资行为措辞)。
class AnalysisConclusionsCard extends StatelessWidget {
  const AnalysisConclusionsCard({super.key, required this.items});

  final List<ConclusionItem> items;

  void _go(BuildContext context, AppDestination destination) {
    Actions.maybeInvoke(context, SelectDestinationIntent(destination));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '分析结论',
              style: theme.extension<FundLensTextStyles>()!.sectionTitle,
            ),
            const SizedBox(height: FundLensTokens.space3),
            for (final item in items)
              _ConclusionRow(
                item: item,
                onAction: item.action == null
                    ? null
                    : () => _go(context, item.action!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConclusionRow extends StatelessWidget {
  const _ConclusionRow({required this.item, this.onAction});

  final ConclusionItem item;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberStyle = theme.extension<FundLensTextStyles>()!.financialNumber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FundLensTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(item.name, style: theme.textTheme.bodyMedium),
              ),
              Expanded(
                child: Text(
                  item.result,
                  style: numberStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.status != null) _StatusChip(item: item),
            ],
          ),
          const SizedBox(height: FundLensTokens.space1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 84),
              Expanded(
                child: Text(
                  item.explanation,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: FundLensTokens.space2,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(item.actionLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 状态胶囊标签:正常(绿)/提示(琥珀)/需要处理(红),颜色之外必有文字。
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final ConclusionItem item;

  (Color, Color) get _colors => switch (item.status!) {
        ConclusionStatus.normal => (FundLensTokens.lossSoft, FundLensTokens.loss),
        ConclusionStatus.attention => (FundLensTokens.warnSoft, FundLensTokens.warn),
        ConclusionStatus.warning => (FundLensTokens.profitSoft, FundLensTokens.profit),
      };

  String get _label => switch (item.status!) {
        ConclusionStatus.normal => '正常',
        ConclusionStatus.attention => '提示',
        ConclusionStatus.warning => '需要处理',
      };

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusPill),
      ),
      alignment: Alignment.center,
      child: Text(
        _label,
        style: TextStyle(
          fontFamily: 'Noto Sans SC',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS（Task 2 的 7 个 + 本任务的 3 个 = 10 个）。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/analysis/analysis_conclusions.dart apps/fundlens_windows/test/features/analysis/analysis_conclusions_test.dart
git commit -m "feat(analysis): 分析结论卡(状态胶囊/一句话解释/修复入口跳转)"
```

---

### Task 5: AnalysisPage 重组（Tabs + 8/4 栅格 + 页面级状态）

**Files:**
- Modify: `apps/fundlens_windows/lib/features/analysis/analysis_page.dart`（整体重写）
- Delete: `apps/fundlens_windows/lib/features/analysis/composition_table.dart`
- Delete: `apps/fundlens_windows/lib/features/analysis/concentration_panel.dart`
- Test: `apps/fundlens_windows/test/features/analysis/analysis_page_test.dart`（整体重写）

**Interfaces:**
- Consumes: Task 1–4 的全部产物；`portfolioStateProvider`/`portfolioSummaryProvider`/`dataQualityProvider`/`holdingsProvider`/`freshQuoteHoldingIdsProvider`（`application/portfolio_providers.dart`、`application/app_dependencies.dart`）；`structureThresholdsProvider`；`showHoldingEditorDialog`（`features/holdings/holding_editor_dialog.dart`）；`holdingRepositoryProvider`
- Produces: 重组的 `AnalysisPage`（TabController 三 Tab、8/4 栅格、空/加载/降级状态）

- [ ] **Step 1: 写失败测试**

整体重写 `apps/fundlens_windows/test/features/analysis/analysis_page_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/analysis/analysis_page.dart';
import 'package:fundlens_windows/features/analysis/structure_thresholds.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

final class FakeHoldingRepository implements HoldingRepository {
  FakeHoldingRepository(this._holdings);

  final List<Holding> _holdings;

  @override
  Stream<List<Holding>> watchAll() => Stream.value(_holdings);

  @override
  Future<List<Holding>> getAll() async => _holdings;

  @override
  Future<void> upsert(Holding holding) async {}

  @override
  Future<void> replacePlatform(
    SourcePlatform platform,
    List<Holding> holdings,
  ) async {}

  @override
  Future<void> deleteByIds(List<String> ids) async {}

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();
}

Holding fixtureHolding({
  required String id,
  required String productName,
  required AssetClass assetClass,
  required InstrumentType instrumentType,
  required SourcePlatform sourcePlatform,
  required String currentValue,
  String? costAmount,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: sourcePlatform,
    instrumentType: instrumentType,
    assetClass: assetClass,
    productName: productName,
    currency: 'CNY',
    currentValue: DecimalValue.parse(currentValue),
    costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

Widget analysisHarness({List<Holding>? holdings}) {
  final fixture = holdings ??
      [
        fixtureHolding(
          id: 'h-1',
          productName: '成长基金',
          assetClass: AssetClass.equity,
          instrumentType: InstrumentType.offExchangeFund,
          sourcePlatform: SourcePlatform.alipay,
          currentValue: '1000.00',
        ),
        fixtureHolding(
          id: 'h-2',
          productName: '定期存款',
          assetClass: AssetClass.deposit,
          instrumentType: InstrumentType.bankDeposit,
          sourcePlatform: SourcePlatform.manual,
          currentValue: '3000.00',
          costAmount: '3000.00',
        ),
      ];
  return ProviderScope(
    overrides: [
      holdingRepositoryProvider.overrideWithValue(
        FakeHoldingRepository(fixture),
      ),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
      structureThresholdsProvider.overrideWith((ref) => const StructureThresholds()),
    ],
    child: MaterialApp(theme: FundLensTheme.light, home: const AnalysisPage()),
  );
}

Future<void> pumpAnalysis(WidgetTester tester, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(analysisHarness());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('analysis does not emit allocation advice', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    for (final forbidden in ['建议', '应当', '调仓', '再平衡', '买入', '卖出']) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('资产类别图表显示金额与占比', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    expect(find.text('资产类别'), findsOneWidget); // Tab
    expect(find.text('¥3,000.00'), findsOneWidget);
    expect(find.text('¥1,000.00'), findsOneWidget);
    expect(find.text('75.0%'), findsWidgets);
    expect(find.text('25.0%'), findsWidgets);
  });

  testWidgets('来源平台 Tab 切换后显示平台图例', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('来源平台'));
    await tester.pumpAndSettle();
    expect(find.text('手工录入'), findsOneWidget);
    expect(find.text('支付宝'), findsOneWidget);
  });

  testWidgets('Tabs 支持键盘左右切换', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('资产类别'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    // 已切到"产品类型":图表显示产品类型标签
    expect(find.text('场外基金'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('来源平台'), findsOneWidget);
    expect(find.text('手工录入'), findsOneWidget);
  });

  testWidgets('切换维度时图表区高度不变(布局稳定)', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    final before = tester.getSize(
      find.byKey(const ValueKey('analysis-chart-area')),
    );
    await tester.tap(find.text('来源平台'));
    await tester.pumpAndSettle();
    final after = tester.getSize(
      find.byKey(const ValueKey('analysis-chart-area')),
    );
    expect(after.height, before.height);
    await tester.tap(find.text('产品类型'));
    await tester.pumpAndSettle();
    final afterSecond = tester.getSize(
      find.byKey(const ValueKey('analysis-chart-area')),
    );
    expect(afterSecond.height, before.height);
  });

  testWidgets('分析结论卡显示五项结论与状态', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    expect(find.text('分析结论'), findsOneWidget);
    expect(find.text('资产结构'), findsOneWidget);
    expect(find.text('集中度'), findsOneWidget);
    expect(find.text('数据质量'), findsOneWidget);
    expect(find.text('收益覆盖'), findsOneWidget);
    expect(find.text('行情新鲜度'), findsOneWidget);
    expect(find.text('正常'), findsWidgets);
  });

  testWidgets('全部资产为"其他"时输出数据质量警告而非误导性结论', (tester) async {
    await tester.pumpWidget(
      analysisHarness(
        holdings: [
          fixtureHolding(
            id: 'h-1',
            productName: '未分类产品',
            assetClass: AssetClass.other,
            instrumentType: InstrumentType.offExchangeFund,
            sourcePlatform: SourcePlatform.alipay,
            currentValue: '5000.00',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('需要处理'), findsOneWidget);
    expect(find.text('补充资产分类'), findsOneWidget);
    expect(find.textContaining('请补充资产类别'), findsOneWidget);
    expect(find.text('最大资产类别'), findsNothing);
  });

  testWidgets('无持仓时显示空状态与添加入口', (tester) async {
    await tester.pumpWidget(analysisHarness(holdings: []));
    await tester.pumpAndSettle();
    expect(find.text('添加第一项资产'), findsOneWidget);
  });

  testWidgets('分析页使用 standard 档 PageScaffold', (tester) async {
    await pumpAnalysis(tester);
    expect(find.byType(PageScaffold), findsOneWidget);
    expect(find.text('资产分析'), findsOneWidget);
  });

  testWidgets('窄屏(760px)下堆叠且不溢出', (tester) async {
    await pumpAnalysis(tester, size: const Size(760, 900));
    expect(tester.takeException(), isNull);
  });
}
```

注意：测试中 `find.text('资产类别')` 在 Tab 与图表行名称中可能同时出现（如类别名"现金"等与 Tab 文案不同，无冲突；但"资产类别"仅 Tab 使用，图表行用具体类别名）。`3,000.00`/`1,000.00` 为 `formatAmount` 输出（金额列用 `formatCurrency` 输出 `¥3,000.00`——若测试断言不匹配，将两处金额断言改为 `¥3,000.00`/`¥1,000.00`，以实际渲染为准，见 Step 3 说明）。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd apps/fundlens_windows && /d/flutter/bin/flutter.bat test test/features/analysis/analysis_page_test.dart`
Expected: FAIL（旧页面无 TabBar/结论卡/图表区 key）。

- [ ] **Step 3: 实现**

整体重写 `apps/fundlens_windows/lib/features/analysis/analysis_page.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../application/portfolio_state.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/grid_row.dart';
import '../../widgets/page_scaffold.dart';
import '../holdings/holding_editor_dialog.dart';
import 'analysis_chart.dart';
import 'analysis_conclusions.dart';
import 'structure_thresholds.dart';

/// 资产分析页:三个构成维度(Tabs) + 图表 + 分析结论。
///
/// 只描述资产事实与数据质量,不输出任何投资行为措辞。
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AnalysisDimension.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addFirstAsset(BuildContext context) async {
    final holding = await showHoldingEditorDialog(context);
    if (holding == null) return;
    await ref.read(holdingRepositoryProvider).upsert(holding);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioStateProvider);
    return PageScaffold(
      tier: PageWidthTier.standard,
      crumb: '组合',
      title: '资产分析',
      body: switch (state) {
        PortfolioLoading() => const Center(child: CircularProgressIndicator()),
        PortfolioDegraded(:final error) => Center(child: Text('数据暂时不可用：$error')),
        PortfolioEmpty() => Center(
          child: FilledButton.icon(
            key: const ValueKey('analysis-add-first-asset'),
            onPressed: () => _addFirstAsset(context),
            icon: const Icon(Icons.add),
            label: const Text('添加第一项资产'),
          ),
        ),
        PortfolioReady() => _AnalysisBody(tabController: _tabController),
      },
    );
  }
}

/// 主体:左 8 列图表卡 + 右 4 列结论卡;窄屏堆叠。
class _AnalysisBody extends ConsumerWidget {
  const _AnalysisBody({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final quality = ref.watch(dataQualityProvider);
    final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
    final thresholds = ref.watch(structureThresholdsProvider);
    final freshQuoteHoldingIds = ref.watch(freshQuoteHoldingIdsProvider);
    final dimension = AnalysisDimension.values[tabController.index];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: FundLensTokens.pagePadding),
      child: GridRow(
        children: [
          GridCol(span: 8, child: _CompositionChartCard(tabController: tabController)),
          GridCol(
            span: 4,
            child: AnalysisConclusionsCard(
              items: buildAnalysisConclusions(
                summary: summary,
                quality: quality,
                holdings: holdings,
                thresholds: thresholds,
                freshQuoteHoldingIds: freshQuoteHoldingIds,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 左卡:标题 + 可访问 Tabs + 固定高度图表区(切换仅换内容,布局稳定)。
class _CompositionChartCard extends ConsumerWidget {
  const _CompositionChartCard({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(portfolioSummaryProvider);
    final dimension = AnalysisDimension.values[tabController.index];
    final rows = buildChartRows(summary, dimension);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '资产构成',
              style: theme.extension<FundLensTextStyles>()!.sectionTitle,
            ),
            const SizedBox(height: FundLensTokens.space4),
            TabBar(
              controller: tabController,
              indicatorColor: FundLensTokens.accent,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: FundLensTokens.border,
              labelColor: FundLensTokens.ink,
              unselectedLabelColor: FundLensTokens.muted,
              labelStyle: const TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: [
                for (final d in AnalysisDimension.values)
                  Tab(text: dimensionLabels[d]),
              ],
            ),
            const SizedBox(height: FundLensTokens.space3),
            SizedBox(
              height: 264,
              key: const ValueKey('analysis-chart-area'),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (dimension) {
                  AnalysisDimension.source => PlatformProportionBar(
                    key: const ValueKey('platform-proportion-bar'),
                    rows: rows,
                  ),
                  _ => HorizontalBarChart(
                    key: const ValueKey('horizontal-bar-chart'),
                    rows: rows,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

删除文件：

```bash
git rm apps/fundlens_windows/lib/features/analysis/composition_table.dart apps/fundlens_windows/lib/features/analysis/concentration_panel.dart
```

- [ ] **Step 4: 运行测试确认通过**

Run: 同 Step 2
Expected: PASS（9 个测试）。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/analysis/analysis_page.dart apps/fundlens_windows/test/features/analysis/analysis_page_test.dart
git commit -m "feat(analysis): 页面重组——Tabs/8+4栅格/页面级状态,删除构成表与指标清单"
```

---

### Task 6: 回归门禁

**Files:**
- 无新增/修改（仅验证）

- [ ] **Step 1: 静态检查**

Run: `cd apps/fundlens_windows && /d/flutter/bin/flutter.bat analyze`
Expected: No issues found。

- [ ] **Step 2: 全量测试(经 sqlite3mc 包装)**

Run: `cd apps/fundlens_windows && python ../../tools/with_sqlite3mc_server.py 8765 /d/flutter/bin/flutter.bat test`
Expected: All tests passed（基线 286 个 + 新增 15 个 ≈ 301 个；最终数以实际为准，但不得低于基线）。

- [ ] **Step 3: 核心层回归**

Run: `cd packages/fundlens_core && /d/flutter/bin/dart.bat test`
Expected: All tests passed（18 个）。

- [ ] **Step 4: 提交收尾（如 analyze 有格式化/清理性修改）**

```bash
git add -A
git commit -m "chore(analysis): 回归通过——analyze 与全量测试全绿" || echo "无变更可提交"
```

---

## Self-Review 记录

- **Spec 覆盖**：§2 目标→Task 5 页面测试（高度稳定/键盘切换/全其他警告/空状态）+ Task 1–4；§4 页面结构→Task 5；§5 Tabs→Task 5；§6 图表（合并规则/三形态/标记规范/配色/空状态）→Task 1/3；§7 结论卡（五项/状态/全其他）→Task 2/4；§8 数据流→纯函数 + Task 5 组装；§9 文件组织→Task 1–5；§10 测试→各任务；§11 不做的事→无对应任务。
- **占位符**：无 TBD/TODO；所有步骤含完整代码与命令。
- **类型一致性**：`buildChartRows(PortfolioSummary, AnalysisDimension)` Task 1 定义、Task 3/5 使用一致；`buildAnalysisConclusions` 签名（含 `freshQuoteHoldingIds`）Task 2 定义、Task 5 调用一致；`ChartBarRow`/`ConclusionItem` 字段跨任务一致；`AnalysisDimension` 由 Task 1 定义并供 Task 5 使用（原 `analysis_page.dart` 中的枚举已迁出）。
