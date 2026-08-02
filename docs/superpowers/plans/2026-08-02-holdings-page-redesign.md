# 全部持仓页改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"全部持仓"页改造为高效数据管理页面——完整工具栏（搜索/4 筛选/排序/添加）、13 列 flex 填满宽度的表格、明确缺失数据文案、行详情抽屉、批量操作、空状态与计数。

**Architecture:** 展示逻辑全部收口为纯函数（数据状态派生、单元格文案、筛选/排序、列宽分配），Widget 层只做渲染与交互；保留现有双区虚拟滚动表格架构（名称冻结区 + 横向滚动区），列宽从固定 px 改为 min-width + flex 权重；新功能（抽屉/批量条/工具栏）各自独立文件。

**Tech Stack:** Flutter Windows / Riverpod 3 / fundlens_core（纯 Dart）/ Drift（不动 schema）/ file_picker 10.3.7（已有依赖，导出保存对话框）。

## Global Constraints

- 所有金额/份额/价格/比例使用 `DecimalValue`，double 转换只发生在渲染边界。
- 颜色、间距、字号一律取自 `FundLensTokens`/主题；间距只允许 4/8/12/16/24/32/40/48（space1=4, space2=8, space3=12, space4=16, space6=24, space8=32, space10=40, space12=48）；组件不得硬编码颜色。
- 行高 56 = `FundLensTokens.rowHeight`；表头高 48；点击区域 ≥40×40；说明文字 ≥12px。
- 红盈利（profit #B84B34）绿亏损（loss #19705D）+ 显式 +/- 符号；数据状态/缺失文案用 muted 文字，不用高饱和色块。
- 页面文案禁止 `建议/应当/调仓/再平衡/买入/卖出`（有 find.textContaining 断言测试）。
- 累计收益（cumulativeProfit）只展示，不纳入当前浮动盈亏汇总。
- 历史快照不可变（本页不触碰快照）；领域层 fundlens_core 不依赖 Flutter。
- 代码注释与界面文案使用中文；不引入任何新依赖。
- 严格遵守 TDD：先写失败测试 → 最小实现 → 全绿 → 小而清晰提交。
- flutter 位于 `D:\flutter\bin`（用 `/d/flutter/bin/flutter.bat`）；flutter 命令必须从 `apps/fundlens_windows` 目录运行；全量测试用 sqlite3mc 包装：`python ../../tools/with_sqlite3mc_server.py 8765 /d/flutter/bin/flutter.bat test`（不能传 `--` 分隔符）。
- windows/flutter/generated_* 文件若出现纯 CRLF 行尾噪音，用 `git restore apps/fundlens_windows/windows/flutter/` 清理，不要提交。

---

### Task 1: holding_status.dart — 数据状态派生与缺失文案纯函数

**Files:**
- Create: `apps/fundlens_windows/lib/features/holdings/holding_status.dart`
- Modify: `apps/fundlens_windows/lib/features/holdings/holding_grid.dart`（删除 `HoldingValueFormatter` 定义，改为 import）
- Modify: `apps/fundlens_windows/lib/features/holdings/holding_export_service.dart:7`（import 从 holding_grid.dart 改为 holding_status.dart）
- Test: `apps/fundlens_windows/test/features/holdings/holding_status_test.dart`

**Interfaces:**
- Consumes: `Holding`（fundlens_core，含 `effectiveCostAmount`、`currentFloatingProfit` getter）、`DecimalValue`（`canonical`/`isZero`/`isNegative`/`compareTo`/`divide(other, {scale=8})`/`parse`）。
- Produces（后续任务依赖的确切签名）:
  - `enum HoldingDataStatus { incomplete, noQuote, staleQuote, missingCost, normal }`
  - `const holdingDataStatusLabels = <HoldingDataStatus, String>{...}`（未填写/暂无行情/等待更新/缺少成本/正常）
  - `HoldingDataStatus deriveHoldingDataStatus(Holding holding, {required Set<String> freshQuoteHoldingIds})`
  - `abstract final class HoldingValueFormatter`（从 holding_grid.dart 原样迁移 + 新增 `percent`）
  - `String holdingQuantityText(Holding)` / `holdingPriceText(Holding)` / `holdingCostText(Holding)` / `holdingProfitText(Holding)` / `holdingReturnText(Holding)` / `holdingValuationDateText(Holding)` / `holdingShareText(DecimalValue? share)`
  - `DecimalValue? holdingEffectiveReturn(Holding)`

- [ ] **Step 1: Write the failing test**

Create `apps/fundlens_windows/test/features/holdings/holding_status_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_status.dart';

final _now = DateTime.utc(2026, 7, 20);

/// 构造一条"正常"的行情类持仓;用命名参数覆盖需要变化的字段。
/// noQuantity/noPrice/noDate 用于显式制造 null(默认参数有兜底值)。
Holding fixtureHolding({
  String id = 'h-1',
  String productName = '测试基金',
  String? productCode = '110011',
  String currency = 'CNY',
  DecimalValue? quantity,
  DecimalValue? currentPrice,
  DecimalValue? costAmount,
  DecimalValue? holdingProfit,
  DecimalValue? holdingReturn,
  DecimalValue? currentValue,
  ValuationMethod valuationMethod = ValuationMethod.automaticQuote,
  DateTime? valuationDate,
  bool noQuantity = false,
  bool noPrice = false,
  bool noDate = false,
}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: productName,
    productCode: productCode,
    currency: currency,
    quantity: noQuantity ? null : (quantity ?? DecimalValue.parse('1000')),
    currentPrice: noPrice ? null : (currentPrice ?? DecimalValue.parse('1.5')),
    costAmount: costAmount,
    holdingProfit: holdingProfit,
    holdingReturn: holdingReturn,
    currentValue: currentValue ?? DecimalValue.parse('1500'),
    valuationMethod: valuationMethod,
    valuationDate: noDate ? null : (valuationDate ?? DateTime.utc(2026, 7, 19)),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  group('deriveHoldingDataStatus', () {
    test('正常持仓返回 normal', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(costAmount: DecimalValue.parse('1000')),
        freshQuoteHoldingIds: {'h-1'},
      );
      expect(status, HoldingDataStatus.normal);
    });

    test('名称为空返回未填写', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(productName: '  '),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.incomplete);
    });

    test('自动行情缺产品代码返回未填写', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(productCode: null),
        freshQuoteHoldingIds: const {'h-1'},
      );
      expect(status, HoldingDataStatus.incomplete);
    });

    test('行情类缺现价返回暂无行情(不被未填写吞掉)', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(noPrice: true),
        freshQuoteHoldingIds: const {'h-1'},
      );
      expect(status, HoldingDataStatus.noQuote);
    });

    test('自动行情不在新鲜集合返回等待更新', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(costAmount: DecimalValue.parse('1000')),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.staleQuote);
    });

    test('无有效成本返回缺少成本', () {
      // 手动金额类(不参与行情判断),无成本也无盈亏。
      final status = deriveHoldingDataStatus(
        fixtureHolding(valuationMethod: ValuationMethod.manualAmount),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.missingCost);
    });

    test('优先级:缺代码与缺成本并存时返回未填写', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(productCode: null),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.incomplete);
    });
  });

  group('单元格缺失文案', () {
    test('份额:手动金额类不适用,行情类缺失暂无行情,有值显示千分位', () {
      expect(
        holdingQuantityText(
          fixtureHolding(valuationMethod: ValuationMethod.manualAmount),
        ),
        '不适用',
      );
      expect(
        holdingQuantityText(
          fixtureHolding(
            valuationMethod: ValuationMethod.quantityTimesPrice,
            noQuantity: true,
          ),
        ),
        '暂无行情',
      );
      expect(
        holdingQuantityText(
          fixtureHolding(valuationMethod: ValuationMethod.quantityTimesPrice),
        ),
        '1,000',
      );
    });

    test('覆盖成本:null 显示缺少成本,否则千分位金额', () {
      expect(holdingCostText(fixtureHolding()), '缺少成本');
      expect(
        holdingCostText(fixtureHolding(costAmount: DecimalValue.parse('12345.6'))),
        '12,345.60',
      );
    });

    test('持仓盈亏:无成本显示缺少成本,有盈亏带符号', () {
      expect(holdingProfitText(fixtureHolding()), '缺少成本');
      expect(
        holdingProfitText(
          fixtureHolding(
            costAmount: DecimalValue.parse('1000'),
            holdingProfit: DecimalValue.parse('-25.5'),
          ),
        ),
        '-25.50',
      );
    });

    test('持仓收益率:无成本显示缺少成本,有收益率带符号百分号', () {
      expect(holdingReturnText(fixtureHolding()), '缺少成本');
      expect(
        holdingReturnText(
          fixtureHolding(
            costAmount: DecimalValue.parse('1000'),
            holdingReturn: DecimalValue.parse('0.125'),
          ),
        ),
        '+12.50%',
      );
      // holdingReturn 为空但有成本与盈亏 → 由 盈亏÷成本 推导。
      expect(
        holdingReturnText(
          fixtureHolding(
            costAmount: DecimalValue.parse('1000'),
            holdingProfit: DecimalValue.parse('100'),
          ),
        ),
        '+10.00%',
      );
    });

    test('估值日期:行情类缺失暂无行情,手动金额类不适用', () {
      expect(
        holdingValuationDateText(fixtureHolding(noDate: true)),
        '暂无行情',
      );
      expect(
        holdingValuationDateText(
          fixtureHolding(
            valuationMethod: ValuationMethod.manualAmount,
            noDate: true,
          ),
        ),
        '不适用',
      );
      expect(
        holdingValuationDateText(fixtureHolding()),
        '2026-07-19',
      );
    });

    test('资产占比:null 不适用,否则百分比', () {
      expect(holdingShareText(null), '不适用');
      expect(holdingShareText(DecimalValue.parse('0.1234')), '12.34%');
    });
  });

  group('HoldingValueFormatter.percent', () {
    test('小数转百分比保留两位', () {
      expect(
        HoldingValueFormatter.percent(DecimalValue.parse('0.5')),
        '50.00%',
      );
      expect(HoldingValueFormatter.percent(null), '—');
    });
  });
}
```

注意：上面有一个 `skip: true` 的占位断言——**删掉它**（连同 `copyWithPlaceholder` 调用），只保留两个有效断言。这是计划自检发现的多余内容，实现时不得保留 skip 用例。

- [ ] **Step 2: Run test to verify it fails**

Run（从 `apps/fundlens_windows` 目录）: `/d/flutter/bin/flutter.bat test test/features/holdings/holding_status_test.dart`
Expected: FAIL — `holding_status.dart` 不存在（编译错误）。

- [ ] **Step 3: Write minimal implementation**

Create `apps/fundlens_windows/lib/features/holdings/holding_status.dart`:

```dart
import 'package:fundlens_core/fundlens_core.dart';

/// 持仓数据状态(数据状态列与筛选器共用)。
///
/// 派生优先级见 [deriveHoldingDataStatus];文案全部使用 muted 文字,
/// 不使用高饱和色块。
enum HoldingDataStatus { incomplete, noQuote, staleQuote, missingCost, normal }

/// 数据状态的中文标签。
const holdingDataStatusLabels = <HoldingDataStatus, String>{
  HoldingDataStatus.incomplete: '未填写',
  HoldingDataStatus.noQuote: '暂无行情',
  HoldingDataStatus.staleQuote: '等待更新',
  HoldingDataStatus.missingCost: '缺少成本',
  HoldingDataStatus.normal: '正常',
};

bool _isQuoteBased(Holding h) {
  return h.valuationMethod == ValuationMethod.automaticQuote ||
      h.valuationMethod == ValuationMethod.quantityTimesPrice;
}

/// 派生单条持仓的数据状态,优先级从上到下(高优先级先命中):
///
/// 1. 未填写:用户提供的必填字段缺失(名称/币种/金额为负/行情类缺代码或份额)。
/// 2. 暂无行情:行情类缺少现价或估值日期(行情侧数据,不归入"未填写")。
/// 3. 等待更新:自动行情持仓不在本次刷新集合中。
/// 4. 缺少成本:无有效成本,无法纳入收益统计。
/// 5. 正常。
HoldingDataStatus deriveHoldingDataStatus(
  Holding holding, {
  required Set<String> freshQuoteHoldingIds,
}) {
  if (holding.productName.trim().isEmpty ||
      holding.currency.trim().isEmpty ||
      holding.currentValue.isNegative) {
    return HoldingDataStatus.incomplete;
  }
  if (holding.valuationMethod == ValuationMethod.automaticQuote &&
      (holding.productCode == null ||
          holding.productCode!.trim().isEmpty ||
          holding.quantity == null)) {
    return HoldingDataStatus.incomplete;
  }
  if (holding.valuationMethod == ValuationMethod.quantityTimesPrice &&
      holding.quantity == null) {
    return HoldingDataStatus.incomplete;
  }
  if (_isQuoteBased(holding) &&
      (holding.currentPrice == null || holding.valuationDate == null)) {
    return HoldingDataStatus.noQuote;
  }
  if (holding.valuationMethod == ValuationMethod.automaticQuote &&
      !freshQuoteHoldingIds.contains(holding.id)) {
    return HoldingDataStatus.staleQuote;
  }
  if (holding.effectiveCostAmount == null) {
    return HoldingDataStatus.missingCost;
  }
  return HoldingDataStatus.normal;
}

/// 持仓的有效收益率:优先取平台值,否则由 盈亏÷有效成本 推导。
DecimalValue? holdingEffectiveReturn(Holding holding) {
  if (holding.holdingReturn != null) return holding.holdingReturn;
  final cost = holding.effectiveCostAmount;
  final profit = holding.currentFloatingProfit;
  if (cost == null || cost.isZero || profit == null) return null;
  return profit.divide(cost);
}

/// 份额单元格文案。
String holdingQuantityText(Holding h) {
  if (h.valuationMethod == ValuationMethod.manualAmount) return '不适用';
  if (h.quantity == null) return '暂无行情';
  return HoldingValueFormatter.number(h.quantity);
}

/// 现价单元格文案。
String holdingPriceText(Holding h) {
  if (h.valuationMethod == ValuationMethod.manualAmount) return '不适用';
  if (h.currentPrice == null) return '暂无行情';
  return HoldingValueFormatter.number(h.currentPrice);
}

/// 覆盖成本单元格文案。
String holdingCostText(Holding h) {
  if (h.costAmount == null) return '缺少成本';
  return HoldingValueFormatter.amount(h.costAmount);
}

/// 持仓盈亏单元格文案(红绿由样式层处理,此处只管数值与符号)。
String holdingProfitText(Holding h) {
  final profit = h.currentFloatingProfit;
  if (profit == null) return '缺少成本';
  return HoldingValueFormatter.signedAmount(profit);
}

/// 持仓收益率单元格文案。
String holdingReturnText(Holding h) {
  final value = holdingEffectiveReturn(h);
  if (value == null) return '缺少成本';
  return HoldingValueFormatter.signedPercent(value);
}

/// 估值日期单元格文案。
String holdingValuationDateText(Holding h) {
  if (h.valuationDate == null) {
    return _isQuoteBased(h) ? '暂无行情' : '不适用';
  }
  return HoldingValueFormatter.date(h.valuationDate);
}

/// 资产占比单元格文案;组合总额为 0 时由调用方传 null。
String holdingShareText(DecimalValue? share) {
  if (share == null) return '不适用';
  return HoldingValueFormatter.percent(share);
}

/// 表格数值格式化。从 holding_grid.dart 原样迁移,并新增 [percent]。
///
/// 行组件不计算金融指标,只渲染 [Holding] 上已有的值。
abstract final class HoldingValueFormatter {
  /// `1234567.8` → `1,234,567.80`;负值保留负号。
  static String amount(DecimalValue? value) {
    if (value == null) return '—';
    return _grouped(value.canonical);
  }

  /// 不带强制小数的千分位数值(份额、价格)。
  static String number(DecimalValue? value) {
    if (value == null) return '—';
    return _grouped(value.canonical);
  }

  /// 带符号百分比:`0.125` → `+12.50%`。始终带 +/-,盈亏不靠颜色区分。
  static String signedPercent(DecimalValue? value) {
    if (value == null) return '—';
    final canonical = value.canonical;
    final parsed = double.tryParse(canonical);
    if (parsed == null) return '—';
    final percent = parsed * 100;
    final sign = percent < 0 ? '-' : '+';
    return '$sign${percent.abs().toStringAsFixed(2)}%';
  }

  /// 无符号百分比(资产占比):`0.1234` → `12.34%`。
  static String percent(DecimalValue? value) {
    if (value == null) return '—';
    final parsed = double.tryParse(value.canonical);
    if (parsed == null) return '—';
    return '${(parsed * 100).toStringAsFixed(2)}%';
  }

  /// 带符号金额(盈亏)。
  static String signedAmount(DecimalValue? value) {
    if (value == null) return '—';
    if (value.isNegative) return amount(value);
    return '+${amount(value)}';
  }

  static String date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toUtc();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _grouped(String canonical) {
    final negative = canonical.startsWith('-');
    final body = negative ? canonical.substring(1) : canonical;
    final dot = body.indexOf('.');
    final integer = dot == -1 ? body : body.substring(0, dot);
    final fraction = dot == -1 ? '' : body.substring(dot);
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      final remaining = integer.length - i;
      buffer.write(integer[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return '${negative ? '-' : ''}$buffer$fraction';
  }
}
```

Modify `apps/fundlens_windows/lib/features/holdings/holding_grid.dart`:
- 删除文件中的 `abstract final class HoldingValueFormatter { ... }` 整块定义（第 14–73 行区域）。
- 在 import 区添加 `import 'holding_status.dart';`。

Modify `apps/fundlens_windows/lib/features/holdings/holding_export_service.dart`:
- 第 7 行 `import 'holding_grid.dart';` 改为 `import 'holding_status.dart';`。

- [ ] **Step 4: Run tests to verify they pass**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/`
Expected: PASS（新 status 测试全过；既有 grid/export/editor/page 测试不受影响——grid 仍从 status 文件拿到同名 formatter）。

- [ ] **Step 5: Commit**

```bash
git add apps/fundlens_windows/lib/features/holdings/holding_status.dart apps/fundlens_windows/lib/features/holdings/holding_grid.dart apps/fundlens_windows/lib/features/holdings/holding_export_service.dart apps/fundlens_windows/test/features/holdings/holding_status_test.dart
git commit -m "feat(holdings): 数据状态派生与缺失文案纯函数(五态优先级/单元格映射/formatter迁移)"
```

---

### Task 2: holding_filters.dart — 筛选/排序/多选状态重构

**Files:**
- Modify: `apps/fundlens_windows/lib/features/holdings/holding_filters.dart`（整体重写）
- Modify: `apps/fundlens_windows/lib/features/holdings/holdings_page.dart`（删除 SegmentedButton 与 preset 引用，最小补丁保持编译）
- Modify: `apps/fundlens_windows/lib/features/holdings/holding_grid.dart`（`HoldingGrid` 删除 preset 参数，`holdingColumnsFor()` 收敛为单列表，最小补丁）
- Modify: `apps/fundlens_windows/test/features/holdings/holding_grid_test.dart`（删除 preset 用例）
- Modify: `apps/fundlens_windows/test/features/holdings/holdings_page_test.dart`（actions 数量断言 3→2）
- Test: `apps/fundlens_windows/test/features/holdings/holding_filters_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `HoldingDataStatus`/`deriveHoldingDataStatus`/`holdingEffectiveReturn`；`filteredHoldingsProvider`/`holdingsProvider`（portfolio_providers.dart）；`freshQuoteHoldingIdsProvider`（app_dependencies.dart）。
- Produces（后续任务依赖）:
  - `enum HoldingSortField { name, currentValue, share, quantity, currentPrice, cost, profit, returnRate, valuationDate }` + `holdingSortFieldLabels`
  - `final class HoldingSort { const HoldingSort(this.field, this.ascending); static const initial; String get label; }`
  - `final class HoldingFilterState`（query/sources/assetClasses/statuses/tags/sort + `hasActiveFilter` + `cleared()`）
  - `holdingFilterProvider`（StateProvider）、`holdingSelectionProvider`（StateProvider<Set<String>>）、`holdingTagOptionsProvider`（List<String>）
  - `visibleHoldingsProvider`（Provider<List<Holding>>）
  - `int Function(Holding, Holding) holdingComparator(HoldingSort sort)`
  - `HoldingLabels`（保持原样导出，勿动）

- [ ] **Step 1: Write the failing test**

Create `apps/fundlens_windows/test/features/holdings/holding_filters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_status.dart';

import '../overview/asset_spectrum_test.dart' show FakeHoldingRepository;

final _now = DateTime.utc(2026, 7, 20);

Holding makeHolding({
  required String id,
  String name = '产品',
  SourcePlatform source = SourcePlatform.alipay,
  AssetClass assetClass = AssetClass.equity,
  DecimalValue? currentValue,
  DecimalValue? quantity,
  DecimalValue? costAmount,
  DecimalValue? holdingProfit,
  ValuationMethod valuationMethod = ValuationMethod.automaticQuote,
  DateTime? valuationDate,
  List<String> platformTags = const [],
  bool noQuantity = false,
}) {
  return Holding(
    id: id,
    sourcePlatform: source,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: name,
    productCode: '110011',
    currency: 'CNY',
    quantity: noQuantity ? null : (quantity ?? DecimalValue.parse('100')),
    currentPrice: DecimalValue.parse('1.0'),
    currentValue: currentValue ?? DecimalValue.parse('100'),
    costAmount: costAmount,
    holdingProfit: holdingProfit,
    valuationMethod: valuationMethod,
    valuationDate: valuationDate ?? _now,
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    platformTags: platformTags,
    createdAt: _now,
    updatedAt: _now,
  );
}

ProviderContainer makeContainer(List<Holding> holdings) {
  return ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(FakeHoldingRepository(holdings)),
    // 默认全部行情新鲜,避免"等待更新"干扰数据状态断言。
    freshQuoteHoldingIdsProvider.overrideWithValue(
      {for (final h in holdings) h.id},
    ),
  ]);
}

void main() {
  group('visibleHoldingsProvider 筛选组合', () {
    test('搜索 + 资产类别 + 来源平台组合过滤', () async {
      final container = makeContainer([
        makeHolding(id: 'a', name: '沪深300', currentValue: DecimalValue.parse('300')),
        makeHolding(id: 'b', name: '中证500', assetClass: AssetClass.fixedIncome),
        makeHolding(id: 'c', name: '沪深增强', source: SourcePlatform.ths),
      ]);
      addTearDown(container.dispose);
      await container.read(holdingsProvider.future);

      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(
        query: '沪深',
        assetClasses: {AssetClass.equity},
        sources: {SourcePlatform.alipay},
      );
      final visible = container.read(visibleHoldingsProvider);
      expect(visible.map((h) => h.id), ['a']);
    });

    test('数据状态筛选:只保留缺少成本的持仓', () async {
      final container = makeContainer([
        makeHolding(id: 'no-cost'),
        makeHolding(id: 'has-cost', costAmount: DecimalValue.parse('50')),
      ]);
      addTearDown(container.dispose);
      await container.read(holdingsProvider.future);

      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(
        statuses: {HoldingDataStatus.missingCost},
      );
      final visible = container.read(visibleHoldingsProvider);
      expect(visible.map((h) => h.id), ['no-cost']);
    });

    test('组合标签筛选:标签命中与未标记', () async {
      final container = makeContainer([
        makeHolding(id: 'tagged', platformTags: const ['工资账户']),
        makeHolding(id: 'untagged'),
      ]);
      addTearDown(container.dispose);
      await container.read(holdingsProvider.future);

      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(tags: {'工资账户'});
      expect(
        container.read(visibleHoldingsProvider).map((h) => h.id),
        ['tagged'],
      );

      // null 元素 = 未标记。
      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(tags: {null});
      expect(
        container.read(visibleHoldingsProvider).map((h) => h.id),
        ['untagged'],
      );
    });

    test('hasActiveFilter 与 cleared:清除筛选保留排序', () {
      const filter = HoldingFilterState(
        query: 'x',
        sort: HoldingSort(HoldingSortField.name, true),
      );
      expect(filter.hasActiveFilter, isTrue);
      final cleared = filter.cleared();
      expect(cleared.hasActiveFilter, isFalse);
      expect(cleared.sort.field, HoldingSortField.name);
      expect(cleared.sort.ascending, isTrue);
      expect(const HoldingFilterState().hasActiveFilter, isFalse);
    });
  });

  group('holdingComparator', () {
    test('当前金额降序(默认),占比序与金额序一致', () {
      final small = makeHolding(id: 's', currentValue: DecimalValue.parse('10'));
      final big = makeHolding(id: 'b', currentValue: DecimalValue.parse('99'));
      final list = [small, big]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.currentValue, false)),
        );
      expect(list.map((h) => h.id), ['b', 's']);
      final byShare = [small, big]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.share, true)),
        );
      expect(byShare.map((h) => h.id), ['s', 'b']);
    });

    test('空值恒排末尾(与方向无关),同值按 id 稳定', () {
      final noQty = makeHolding(id: 'z-none', noQuantity: true);
      final a = makeHolding(id: 'a', quantity: DecimalValue.parse('1'));
      final b = makeHolding(id: 'b', quantity: DecimalValue.parse('2'));
      for (final ascending in [true, false]) {
        final list = [noQty, b, a]..sort(
            holdingComparator(HoldingSort(HoldingSortField.quantity, ascending)),
          );
        expect(list.last.id, 'z-none', reason: 'ascending=$ascending');
      }
      final same1 = makeHolding(id: 'a', quantity: DecimalValue.parse('1'));
      final same2 = makeHolding(id: 'b', quantity: DecimalValue.parse('1'));
      final list = [same2, same1]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.quantity, true)),
        );
      expect(list.map((h) => h.id), ['a', 'b']);
    });

    test('收益率排序:平台值与推导值混合比较', () {
      final platform = makeHolding(
        id: 'p',
        costAmount: DecimalValue.parse('100'),
        holdingProfit: DecimalValue.parse('50'),
      );
      // holdingReturn 为空 → 由 50÷100 推导 0.5。
      final list = [platform]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.returnRate, false)),
        );
      expect(list.single.id, 'p'); // 不抛异常即验证推导路径可比较
    });
  });

  group('holdingTagOptionsProvider', () {
    test('汇总全部持仓标签并去重排序', () async {
      final container = makeContainer([
        makeHolding(id: 'a', platformTags: const ['奖金', '工资']),
        makeHolding(id: 'b', platformTags: const ['工资']),
      ]);
      addTearDown(container.dispose);
      await container.read(holdingsProvider.future);
      expect(container.read(holdingTagOptionsProvider), ['工资', '奖金']);
    });
  });

  test('HoldingSort.label:金额与名称的方向文案', () {
    expect(
      const HoldingSort(HoldingSortField.currentValue, false).label,
      '当前金额 · 从高到低',
    );
    expect(
      const HoldingSort(HoldingSortField.name, true).label,
      '产品名称 · A → Z',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/holding_filters_test.dart`
Expected: FAIL — `HoldingSortField`/`HoldingFilterState(statuses/tags)` 不存在（编译错误）。

- [ ] **Step 3: Write minimal implementation**

Rewrite `apps/fundlens_windows/lib/features/holdings/holding_filters.dart` 全文如下（`HoldingLabels` 与原 `holdingSupportsQuoteRefresh`/`_quoteEligibleTypes` 原样保留在文件尾部，此处省略号部分请从旧文件原样拷贝）:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import 'holding_status.dart';

/// 表头与排序下拉共用的可排序字段。
enum HoldingSortField {
  name,
  currentValue,
  share,
  quantity,
  currentPrice,
  cost,
  profit,
  returnRate,
  valuationDate,
}

/// 排序字段中文标签。
const holdingSortFieldLabels = <HoldingSortField, String>{
  HoldingSortField.name: '产品名称',
  HoldingSortField.currentValue: '当前金额',
  HoldingSortField.share: '资产占比',
  HoldingSortField.quantity: '份额',
  HoldingSortField.currentPrice: '现价',
  HoldingSortField.cost: '覆盖成本',
  HoldingSortField.profit: '持仓盈亏',
  HoldingSortField.returnRate: '持仓收益率',
  HoldingSortField.valuationDate: '估值日期',
};

/// 排序状态:字段 + 方向。默认当前金额降序。
final class HoldingSort {
  const HoldingSort(this.field, this.ascending);

  final HoldingSortField field;
  final bool ascending;

  static const initial = HoldingSort(HoldingSortField.currentValue, false);

  /// 排序下拉与表头共用的展示文案。
  String get label {
    final direction = field == HoldingSortField.name
        ? (ascending ? 'A → Z' : 'Z → A')
        : (ascending ? '从低到高' : '从高到低');
    return '${holdingSortFieldLabels[field]} · $direction';
  }

  @override
  bool operator ==(Object other) {
    return other is HoldingSort &&
        other.field == field &&
        other.ascending == ascending;
  }

  @override
  int get hashCode => Object.hash(field, ascending);
}

/// 持仓页筛选状态。
final class HoldingFilterState {
  const HoldingFilterState({
    this.query = '',
    this.sources = const {},
    this.assetClasses = const {},
    this.statuses = const {},
    this.tags = const {},
    this.sort = HoldingSort.initial,
  });

  final String query;
  final Set<SourcePlatform> sources;
  final Set<AssetClass> assetClasses;
  final Set<HoldingDataStatus> statuses;

  /// 组合标签筛选;元素为 null 表示"未标记"(platformTags 为空的持仓)。
  final Set<String?> tags;
  final HoldingSort sort;

  HoldingFilterState copyWith({
    String? query,
    Set<SourcePlatform>? sources,
    Set<AssetClass>? assetClasses,
    Set<HoldingDataStatus>? statuses,
    Set<String?>? tags,
    HoldingSort? sort,
  }) {
    return HoldingFilterState(
      query: query ?? this.query,
      sources: sources ?? this.sources,
      assetClasses: assetClasses ?? this.assetClasses,
      statuses: statuses ?? this.statuses,
      tags: tags ?? this.tags,
      sort: sort ?? this.sort,
    );
  }

  /// 是否存在任一激活的筛选(不含排序)。
  bool get hasActiveFilter {
    return query.trim().isNotEmpty ||
        sources.isNotEmpty ||
        assetClasses.isNotEmpty ||
        statuses.isNotEmpty ||
        tags.isNotEmpty;
  }

  /// 清除全部筛选,保留排序。
  HoldingFilterState cleared() => HoldingFilterState(sort: sort);
}

/// 持仓页交互筛选状态。
final holdingFilterProvider =
    StateProvider<HoldingFilterState>((ref) => const HoldingFilterState());

/// 多选状态:选中的持仓 id 集合。筛选变化不清空,删除/取消后清空。
final holdingSelectionProvider = StateProvider<Set<String>>((ref) => const {});

/// 全部持仓出现过的组合标签(去重排序);"未标记"由界面层追加。
final holdingTagOptionsProvider = Provider<List<String>>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
  final tags = <String>{for (final h in holdings) ...h.platformTags};
  final sorted = tags.toList()..sort();
  return List.unmodifiable(sorted);
});

/// 排序比较器:空值恒排末尾(与方向无关),同值按 id 稳定次序。
int Function(Holding, Holding) holdingComparator(HoldingSort sort) {
  int sign(int c) => sort.ascending ? c : -c;

  int compareDecimal(DecimalValue? a, DecimalValue? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return sign(a.compareTo(b));
  }

  int compareDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return sign(a.compareTo(b));
  }

  return (a, b) {
    final c = switch (sort.field) {
      HoldingSortField.name => sign(a.productName.compareTo(b.productName)),
      // 同一分母下占比序与金额序一致。
      HoldingSortField.currentValue ||
      HoldingSortField.share =>
        compareDecimal(a.currentValue, b.currentValue),
      HoldingSortField.quantity => compareDecimal(a.quantity, b.quantity),
      HoldingSortField.currentPrice =>
        compareDecimal(a.currentPrice, b.currentPrice),
      HoldingSortField.cost =>
        compareDecimal(a.effectiveCostAmount, b.effectiveCostAmount),
      HoldingSortField.profit =>
        compareDecimal(a.currentFloatingProfit, b.currentFloatingProfit),
      HoldingSortField.returnRate =>
        compareDecimal(holdingEffectiveReturn(a), holdingEffectiveReturn(b)),
      HoldingSortField.valuationDate =>
        compareDate(a.valuationDate, b.valuationDate),
    };
    return c != 0 ? c : a.id.compareTo(b.id);
  };
}

/// 组合筛选(搜索/类别/平台/状态/标签)与排序后的可见持仓。
final visibleHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(filteredHoldingsProvider);
  final filter = ref.watch(holdingFilterProvider);
  final freshIds = ref.watch(freshQuoteHoldingIdsProvider);

  final query = filter.query.trim();
  Iterable<Holding> result = holdings;
  if (query.isNotEmpty) {
    final lower = query.toLowerCase();
    result = result.where((holding) {
      return holding.productName.contains(query) ||
          (holding.productCode?.toLowerCase().contains(lower) ?? false);
    });
  }
  if (filter.sources.isNotEmpty) {
    result = result.where((h) => filter.sources.contains(h.sourcePlatform));
  }
  if (filter.assetClasses.isNotEmpty) {
    result = result.where((h) => filter.assetClasses.contains(h.assetClass));
  }
  if (filter.statuses.isNotEmpty) {
    result = result.where(
      (h) => filter.statuses.contains(
        deriveHoldingDataStatus(h, freshQuoteHoldingIds: freshIds),
      ),
    );
  }
  if (filter.tags.isNotEmpty) {
    result = result.where(
      (h) => h.platformTags.isEmpty
          ? filter.tags.contains(null)
          : h.platformTags.any(filter.tags.contains),
    );
  }

  final sorted = result.toList(growable: false);
  sorted.sort(holdingComparator(filter.sort));
  return List.unmodifiable(sorted);
});

// === 以下内容从旧文件原样保留: ===
// - _quoteEligibleTypes 与 holdingSupportsQuoteRefresh
// - HoldingLabels(sourcePlatform / instrumentType / assetClass /
//   valuationMethod / dataOrigin)
// (原 HoldingColumnPreset 枚举与 preset 字段已删除)
```

**最小补丁保持编译（本任务不重写这两个文件的 UI）:**

`holdings_page.dart`:
- 删除 SegmentedButton 整段（第 46–66 行）。
- `body: HoldingGrid(holdings: holdings, preset: filter.preset)` 改为 `body: HoldingGrid(holdings: holdings)`。
- 删除不再使用的 import（如果 `holding_filters.dart` 中 preset 相关引用消失后产生 unused import，仅清理 analyze 报出的项）。

`holding_grid.dart`:
- `HoldingGrid` 构造函数删除 `this.preset = HoldingColumnPreset.portfolio` 参数与字段。
- `holdingColumnsFor(HoldingColumnPreset preset)` 改为无参 `List<HoldingColumn> holdingColumns()`，返回原 `HoldingColumnPreset.portfolio` 分支的 6 列（份额/现价/成本金额/持仓盈亏/持仓收益率/估值日期）；删除其余两个分支与 `HoldingColumnPreset` 引用（枚举本体已在 filters 文件删除）。
- `_HoldingGridState.build` 中 `holdingColumnsFor(widget.preset)` 改为 `holdingColumns()`。

`holding_grid_test.dart`:
- 删除 `gridHarness` 的 preset 参数与第 104–117 行的 'platform preset shows provenance columns' 用例。
- `HoldingGrid(holdings: holdings, preset: preset)` 改为 `HoldingGrid(holdings: holdings)`。

`holdings_page_test.dart`:
- 第 46 行 `expect(scaffold.actions.length, 3);` 改为 `expect(scaffold.actions.length, 2);`，注释同步改为「搜索框与『添加持仓』按钮位于页头操作区」。

- [ ] **Step 4: Run tests to verify they pass**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/ && /d/flutter/bin/flutter.bat analyze`
Expected: 测试全过；analyze No issues（若报 unused import 按 Step 3 说明清理）。

- [ ] **Step 5: Commit**

```bash
git add apps/fundlens_windows/lib/features/holdings/ apps/fundlens_windows/test/features/holdings/
git commit -m "feat(holdings): 筛选状态重构——四筛选+九字段排序+多选状态,删除列预设"
```

---

### Task 3: holding_grid.dart — 13 列 flex 表格重构（排序表头/复选框/行交互）

**Files:**
- Modify: `apps/fundlens_windows/lib/features/holdings/holding_grid.dart`（整体重写）
- Modify: `apps/fundlens_windows/lib/features/holdings/holdings_page.dart`（接线新参数，最小补丁）
- Test: `apps/fundlens_windows/test/features/holdings/holding_grid_test.dart`（整体重写）

**Interfaces:**
- Consumes: Task 1 的 `HoldingValueFormatter`/单元格文案函数/`holdingDataStatusLabels`/`deriveHoldingDataStatus`；Task 2 的 `HoldingSort`/`HoldingSortField`/`holdingFilterProvider`/`holdingSelectionProvider`/`visibleHoldingsProvider`；`portfolioSummaryProvider`（totalValue）；`freshQuoteHoldingIdsProvider`。
- Produces（后续任务依赖）:
  - `final class HoldingCellContext { const HoldingCellContext({required this.holding, required this.totalValue, required this.freshQuoteHoldingIds}); DecimalValue? get share; }`
  - `final class HoldingColumnSpec { label, minWidth, flex, numeric, sortField, value }`
  - `List<HoldingColumnSpec> holdingColumnSpecs()`
  - `final class HoldingColumnLayout { nameWidth, columnWidths, scrollable }`
  - `HoldingColumnLayout resolveHoldingColumnLayout(double availableWidth)`
  - `class HoldingGrid extends StatefulWidget`（参数见下）
  - 常量 `kHoldingCheckboxWidth = 40`、`kHoldingNameMinWidth = 200`

**HoldingGrid 参数（全部必传，由页面接线）:**

```dart
const HoldingGrid({
  super.key,
  required this.holdings,           // 可见持仓(已筛选排序)
  required this.totalValue,         // 组合总资产(占比分母)
  required this.freshQuoteHoldingIds,
  required this.sort,               // 当前排序
  required this.onSortChanged,      // 表头点击回调
  required this.selectedIds,        // 多选集合
  required this.onSelectedChanged,  // (String id, bool selected)
  required this.onSelectAllChanged, // (bool selectAll)
  required this.onRowTap,           // 行点击(打开抽屉),null 时行不可点击
});
```

- [ ] **Step 1: Write the failing test**

Rewrite `apps/fundlens_windows/test/features/holdings/holding_grid_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_grid.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final _now = DateTime.utc(2026, 7, 1);

Holding gridHolding({
  required String id,
  String name = '产品',
  DecimalValue? currentValue,
  DecimalValue? quantity,
  DecimalValue? currentPrice,
  DecimalValue? costAmount,
  DecimalValue? holdingProfit,
  ValuationMethod valuationMethod = ValuationMethod.automaticQuote,
  DateTime? valuationDate,
  bool noPrice = false,
  bool noDate = false,
}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: name,
    productCode: '110011',
    currency: 'CNY',
    quantity: quantity ?? DecimalValue.parse('1000'),
    currentPrice: noPrice ? null : (currentPrice ?? DecimalValue.parse('1.5')),
    currentValue: currentValue ?? DecimalValue.parse('1500'),
    costAmount: costAmount,
    holdingProfit: holdingProfit,
    valuationMethod: valuationMethod,
    valuationDate: noDate ? null : (valuationDate ?? _now),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

List<Holding> generateGridHoldings(int count) {
  return [
    for (var i = 0; i < count; i++)
      gridHolding(
        id: 'h-$i',
        name: '产品${i.toString().padLeft(4, '0')}',
        currentValue: DecimalValue.parse('${1000 + i}'),
      ),
  ];
}

class GridHarness extends StatefulWidget {
  const GridHarness({
    super.key,
    required this.holdings,
    this.totalValue,
    this.onRowTap,
  });

  final List<Holding> holdings;
  final DecimalValue? totalValue;
  final void Function(Holding holding)? onRowTap;

  @override
  State<GridHarness> createState() => _GridHarnessState();
}

class _GridHarnessState extends State<GridHarness> {
  HoldingSort _sort = HoldingSort.initial;
  Set<String> _selected = const {};

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: FundLensTheme.light,
      home: Scaffold(
        body: HoldingGrid(
          holdings: widget.holdings,
          totalValue: widget.totalValue ?? DecimalValue.parse('100000'),
          freshQuoteHoldingIds: {for (final h in widget.holdings) h.id},
          sort: _sort,
          onSortChanged: (sort) => setState(() => _sort = sort),
          selectedIds: _selected,
          onSelectedChanged: (id, selected) => setState(() {
            _selected = {..._selected}
              ..remove(id)
              ..addAll(selected ? [id] : const <String>[]);
          }),
          onSelectAllChanged: (all) => setState(() {
            _selected =
                all ? {for (final h in widget.holdings) h.id} : const <String>{};
          }),
          onRowTap: widget.onRowTap,
        ),
      ),
    );
  }
}

Future<void> pumpGrid(
  WidgetTester tester, {
  required List<Holding> holdings,
  Size size = const Size(1440, 900),
  DecimalValue? totalValue,
  void Function(Holding holding)? onRowTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GridHarness(
    holdings: holdings,
    totalValue: totalValue,
    onRowTap: onRowTap,
  ));
  await tester.pump();
}

void main() {
  group('列宽分配 resolveHoldingColumnLayout', () {
    test('宽容器:列分满宽度且不滚动', () {
      final layout = resolveHoldingColumnLayout(1600);
      expect(layout.scrollable, isFalse);
      final total = kHoldingCheckboxWidth +
          layout.nameWidth +
          layout.columnWidths.fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1600, 0.01));
      expect(layout.columnWidths.length, 11);
    });

    test('窄容器:取最小宽度并横向滚动', () {
      final layout = resolveHoldingColumnLayout(700);
      expect(layout.scrollable, isTrue);
      expect(layout.nameWidth, kHoldingNameMinWidth);
    });
  });

  group('表格渲染', () {
    testWidgets('表头含全部 12 个字段', (tester) async {
      await pumpGrid(tester, holdings: generateGridHoldings(3));
      for (final label in [
        '产品名称', '资产类别', '来源平台', '当前金额', '资产占比', '份额',
        '现价', '覆盖成本', '持仓盈亏', '持仓收益率', '估值日期', '数据状态',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('1920 宽度无溢出,数据状态列可见', (tester) async {
      await pumpGrid(
        tester,
        holdings: generateGridHoldings(5),
        size: const Size(1920, 1080),
      );
      expect(find.text('数据状态'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1280 宽度可横向滚动,名称列固定', (tester) async {
      await pumpGrid(
        tester,
        holdings: generateGridHoldings(5),
        size: const Size(1280, 720),
      );
      expect(find.text('产品0000'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('holding-grid-hscroll')),
        const Offset(-600, 0),
      );
      await tester.pump();
      // 横向滚动后名称列(冻结区)仍然可见。
      expect(find.text('产品0000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2000 行只构建少量行组件(虚拟滚动)', (tester) async {
      await pumpGrid(
        tester,
        holdings: generateGridHoldings(2000),
        size: const Size(1280, 720),
      );
      expect(
        tester.widgetList(find.byType(HoldingGridRowView)).length,
        lessThan(100),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('缺失数据文案', () {
    testWidgets('缺成本/不适用/暂无行情分行显示', (tester) async {
      await pumpGrid(tester, holdings: [
        // 无成本 → 覆盖成本/盈亏/收益率 缺少成本。
        gridHolding(id: 'a', name: '无成本产品'),
        // 手动金额类 → 份额/现价 不适用。
        gridHolding(
          id: 'b',
          name: '手动产品',
          valuationMethod: ValuationMethod.manualAmount,
        ),
        // 行情类缺价 → 现价 暂无行情,数据状态 暂无行情。
        gridHolding(id: 'c', name: '缺价产品', noPrice: true),
      ]);
      expect(find.text('缺少成本'), findsWidgets);
      expect(find.text('不适用'), findsWidgets);
      expect(find.text('暂无行情'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('组合总额为 0 时占比显示不适用', (tester) async {
      await pumpGrid(
        tester,
        holdings: [gridHolding(id: 'a')],
        totalValue: DecimalValue.zero,
      );
      expect(find.text('不适用'), findsOneWidget);
    });
  });

  group('排序表头', () {
    testWidgets('点击当前金额表头:降序→升序→默认三态循环', (tester) async {
      await pumpGrid(tester, holdings: [
        gridHolding(
          id: 'small', name: '小额', currentValue: DecimalValue.parse('10')),
        gridHolding(
          id: 'big', name: '大额', currentValue: DecimalValue.parse('99')),
      ]);
      // 默认当前金额降序:大额在上。
      expect(
        tester.getTopLeft(find.text('大额')).dy,
        lessThan(tester.getTopLeft(find.text('小额')).dy),
      );
      // 第一次点击:反转为升序。
      await tester.tap(find.byKey(const ValueKey('sort-currentValue')));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('小额')).dy,
        lessThan(tester.getTopLeft(find.text('大额')).dy),
      );
      // 第二次点击:回到默认(降序)。
      await tester.tap(find.byKey(const ValueKey('sort-currentValue')));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('大额')).dy,
        lessThan(tester.getTopLeft(find.text('小额')).dy),
      );
    });

    testWidgets('点击名称表头:按名称升序', (tester) async {
      await pumpGrid(tester, holdings: [
        gridHolding(id: 'a', name: '乙产品'),
        gridHolding(id: 'b', name: '甲产品'),
      ]);
      await tester.tap(find.byKey(const ValueKey('sort-name')));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('甲产品')).dy,
        lessThan(tester.getTopLeft(find.text('乙产品')).dy),
      );
    });
  });

  group('复选框与行交互', () {
    testWidgets('表头全选/取消全选', (tester) async {
      await pumpGrid(tester, holdings: generateGridHoldings(3));
      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pump();
      for (final h in generateGridHoldings(3)) {
        final checkbox = tester.widget<Checkbox>(
          find.byKey(ValueKey('select-${h.id}')),
        );
        expect(checkbox.value, isTrue);
      }
      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pump();
      final first = tester.widget<Checkbox>(
        find.byKey(const ValueKey('select-h-0')),
      );
      expect(first.value, isFalse);
    });

    testWidgets('行点击触发 onRowTap,复选框点击不触发', (tester) async {
      Holding? tapped;
      await pumpGrid(
        tester,
        holdings: [gridHolding(id: 'a', name: '目标产品')],
        onRowTap: (h) => tapped = h,
      );
      await tester.tap(find.text('目标产品'));
      await tester.pump();
      expect(tapped?.id, 'a');

      tapped = null;
      await tester.tap(find.byKey(const ValueKey('select-a')));
      await tester.pump();
      expect(tapped, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/holding_grid_test.dart`
Expected: FAIL — `resolveHoldingColumnLayout`/`HoldingGridRowView`/新参数不存在（编译错误）。

- [ ] **Step 3: Write minimal implementation**

Rewrite `apps/fundlens_windows/lib/features/holdings/holding_grid.dart` 全文:

```dart
import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'holding_filters.dart';
import 'holding_status.dart';

/// 复选框列宽。
const double kHoldingCheckboxWidth = 40;

/// 产品名称列最小宽度。
const double kHoldingNameMinWidth = 200;

/// 名称列的 flex 权重(与滚动区列共享剩余空间)。
const double _kNameFlex = 2;

/// 单元格上下文:持仓 + 组合总额 + 新鲜行情集合。
final class HoldingCellContext {
  const HoldingCellContext({
    required this.holding,
    required this.totalValue,
    required this.freshQuoteHoldingIds,
  });

  final Holding holding;
  final DecimalValue totalValue;
  final Set<String> freshQuoteHoldingIds;

  /// 资产占比;组合总额为 0 时为 null(显示"不适用")。
  DecimalValue? get share {
    if (totalValue.isZero) return null;
    return holding.currentValue.divide(totalValue);
  }
}

/// 滚动区列定义:标签、最小宽度、flex 权重、对齐与取值函数。
final class HoldingColumnSpec {
  const HoldingColumnSpec({
    required this.label,
    required this.minWidth,
    required this.flex,
    required this.numeric,
    required this.value,
    this.sortField,
  });

  final String label;
  final double minWidth;
  final double flex;
  final bool numeric;
  final String Function(HoldingCellContext ctx) value;
  final HoldingSortField? sortField;
}

/// 11 个滚动区列(复选框与产品名称在冻结区)。
List<HoldingColumnSpec> holdingColumnSpecs() {
  String assetClass(HoldingCellContext c) =>
      HoldingLabels.assetClass[c.holding.assetClass]!;
  String platform(HoldingCellContext c) =>
      HoldingLabels.sourcePlatform[c.holding.sourcePlatform]!;
  String amount(HoldingCellContext c) =>
      HoldingValueFormatter.amount(c.holding.currentValue);
  String share(HoldingCellContext c) => holdingShareText(c.share);
  String quantity(HoldingCellContext c) => holdingQuantityText(c.holding);
  String price(HoldingCellContext c) => holdingPriceText(c.holding);
  String cost(HoldingCellContext c) => holdingCostText(c.holding);
  String profit(HoldingCellContext c) => holdingProfitText(c.holding);
  String returnRate(HoldingCellContext c) => holdingReturnText(c.holding);
  String date(HoldingCellContext c) => holdingValuationDateText(c.holding);
  String status(HoldingCellContext c) => holdingDataStatusLabels[
      deriveHoldingDataStatus(
        c.holding,
        freshQuoteHoldingIds: c.freshQuoteHoldingIds,
      )]!;

  return [
    HoldingColumnSpec(
      label: '资产类别', minWidth: 88, flex: 1, numeric: false,
      value: assetClass,
    ),
    HoldingColumnSpec(
      label: '来源平台', minWidth: 96, flex: 1, numeric: false,
      value: platform,
    ),
    HoldingColumnSpec(
      label: '当前金额', minWidth: 120, flex: 1.2, numeric: true,
      value: amount, sortField: HoldingSortField.currentValue,
    ),
    HoldingColumnSpec(
      label: '资产占比', minWidth: 96, flex: 1, numeric: true,
      value: share, sortField: HoldingSortField.share,
    ),
    HoldingColumnSpec(
      label: '份额', minWidth: 110, flex: 1, numeric: true,
      value: quantity, sortField: HoldingSortField.quantity,
    ),
    HoldingColumnSpec(
      label: '现价', minWidth: 100, flex: 1, numeric: true,
      value: price, sortField: HoldingSortField.currentPrice,
    ),
    HoldingColumnSpec(
      label: '覆盖成本', minWidth: 120, flex: 1.2, numeric: true,
      value: cost, sortField: HoldingSortField.cost,
    ),
    HoldingColumnSpec(
      label: '持仓盈亏', minWidth: 120, flex: 1.2, numeric: true,
      value: profit, sortField: HoldingSortField.profit,
    ),
    HoldingColumnSpec(
      label: '持仓收益率', minWidth: 110, flex: 1, numeric: true,
      value: returnRate, sortField: HoldingSortField.returnRate,
    ),
    HoldingColumnSpec(
      label: '估值日期', minWidth: 104, flex: 1, numeric: false,
      value: date, sortField: HoldingSortField.valuationDate,
    ),
    HoldingColumnSpec(
      label: '数据状态', minWidth: 96, flex: 1, numeric: false,
      value: status,
    ),
  ];
}

/// 一次布局解析的结果:名称列宽、各滚动列宽、是否横向滚动。
final class HoldingColumnLayout {
  const HoldingColumnLayout({
    required this.nameWidth,
    required this.columnWidths,
    required this.scrollable,
  });

  final double nameWidth;
  final List<double> columnWidths;
  final bool scrollable;

  /// 滚动区内容总宽。
  double get scrollContentWidth =>
      columnWidths.fold<double>(0, (a, b) => a + b);
}

/// 列宽分配:容器超出各列最小宽度总和时按 flex 权重分满;
/// 不足时取最小宽度并横向滚动。
HoldingColumnLayout resolveHoldingColumnLayout(double availableWidth) {
  final specs = holdingColumnSpecs();
  final mins = [for (final c in specs) c.minWidth];
  final minScroll = mins.fold<double>(0, (a, b) => a + b);
  final minTotal = kHoldingCheckboxWidth + kHoldingNameMinWidth + minScroll;
  if (availableWidth <= minTotal) {
    return HoldingColumnLayout(
      nameWidth: kHoldingNameMinWidth,
      columnWidths: mins,
      scrollable: true,
    );
  }
  final leftover = availableWidth - minTotal;
  final flexSum = _kNameFlex + specs.fold<double>(0, (s, c) => s + c.flex);
  return HoldingColumnLayout(
    nameWidth: kHoldingNameMinWidth + leftover * (_kNameFlex / flexSum),
    columnWidths: [
      for (final c in specs) c.minWidth + leftover * (c.flex / flexSum),
    ],
    scrollable: false,
  );
}

/// 虚拟化双区持仓表格:冻结区(复选框+产品名称) + 横向滚动区(11 列)。
///
/// 布局由 [resolveHoldingColumnLayout] 一次解析,表头与两区行共用,
/// 保证列对齐;垂直滚动由两个 ListView 经重入保护同步。
class HoldingGrid extends StatefulWidget {
  const HoldingGrid({
    super.key,
    required this.holdings,
    required this.totalValue,
    required this.freshQuoteHoldingIds,
    required this.sort,
    required this.onSortChanged,
    required this.selectedIds,
    required this.onSelectedChanged,
    required this.onSelectAllChanged,
    required this.onRowTap,
  });

  final List<Holding> holdings;
  final DecimalValue totalValue;
  final Set<String> freshQuoteHoldingIds;
  final HoldingSort sort;
  final void Function(HoldingSort sort) onSortChanged;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelectedChanged;
  final void Function(bool selectAll) onSelectAllChanged;
  final void Function(Holding holding)? onRowTap;

  @override
  State<HoldingGrid> createState() => _HoldingGridState();
}

class _HoldingGridState extends State<HoldingGrid> {
  final ScrollController _frozenController = ScrollController();
  final ScrollController _detailController = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _frozenController.addListener(
      () => _sync(_frozenController, _detailController),
    );
    _detailController.addListener(
      () => _sync(_detailController, _frozenController),
    );
  }

  void _sync(ScrollController source, ScrollController target) {
    if (_syncing || !target.hasClients || !source.hasClients) return;
    final offset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - offset).abs() < 0.5) return;
    _syncing = true;
    try {
      target.jumpTo(offset);
    } finally {
      _syncing = false;
    }
  }

  /// 表头点击的三态循环:
  /// 未激活 → 首态(数字列降序,名称升序);首态 → 反向;反向 → 默认。
  void _cycleSort(HoldingSortField field) {
    final sort = widget.sort;
    final firstAscending = field == HoldingSortField.name;
    if (sort.field != field) {
      widget.onSortChanged(HoldingSort(field, firstAscending));
      return;
    }
    if (sort.ascending == firstAscending) {
      widget.onSortChanged(HoldingSort(field, !firstAscending));
    } else {
      widget.onSortChanged(HoldingSort.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.holdings.isEmpty) {
      return const SizedBox.shrink();
    }
    final specs = holdingColumnSpecs();
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = resolveHoldingColumnLayout(constraints.maxWidth);
        final frozenWidth = kHoldingCheckboxWidth + layout.nameWidth;
        final scrollRegionWidth = constraints.maxWidth - frozenWidth;
        final contentWidth =
            layout.scrollable ? layout.scrollContentWidth : scrollRegionWidth;
        return DecoratedBox(
          decoration: const BoxDecoration(color: FundLensTokens.surface),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 冻结区:复选框 + 产品名称。
              SizedBox(
                width: frozenWidth,
                child: Column(
                  children: [
                    _FrozenHeader(
                      nameWidth: layout.nameWidth,
                      sort: widget.sort,
                      onSortTap: _cycleSort,
                      selectedIds: widget.selectedIds,
                      holdings: widget.holdings,
                      onSelectAllChanged: widget.onSelectAllChanged,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        key: const ValueKey('holding-grid-frozen'),
                        controller: _frozenController,
                        itemExtent: FundLensTokens.rowHeight,
                        itemCount: widget.holdings.length,
                        itemBuilder: (context, index) {
                          final holding = widget.holdings[index];
                          return HoldingGridFrozenRow(
                            key: ValueKey('frozen-${holding.id}'),
                            holding: holding,
                            nameWidth: layout.nameWidth,
                            selected: widget.selectedIds.contains(holding.id),
                            onSelectedChanged: widget.onSelectedChanged,
                            onTap: widget.onRowTap == null
                                ? null
                                : () => widget.onRowTap!(holding),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // 横向滚动区:11 列。
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('holding-grid-hscroll'),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      children: [
                        _DetailHeader(
                          specs: specs,
                          widths: layout.columnWidths,
                          sort: widget.sort,
                          onSortTap: _cycleSort,
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            key: const ValueKey('holding-grid-detail'),
                            controller: _detailController,
                            itemExtent: FundLensTokens.rowHeight,
                            itemCount: widget.holdings.length,
                            itemBuilder: (context, index) {
                              final holding = widget.holdings[index];
                              return HoldingGridRowView(
                                key: ValueKey('detail-${holding.id}'),
                                specs: specs,
                                widths: layout.columnWidths,
                                cellContext: HoldingCellContext(
                                  holding: holding,
                                  totalValue: widget.totalValue,
                                  freshQuoteHoldingIds:
                                      widget.freshQuoteHoldingIds,
                                ),
                                selected:
                                    widget.selectedIds.contains(holding.id),
                                onTap: widget.onRowTap == null
                                    ? null
                                    : () => widget.onRowTap!(holding),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 冻结区表头:全选复选框 + 可排序的"产品名称"。
class _FrozenHeader extends StatelessWidget {
  const _FrozenHeader({
    required this.nameWidth,
    required this.sort,
    required this.onSortTap,
    required this.selectedIds,
    required this.holdings,
    required this.onSelectAllChanged,
  });

  final double nameWidth;
  final HoldingSort sort;
  final void Function(HoldingSortField field) onSortTap;
  final Set<String> selectedIds;
  final List<Holding> holdings;
  final void Function(bool selectAll) onSelectAllChanged;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        holdings.isNotEmpty && selectedIds.length == holdings.length;
    final someSelected = selectedIds.isNotEmpty && !allSelected;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: kHoldingCheckboxWidth,
            child: Center(
              child: Checkbox(
                key: const ValueKey('select-all'),
                tristate: true,
                value: allSelected ? true : (someSelected ? null : false),
                onChanged: (value) => onSelectAllChanged(value ?? false),
              ),
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: _SortHeaderCell(
              label: '产品名称',
              field: HoldingSortField.name,
              sort: sort,
              numeric: false,
              active: sort.field == HoldingSortField.name,
              onTap: () => onSortTap(HoldingSortField.name),
            ),
          ),
        ],
      ),
    );
  }
}

/// 滚动区表头。
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.specs,
    required this.widths,
    required this.sort,
    required this.onSortTap,
  });

  final List<HoldingColumnSpec> specs;
  final List<double> widths;
  final HoldingSort sort;
  final void Function(HoldingSortField field) onSortTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < specs.length; i++)
            SizedBox(
              width: widths[i],
              child: specs[i].sortField == null
                  ? _PlainHeaderCell(
                      label: specs[i].label,
                      numeric: specs[i].numeric,
                    )
                  : _SortHeaderCell(
                      label: specs[i].label,
                      field: specs[i].sortField!,
                      sort: sort,
                      numeric: specs[i].numeric,
                      active: sort.field == specs[i].sortField,
                      onTap: () => onSortTap(specs[i].sortField!),
                    ),
            ),
        ],
      ),
    );
  }
}

class _PlainHeaderCell extends StatelessWidget {
  const _PlainHeaderCell({required this.label, required this.numeric});

  final String label;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// 可排序表头单元格:箭头指示方向,InkWell 可聚焦(键盘 Enter 触发)。
class _SortHeaderCell extends StatelessWidget {
  const _SortHeaderCell({
    required this.label,
    required this.field,
    required this.sort,
    required this.numeric,
    required this.active,
    required this.onTap,
  });

  final String label;
  final HoldingSortField field;
  final HoldingSort sort;
  final bool numeric;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('sort-${field.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
        child: Row(
          mainAxisAlignment:
              numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (active)
              Icon(
                sort.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: FundLensTokens.accent,
              ),
          ],
        ),
      ),
    );
  }
}

/// 冻结区行:复选框 + 产品名称(含代码副行)。
class HoldingGridFrozenRow extends StatelessWidget {
  const HoldingGridFrozenRow({
    super.key,
    required this.holding,
    required this.nameWidth,
    required this.selected,
    required this.onSelectedChanged,
    required this.onTap,
  });

  final Holding holding;
  final double nameWidth;
  final bool selected;
  final void Function(String id, bool selected) onSelectedChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _RowFrame(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: kHoldingCheckboxWidth,
            child: Center(
              child: Checkbox(
                key: ValueKey('select-${holding.id}'),
                value: selected,
                onChanged: (value) =>
                    onSelectedChanged(holding.id, value ?? false),
              ),
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FundLensTokens.space3,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (holding.productCode != null)
                    Text(
                      holding.productCode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 滚动区行:11 列单元格。
class HoldingGridRowView extends StatelessWidget {
  const HoldingGridRowView({
    super.key,
    required this.specs,
    required this.widths,
    required this.cellContext,
    required this.selected,
    required this.onTap,
  });

  final List<HoldingColumnSpec> specs;
  final List<double> widths;
  final HoldingCellContext cellContext;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financial = theme.extension<FundLensTextStyles>()!.financialNumber;
    return _RowFrame(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          for (var i = 0; i < specs.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FundLensTokens.space3,
                ),
                child: Text(
                  specs[i].value(cellContext),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign:
                      specs[i].numeric ? TextAlign.right : TextAlign.left,
                  style: specs[i].numeric
                      ? financial
                      : theme.textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 行外框:选中底色、hover 反馈、点击;整行可聚焦(Enter 等效点击)。
class _RowFrame extends StatelessWidget {
  const _RowFrame({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? FundLensTokens.accentSoft : FundLensTokens.surface,
      child: InkWell(
        onTap: onTap,
        hoverColor: FundLensTokens.canvas,
        focusColor: FundLensTokens.canvas,
        child: SizedBox(height: FundLensTokens.rowHeight, child: child),
      ),
    );
  }
}
```

**holdings_page.dart 接线补丁（保持页面可用，完整重组在 Task 7）:**
- `body: HoldingGrid(holdings: holdings)` 改为接线版：

```dart
      body: HoldingGrid(
        holdings: holdings,
        totalValue: ref.watch(portfolioSummaryProvider).totalValue,
        freshQuoteHoldingIds: ref.watch(freshQuoteHoldingIdsProvider),
        sort: filter.sort,
        onSortChanged: (sort) =>
            ref.read(holdingFilterProvider.notifier).state =
                filter.copyWith(sort: sort),
        selectedIds: ref.watch(holdingSelectionProvider),
        onSelectedChanged: (id, selected) {
          final current = ref.read(holdingSelectionProvider);
          ref.read(holdingSelectionProvider.notifier).state = {...current}
            ..remove(id)
            ..addAll(selected ? [id] : const <String>[]);
        },
        onSelectAllChanged: (all) {
          ref.read(holdingSelectionProvider.notifier).state =
              all ? {for (final h in holdings) h.id} : const <String>{};
        },
        onRowTap: null, // Task 5 接入详情抽屉
      ),
```
- 补充 import：`portfolio_providers.dart`（portfolioSummaryProvider）与 `app_dependencies.dart`（freshQuoteHoldingIdsProvider）；清理 analyze 报出的 unused import。
- **测试同步补丁**：`holdings_page_test.dart` 的 `pumpHoldings` overrides 列表追加 `portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator())`（页面开始 watch portfolioSummaryProvider，其默认实现会抛 UnimplementedError）；import 相应增加 `fundlens_core` 与 `app_dependencies.dart` 已有项。

- [ ] **Step 4: Run tests to verify they pass**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/ && /d/flutter/bin/flutter.bat analyze`
Expected: 测试全过（含旧 page/editor/export 测试）；analyze No issues。

- [ ] **Step 5: Commit**

```bash
git add apps/fundlens_windows/lib/features/holdings/ apps/fundlens_windows/test/features/holdings/
git commit -m "feat(holdings): 表格重构——13列flex列宽/排序表头/复选框/行点击/缺失文案接线"
```

---

### Task 4: holding_toolbar.dart — 工具栏组件（搜索/4 筛选下拉/排序下拉）

**Files:**
- Create: `apps/fundlens_windows/lib/features/holdings/holding_toolbar.dart`
- Modify: `apps/fundlens_windows/lib/features/holdings/holdings_page.dart`（actions 接线，最小补丁）
- Modify: `apps/fundlens_windows/test/features/holdings/holdings_page_test.dart`（actions 数量断言 2→7）
- Test: `apps/fundlens_windows/test/features/holdings/holding_toolbar_test.dart`

**Interfaces:**
- Consumes: Task 2 的 `HoldingSort`/`HoldingSortField`/`holdingSortFieldLabels`/`HoldingFilterState`；Task 1 的 `HoldingDataStatus`/`holdingDataStatusLabels`；`HoldingLabels`。
- Produces（Task 7 依赖）:
  - `Set<T> toggled<T>(Set<T> set, T value)`
  - `String filterButtonSummary({required String label, required String shortLabel, required List<String> selectedLabels})`
  - `class HoldingSearchField extends StatefulWidget`（`{required String query, required ValueChanged<String> onChanged}`）
  - `class HoldingFilterDropdown<T> extends StatelessWidget`（`{required String label, required String shortLabel, required List<(T, String)> options, required Set<T> selected, required void Function(T value) onToggled}`）
  - `class HoldingSortMenu extends StatelessWidget`（`{required HoldingSort sort, required ValueChanged<HoldingSort> onSelected}`）

- [ ] **Step 1: Write the failing test**

Create `apps/fundlens_windows/test/features/holdings/holding_toolbar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_toolbar.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

Widget harness(Widget child) {
  return MaterialApp(
    theme: FundLensTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('filterButtonSummary', () {
    test('未选中显示完整标签', () {
      expect(
        filterButtonSummary(label: '资产类别', shortLabel: '类别', selectedLabels: const []),
        '资产类别',
      );
    });
    test('选中 1 项显示短标签与值', () {
      expect(
        filterButtonSummary(label: '资产类别', shortLabel: '类别', selectedLabels: const ['权益']),
        '类别:权益',
      );
    });
    test('选中多项显示首值加计数', () {
      expect(
        filterButtonSummary(label: '资产类别', shortLabel: '类别', selectedLabels: const ['权益', '固收']),
        '类别:权益+1',
      );
    });
  });

  group('toggled', () {
    test('添加与移除', () {
      expect(toggled(<String>{}, 'a'), {'a'});
      expect(toggled(<String>{'a'}, 'a'), <String>{});
      expect(toggled(<String>{'a', 'b'}, 'a'), {'b'});
    });
  });

  group('HoldingFilterDropdown', () {
    testWidgets('未选中显示标签,点击条目触发 onToggled 且菜单保持打开', (tester) async {
      String? toggledValue;
      await tester.pumpWidget(harness(
        HoldingFilterDropdown<AssetClass>(
          label: '资产类别',
          shortLabel: '类别',
          options: const [(AssetClass.equity, '权益'), (AssetClass.gold, '黄金')],
          selected: const {},
          onToggled: (v) => toggledValue = v.name,
        ),
      ));
      expect(find.text('资产类别'), findsOneWidget);

      await tester.tap(find.text('资产类别'));
      await tester.pumpAndSettle();
      expect(find.text('权益'), findsOneWidget);

      await tester.tap(find.text('权益'));
      await tester.pump();
      expect(toggledValue, 'equity');
      // 多选菜单点击后不自动关闭。
      expect(find.text('黄金'), findsOneWidget);
    });

    testWidgets('选中态显示摘要文本', (tester) async {
      await tester.pumpWidget(harness(
        HoldingFilterDropdown<AssetClass>(
          label: '资产类别',
          shortLabel: '类别',
          options: const [(AssetClass.equity, '权益'), (AssetClass.gold, '黄金')],
          selected: const {AssetClass.equity, AssetClass.gold},
          onToggled: (_) {},
        ),
      ));
      expect(find.text('类别:权益+1'), findsOneWidget);
    });
  });

  group('HoldingSortMenu', () {
    testWidgets('按钮显示当前排序,菜单选择触发 onSelected', (tester) async {
      HoldingSort? chosen;
      await tester.pumpWidget(harness(
        HoldingSortMenu(
          sort: HoldingSort.initial,
          onSelected: (s) => chosen = s,
        ),
      ));
      expect(find.text('当前金额 · 从高到低'), findsOneWidget);

      await tester.tap(find.text('当前金额 · 从高到低'));
      await tester.pumpAndSettle();
      // 9 字段 × 2 方向 = 18 项。
      expect(find.text('持仓盈亏 · 从低到高'), findsOneWidget);
      await tester.tap(find.text('持仓盈亏 · 从低到高'));
      await tester.pumpAndSettle();
      expect(chosen?.field, HoldingSortField.profit);
      expect(chosen?.ascending, isTrue);
    });
  });

  group('HoldingSearchField', () {
    testWidgets('输入触发 onChanged;外部 query 清空时输入框同步', (tester) async {
      var query = '';
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return harness(
              HoldingSearchField(query: query, onChanged: (v) => query = v),
            );
          },
        ),
      );
      await tester.enterText(find.byType(TextField), '沪深');
      expect(query, '沪深');

      // 外部状态清空(清除筛选) → 输入框文本同步清空。
      rebuild(() => query = '');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/holding_toolbar_test.dart`
Expected: FAIL — `holding_toolbar.dart` 不存在（编译错误）。

- [ ] **Step 3: Write minimal implementation**

Create `apps/fundlens_windows/lib/features/holdings/holding_toolbar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import 'holding_filters.dart';

/// 集合元素的切换(选中/取消)。
Set<T> toggled<T>(Set<T> set, T value) {
  final next = {...set};
  if (!next.remove(value)) next.add(value);
  return next;
}

/// 筛选下拉按钮的摘要文案:
/// 未选中显示完整标签;1 项显示"短标签:值";多项显示"短标签:首值+N"。
String filterButtonSummary({
  required String label,
  required String shortLabel,
  required List<String> selectedLabels,
}) {
  if (selectedLabels.isEmpty) return label;
  if (selectedLabels.length == 1) return '$shortLabel:${selectedLabels.first}';
  return '$shortLabel:${selectedLabels.first}+${selectedLabels.length - 1}';
}

/// 搜索框:受控文本与外部筛选状态同步(清除筛选时自动清空)。
class HoldingSearchField extends StatefulWidget {
  const HoldingSearchField({
    super.key,
    required this.query,
    required this.onChanged,
  });

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<HoldingSearchField> createState() => _HoldingSearchFieldState();
}

class _HoldingSearchFieldState extends State<HoldingSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(HoldingSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 40,
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '搜索产品名称或代码',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// 多选筛选下拉:按钮文本即选中状态;菜单条目点击后不自动关闭。
class HoldingFilterDropdown<T> extends StatelessWidget {
  const HoldingFilterDropdown({
    super.key,
    required this.label,
    required this.shortLabel,
    required this.options,
    required this.selected,
    required this.onToggled,
  });

  final String label;
  final String shortLabel;
  final List<(T, String)> options;
  final Set<T> selected;
  final void Function(T value) onToggled;

  @override
  Widget build(BuildContext context) {
    final selectedLabels = [
      for (final (value, text) in options)
        if (selected.contains(value)) text,
    ];
    final summary = filterButtonSummary(
      label: label,
      shortLabel: shortLabel,
      selectedLabels: selectedLabels,
    );
    return MenuAnchor(
      builder: (context, controller, child) {
        return SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        for (final (value, text) in options)
          _CheckMenuEntry(
            checked: selected.contains(value),
            label: text,
            onTap: () => onToggled(value),
          ),
      ],
    );
  }
}

/// 多选菜单条目:InkWell 直接触发(不走 MenuItemButton,避免自动关闭);
/// 最小高度 40 满足点击区域要求。
class _CheckMenuEntry extends StatelessWidget {
  const _CheckMenuEntry({
    required this.checked,
    required this.label,
    required this.onTap,
  });

  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40, minWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: checked ? FundLensTokens.accent : FundLensTokens.muted,
            ),
            const SizedBox(width: FundLensTokens.space2),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// 排序下拉:列出全部字段 × 方向,与表头排序共享同一状态。
class HoldingSortMenu extends StatelessWidget {
  const HoldingSortMenu({
    super.key,
    required this.sort,
    required this.onSelected,
  });

  final HoldingSort sort;
  final ValueChanged<HoldingSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, child) {
        return SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(sort.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        for (final field in HoldingSortField.values)
          for (final ascending in const [false, true])
            Builder(builder: (context) {
              final option = HoldingSort(field, ascending);
              final current = option == sort;
              return MenuItemButton(
                leadingIcon: current
                    ? const Icon(Icons.check, size: 18, color: FundLensTokens.accent)
                    : const SizedBox(width: 18),
                onPressed: () => onSelected(option),
                child: Text(option.label),
              );
            }),
      ],
    );
  }
}
```

**holdings_page.dart 接线补丁（actions 整体替换为 7 项）:**

```dart
      actions: [
        HoldingSearchField(
          query: filter.query,
          onChanged: (value) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(query: value),
        ),
        HoldingFilterDropdown<AssetClass>(
          label: '资产类别',
          shortLabel: '类别',
          options: [
            for (final entry in HoldingLabels.assetClass.entries)
              (entry.key, entry.value),
          ],
          selected: filter.assetClasses,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(assetClasses: toggled(filter.assetClasses, v)),
        ),
        HoldingFilterDropdown<SourcePlatform>(
          label: '来源平台',
          shortLabel: '平台',
          options: [
            for (final entry in HoldingLabels.sourcePlatform.entries)
              (entry.key, entry.value),
          ],
          selected: filter.sources,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(sources: toggled(filter.sources, v)),
        ),
        HoldingFilterDropdown<HoldingDataStatus>(
          label: '数据状态',
          shortLabel: '状态',
          options: [
            for (final entry in holdingDataStatusLabels.entries)
              (entry.key, entry.value),
          ],
          selected: filter.statuses,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(statuses: toggled(filter.statuses, v)),
        ),
        HoldingFilterDropdown<String?>(
          label: '组合标签',
          shortLabel: '标签',
          options: [
            (null, '未标记'),
            for (final tag in ref.watch(holdingTagOptionsProvider)) (tag, tag),
          ],
          selected: filter.tags,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(tags: toggled(filter.tags, v)),
        ),
        HoldingSortMenu(
          sort: filter.sort,
          onSelected: (sort) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(sort: sort),
        ),
        FilledButton.icon(
          onPressed: () => _addHolding(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('添加持仓'),
        ),
      ],
```
- 补充 import：`holding_toolbar.dart`、`holding_status.dart`（holdingDataStatusLabels）。
- `holdings_page_test.dart` 第 46 行断言改为 `expect(scaffold.actions.length, 7);`，注释改为「搜索/4 筛选下拉/排序下拉/添加持仓位于页头操作区」。

- [ ] **Step 4: Run tests to verify they pass**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/ && /d/flutter/bin/flutter.bat analyze`
Expected: 测试全过；analyze No issues。

- [ ] **Step 5: Commit**

```bash
git add apps/fundlens_windows/lib/features/holdings/ apps/fundlens_windows/test/features/holdings/
git commit -m "feat(holdings): 工具栏组件——搜索/四筛选下拉(选中摘要)/排序下拉"
```

---

### Task 5: holding_detail_drawer.dart — 行详情抽屉 + 行级动作

**Files:**
- Create: `apps/fundlens_windows/lib/features/holdings/holding_actions.dart`（`HoldingActions` 与 `quoteRefreshServiceProvider` 从 holdings_page.dart 迁入并改造）
- Create: `apps/fundlens_windows/lib/features/holdings/holding_detail_drawer.dart`
- Modify: `apps/fundlens_windows/lib/features/holdings/holdings_page.dart`（删除迁出代码；`onRowTap` 接线打开抽屉）
- Test: `apps/fundlens_windows/test/features/holdings/holding_detail_drawer_test.dart`

**Interfaces:**
- Consumes: Task 1 全部单元格文案函数与 `HoldingValueFormatter`；`HoldingLabels`；`holdingSupportsQuoteRefresh`（holding_filters.dart）；`holdingsProvider`/`portfolioSummaryProvider`；`holdingRepositoryProvider`；`QuoteRefreshService`/`QuoteRefreshReport`（market/quote_refresh_service.dart）；`showHoldingEditorDialog`/`showHoldingDeleteConfirmation`。
- Produces（Task 6/7 依赖）:
  - `quoteRefreshServiceProvider`（Provider<QuoteRefreshService?>，从 page 迁入）
  - `abstract final class HoldingActions`：`static Future<bool> edit(...)` / `static Future<bool> delete(...)` / `static Future<QuoteRefreshReport?> refreshQuotes(WidgetRef ref, List<Holding> holdings)` / `static Future<void> export(List<Holding> visible, String path)`
  - `Future<void> showHoldingDetailDrawer(BuildContext context, String holdingId)`
  - `class HoldingDetailDrawer extends ConsumerWidget`（`{required String holdingId}`）
  - 纯函数（测试直接覆盖）: `drawerBasicRows` / `drawerPlatformRows` / `drawerAmountRows` / `drawerProfitRows` / `drawerProvenanceRows` / `drawerUpdatedRows` — 均返回 `List<(String, String)>`
  - `void showHoldingToast(BuildContext context, String message)`

- [ ] **Step 1: Write the failing test**

Create `apps/fundlens_windows/test/features/holdings/holding_detail_drawer_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holding_actions.dart';
import 'package:fundlens_windows/features/holdings/holding_detail_drawer.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final _now = DateTime.utc(2026, 7, 20, 10, 30);

Holding drawerHolding({
  String id = 'h-1',
  String? productCode = '110011',
  DecimalValue? costAmount,
  DecimalValue? cumulativeProfit,
  String? note = '定投中',
  List<String> platformTags = const ['工资账户'],
  Map<String, FieldProvenance> fieldProvenance = const {
    'currentValue': FieldProvenance(kind: ProvenanceKind.original, source: '导入'),
  },
}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: '测试基金',
    productCode: productCode,
    currency: 'CNY',
    quantity: DecimalValue.parse('1000'),
    currentPrice: DecimalValue.parse('1.5'),
    currentValue: DecimalValue.parse('1500'),
    costAmount: costAmount ?? DecimalValue.parse('1200'),
    holdingProfit: DecimalValue.parse('300'),
    holdingReturn: DecimalValue.parse('0.25'),
    cumulativeProfit: cumulativeProfit,
    valuationMethod: ValuationMethod.automaticQuote,
    valuationDate: DateTime.utc(2026, 7, 19),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: fieldProvenance,
    platformTags: platformTags,
    note: note,
    createdAt: _now,
    updatedAt: _now,
  );
}

/// 记录写操作的 Fake 仓库。
final class RecordingHoldingRepository implements HoldingRepository {
  RecordingHoldingRepository(this._holdings);

  final List<Holding> _holdings;
  final List<Holding> upserted = [];
  final List<List<String>> deletedIds = [];

  @override
  Stream<List<Holding>> watchAll() => Stream.value(List.unmodifiable(_holdings));

  @override
  Future<List<Holding>> getAll() async => List.unmodifiable(_holdings);

  @override
  Future<void> upsert(Holding holding) async {
    upserted.add(holding);
    _holdings
      ..removeWhere((h) => h.id == holding.id)
      ..add(holding);
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    deletedIds.add(ids);
    _holdings.removeWhere((h) => ids.contains(h.id));
  }

  @override
  Future<void> replacePlatform(
    SourcePlatform platform, List<Holding> holdings) async {}

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();
}

Future<ProviderContainer> pumpDrawer(
  WidgetTester tester, {
  required RecordingHoldingRepository repo,
  String holdingId = 'h-1',
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(repo),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(body: HoldingDetailDrawer(holdingId: holdingId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('抽屉分节渲染', () {
    testWidgets('六分节齐全,关键值正确', (tester) async {
      await pumpDrawer(tester, repo: RecordingHoldingRepository([drawerHolding()]));
      for (final title in ['基本信息', '来源平台', '当前金额', '成本与收益', '数据来源', '最后更新']) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.text('测试基金'), findsWidgets);
      expect(find.text('支付宝'), findsOneWidget);
      expect(find.text('¥1,500.00'), findsOneWidget);
      // 占比 = 1500 ÷ 1500 = 100%。
      expect(find.text('100.00%'), findsOneWidget);
      expect(find.text('+25.00%'), findsOneWidget);
      expect(find.text('工资账户'), findsOneWidget);
      expect(find.text('原始确认'), findsOneWidget);
      // 操作按钮。
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('刷新行情'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('缺失文案:无代码未填写,无累计盈亏不适用,含累计脚注', (tester) async {
      await pumpDrawer(
        tester,
        repo: RecordingHoldingRepository([
          drawerHolding(productCode: null, note: null),
        ]),
      );
      expect(find.text('未填写'), findsWidgets);
      expect(find.text('不适用'), findsOneWidget);
      expect(find.text('累计盈亏只展示,不纳入当前盈亏汇总。'), findsOneWidget);
    });
  });

  group('行级动作', () {
    testWidgets('编辑:打开编辑对话框,保存后显示已保存 Toast', (tester) async {
      final repo = RecordingHoldingRepository([drawerHolding()]);
      await pumpDrawer(tester, repo: repo);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      // 编辑对话框打开(标题为"编辑持仓")。
      expect(find.text('编辑持仓'), findsOneWidget);
      // 直接保存(初始值合法)。
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.upserted, hasLength(1));
      expect(find.text('已保存'), findsOneWidget);
    });

    testWidgets('刷新行情:服务未接线时按钮禁用', (tester) async {
      await pumpDrawer(tester, repo: RecordingHoldingRepository([drawerHolding()]));
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '刷新行情'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('删除:二次确认后删除并关闭抽屉', (tester) async {
      final repo = RecordingHoldingRepository([drawerHolding()]);
      // 用真实 showGeneralDialog 路径验证关闭。
      final container = ProviderContainer(overrides: [
        holdingRepositoryProvider.overrideWithValue(repo),
        portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      ]);
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: FundLensTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showHoldingDetailDrawer(context, 'h-1'),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('基本信息'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      // 二次确认对话框,明示产品名。
      expect(find.textContaining('测试基金'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
      expect(repo.deletedIds, [
        ['h-1'],
      ]);
      // 抽屉关闭,Toast 出现。
      expect(find.text('基本信息'), findsNothing);
      expect(find.text('已删除'), findsOneWidget);
    });
  });

  group('HoldingActions.refreshQuotes', () {
    test('服务未接线或不可刷新时返回 null', () async {
      final container = ProviderContainer(overrides: [
        holdingRepositoryProvider.overrideWithValue(
          RecordingHoldingRepository(const []),
        ),
      ]);
      addTearDown(container.dispose);
      final ref = container.read(quoteRefreshServiceProvider);
      expect(ref, isNull);
      // 手动金额类不可刷新。
      final manual = drawerHolding().copyWith();
      expect(holdingSupportsQuoteRefreshCheck(manual), isTrue); // 占位,见下
    }, skip: true);
  });
}
```

注意：最后一个 `skip: true` 用例是计划自检发现的坏案例（引用了不存在的函数）——**实现时删除整个 `HoldingActions.refreshQuotes` group**；refreshQuotes 的行为由 Task 6 批量刷新的 widget 测试覆盖，此处不留空壳用例。

- [ ] **Step 2: Run test to verify it fails**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/holding_detail_drawer_test.dart`
Expected: FAIL — `holding_detail_drawer.dart`/`holding_actions.dart` 不存在（编译错误）。

- [ ] **Step 3: Write minimal implementation**

Create `apps/fundlens_windows/lib/features/holdings/holding_actions.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../market/quote_refresh_service.dart';
import 'holding_editor_dialog.dart';
import 'holding_export_service.dart';
import 'holding_filters.dart';

/// 行情刷新服务接线;引导完成前为 null,届时刷新操作保持禁用。
final quoteRefreshServiceProvider = Provider<QuoteRefreshService?>((ref) {
  return null;
});

/// 统一的轻提示。
void showHoldingToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// 行级 CRUD 与行情/导出动作,供页面、抽屉与批量条共用。
abstract final class HoldingActions {
  /// 编辑并保存;返回是否真正保存。
  static Future<bool> edit(
    BuildContext context,
    WidgetRef ref,
    Holding holding,
  ) async {
    final updated = await showHoldingEditorDialog(context, initial: holding);
    if (updated == null) return false;
    await ref.read(holdingRepositoryProvider).upsert(updated);
    return true;
  }

  /// 二次确认后删除;返回是否真正删除。
  static Future<bool> delete(
    BuildContext context,
    WidgetRef ref,
    Holding holding,
  ) async {
    final confirmed = await showHoldingDeleteConfirmation(context, holding);
    if (!confirmed) return false;
    await ref.read(holdingRepositoryProvider).deleteByIds([holding.id]);
    return true;
  }

  /// 刷新行情(自动过滤不可刷新的资产)。
  /// 服务未接线或没有可刷新资产时返回 null。
  static Future<QuoteRefreshReport?> refreshQuotes(
    WidgetRef ref,
    List<Holding> holdings,
  ) async {
    final eligible = holdings.where(holdingSupportsQuoteRefresh).toList();
    if (eligible.isEmpty) return null;
    final service = ref.read(quoteRefreshServiceProvider);
    if (service == null) return null;
    return service.refresh(eligible);
  }

  static Future<void> export(List<Holding> visible, String path) {
    return const HoldingExportService().exportCsv(visible, path);
  }
}
```

Create `apps/fundlens_windows/lib/features/holdings/holding_detail_drawer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'holding_actions.dart';
import 'holding_filters.dart';
import 'holding_status.dart';

/// 打开右侧持仓详情抽屉。
Future<void> showHoldingDetailDrawer(BuildContext context, String holdingId) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭持仓详情',
    barrierColor: const Color(0x61000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 400,
          height: double.infinity,
          child: HoldingDetailDrawer(holdingId: holdingId),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return SlideTransition(position: offset, child: child);
    },
  );
}

/// 基本信息分节行。
List<(String, String)> drawerBasicRows(Holding h) {
  return [
    ('产品名称', h.productName),
    ('产品代码', h.productCode ?? '未填写'),
    ('产品形态', HoldingLabels.instrumentType[h.instrumentType]!),
    ('资产类别', HoldingLabels.assetClass[h.assetClass]!),
    ('币种', h.currency),
    ('备注', h.note ?? '未填写'),
  ];
}

/// 来源平台分节行。
List<(String, String)> drawerPlatformRows(Holding h) {
  return [
    ('来源平台', HoldingLabels.sourcePlatform[h.sourcePlatform]!),
    ('数据出处', HoldingLabels.dataOrigin[h.dataOrigin]!),
    ('估值方式', HoldingLabels.valuationMethod[h.valuationMethod]!),
    ('组合标签', h.platformTags.isEmpty ? '未填写' : h.platformTags.join('、')),
  ];
}

/// 当前金额分节行;share 为 null 时占比显示"不适用"。
List<(String, String)> drawerAmountRows(Holding h, DecimalValue? share) {
  return [
    ('当前金额', '¥${HoldingValueFormatter.amount(h.currentValue)}'),
    ('资产占比', holdingShareText(share)),
  ];
}

/// 成本与收益分节行。
List<(String, String)> drawerProfitRows(Holding h) {
  return [
    ('覆盖成本', holdingCostText(h)),
    ('持仓盈亏', holdingProfitText(h)),
    ('持仓收益率', holdingReturnText(h)),
    (
      '当日盈亏',
      h.dailyProfit == null
          ? (h.valuationMethod == ValuationMethod.manualAmount ? '不适用' : '暂无行情')
          : HoldingValueFormatter.signedAmount(h.dailyProfit),
    ),
    (
      '累计盈亏',
      h.cumulativeProfit == null
          ? '不适用'
          : HoldingValueFormatter.signedAmount(h.cumulativeProfit),
    ),
  ];
}

/// 数据来源分节行:按字段来源类型汇总计数。
List<(String, String)> drawerProvenanceRows(Holding h) {
  final counts = <ProvenanceKind, int>{};
  for (final provenance in h.fieldProvenance.values) {
    counts[provenance.kind] = (counts[provenance.kind] ?? 0) + 1;
  }
  if (counts.isEmpty) return [('字段来源', '无字段来源记录')];
  return [
    if ((counts[ProvenanceKind.original] ?? 0) > 0)
      ('原始确认', '${counts[ProvenanceKind.original]} 项'),
    if ((counts[ProvenanceKind.inferred] ?? 0) > 0)
      ('系统推断', '${counts[ProvenanceKind.inferred]} 项'),
    if ((counts[ProvenanceKind.market] ?? 0) > 0)
      ('行情更新', '${counts[ProvenanceKind.market]} 项'),
    if ((counts[ProvenanceKind.userCorrected] ?? 0) > 0)
      ('人工修正', '${counts[ProvenanceKind.userCorrected]} 项'),
  ];
}

/// 最后更新分节行。
List<(String, String)> drawerUpdatedRows(Holding h) {
  final local = h.updatedAt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return [
    ('最后更新', '$y-$m-$d $hh:$mm'),
    ('估值日期', holdingValuationDateText(h)),
  ];
}

/// 右侧持仓详情抽屉:六个分节 + 编辑/刷新/删除操作。
///
/// 内容按 holdingId 从 holdingsProvider 实时解析,编辑或行情刷新后
/// 自动呈现最新值;持仓被删除时自动关闭。
class HoldingDetailDrawer extends ConsumerWidget {
  const HoldingDetailDrawer({super.key, required this.holdingId});

  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider).value;
    Holding? holding;
    if (holdings != null) {
      for (final h in holdings) {
        if (h.id == holdingId) {
          holding = h;
          break;
        }
      }
    }
    if (holding == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }
    final h = holding;

    final totalValue = ref.watch(portfolioSummaryProvider).totalValue;
    final share =
        totalValue.isZero ? null : h.currentValue.divide(totalValue);
    final canRefresh = holdingSupportsQuoteRefresh(h) &&
        ref.watch(quoteRefreshServiceProvider) != null;

    final theme = Theme.of(context);
    return Material(
      color: FundLensTokens.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: FundLensTokens.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FundLensTokens.space4, FundLensTokens.space3,
                FundLensTokens.space2, FundLensTokens.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      h.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.extension<FundLensTextStyles>()!.sectionTitle,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('drawer-close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FundLensTokens.space4),
                children: [
                  _Section(title: '基本信息', rows: drawerBasicRows(h)),
                  _Section(title: '来源平台', rows: drawerPlatformRows(h)),
                  _Section(title: '当前金额', rows: drawerAmountRows(h, share)),
                  _Section(
                    title: '成本与收益',
                    rows: drawerProfitRows(h),
                    footnote: '累计盈亏只展示,不纳入当前盈亏汇总。',
                  ),
                  _Section(title: '数据来源', rows: drawerProvenanceRows(h)),
                  _Section(title: '最后更新', rows: drawerUpdatedRows(h)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FundLensTokens.space4,
                vertical: FundLensTokens.space2,
              ),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('drawer-edit'),
                    onPressed: () async {
                      final saved = await HoldingActions.edit(context, ref, h);
                      if (saved && context.mounted) {
                        showHoldingToast(context, '已保存');
                      }
                    },
                    child: const Text('编辑'),
                  ),
                  const SizedBox(width: FundLensTokens.space2),
                  Tooltip(
                    message: canRefresh ? '' : '该资产类型不支持行情刷新或服务未就绪',
                    child: TextButton(
                      key: const ValueKey('drawer-refresh'),
                      onPressed: canRefresh
                          ? () async {
                              final report =
                                  await HoldingActions.refreshQuotes(ref, [h]);
                              if (!context.mounted) return;
                              showHoldingToast(
                                context,
                                report != null && report.updated.isNotEmpty
                                    ? '行情已更新'
                                    : '行情未更新,保留原值',
                              );
                            }
                          : null,
                      child: const Text('刷新行情'),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('drawer-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: FundLensTokens.profit,
                    ),
                    onPressed: () async {
                      final deleted =
                          await HoldingActions.delete(context, ref, h);
                      if (deleted && context.mounted) {
                        Navigator.of(context).maybePop();
                        showHoldingToast(context, '已删除');
                      }
                    },
                    child: const Text('删除'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉分节:标题 + 标签/值行 + 可选脚注。
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.footnote});

  final String title;
  final List<(String, String)> rows;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FundLensTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: FundLensTokens.space2),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: FundLensTokens.space1,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(label, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Text(value, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: FundLensTokens.space1),
              child: Text(footnote!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
```

**holdings_page.dart 补丁:**
- 删除 `quoteRefreshServiceProvider` 定义与 `abstract final class HoldingActions` 整块（已迁入 holding_actions.dart）。
- import `holding_actions.dart`（保持 `HoldingActions` 可用——若页面不再引用则不必 import）与 `holding_detail_drawer.dart`。
- `onRowTap: null` 改为 `onRowTap: (holding) => showHoldingDetailDrawer(context, holding.id)`。
- grep 全仓库 `HoldingActions` 与 `quoteRefreshServiceProvider` 的其他引用点（如 settings/market 相关接线），同步改为 import `holding_actions.dart`。

- [ ] **Step 4: Run tests to verify they pass**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/ && /d/flutter/bin/flutter.bat analyze`
Expected: 测试全过；analyze No issues。

- [ ] **Step 5: Commit**

```bash
git add apps/fundlens_windows/lib/features/holdings/ apps/fundlens_windows/test/features/holdings/
git commit -m "feat(holdings): 行详情抽屉——六分节/编辑Toast/刷新禁用/删除二次确认"
```

---

### Task 6: holding_batch_bar.dart — 批量操作 + Holding.copyWith

**Files:**
- Modify: `packages/fundlens_core/lib/src/model/holding.dart`（新增 `copyWith`，仅 4 个非空字段）
- Modify: `packages/fundlens_core/test/model/holding_test.dart`（追加 copyWith 用例）
- Create: `apps/fundlens_windows/lib/features/holdings/holding_batch_bar.dart`
- Test: `apps/fundlens_windows/test/features/holdings/holding_batch_bar_test.dart`

**Interfaces:**
- Consumes: `holdingSelectionProvider`/`visibleHoldingsProvider`（Task 2）；`HoldingActions`/`quoteRefreshServiceProvider`/`showHoldingToast`（Task 5）；`holdingSupportsQuoteRefresh`/`HoldingLabels`；`holdingRepositoryProvider`；`HoldingExportService`（经 HoldingActions.export）。
- Produces（Task 7 依赖）:
  - `class HoldingBatchBar extends ConsumerWidget`（无参，自选隐显）
  - `final holdingSavePathProvider = Provider<Future<String?> Function(String suggestedName)>`
  - core: `Holding copyWith({SourcePlatform? sourcePlatform, AssetClass? assetClass, Map<String, FieldProvenance>? fieldProvenance, DateTime? updatedAt})`

- [ ] **Step 1: Write the failing test**

先写 core 用例——append 到 `packages/fundlens_core/test/model/holding_test.dart` 的 `main()` 内:

```dart
  test('holding copyWith updates only the given fields', () {
    final now = DateTime.utc(2026, 7, 1);
    final later = DateTime.utc(2026, 8, 2, 9, 30);
    final original = Holding(
      id: 'h-1',
      sourcePlatform: SourcePlatform.alipay,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.equity,
      productName: '测试基金',
      currency: 'CNY',
      currentValue: DecimalValue.parse('1500'),
      costAmount: DecimalValue.parse('1200'),
      valuationMethod: ValuationMethod.automaticQuote,
      dataOrigin: DataOrigin.excel,
      fieldProvenance: const {
        'currentValue': FieldProvenance(
          kind: ProvenanceKind.original,
          source: '导入',
        ),
      },
      createdAt: now,
      updatedAt: now,
    );
    final updated = original.copyWith(
      assetClass: AssetClass.gold,
      fieldProvenance: {
        ...original.fieldProvenance,
        'assetClass': const FieldProvenance(
          kind: ProvenanceKind.userCorrected,
          source: '批量修改',
        ),
      },
      updatedAt: later,
    );
    expect(updated.assetClass, AssetClass.gold);
    expect(updated.updatedAt, later);
    expect(
      updated.fieldProvenance['assetClass']!.kind,
      ProvenanceKind.userCorrected,
    );
    // 未传字段保持不变。
    expect(updated.sourcePlatform, SourcePlatform.alipay);
    expect(updated.currentValue.canonical, '1500');
    expect(updated.fieldProvenance['currentValue']!.kind, ProvenanceKind.original);
  });
```

再写 widget 测试——create `apps/fundlens_windows/test/features/holdings/holding_batch_bar_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holding_batch_bar.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

import 'holding_detail_drawer_test.dart' show RecordingHoldingRepository;

final _now = DateTime.utc(2026, 7, 20);

Holding batchHolding(String id, {AssetClass assetClass = AssetClass.equity}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: '产品$id',
    productCode: '110011',
    currency: 'CNY',
    quantity: DecimalValue.parse('100'),
    currentPrice: DecimalValue.parse('1.0'),
    currentValue: DecimalValue.parse('100'),
    valuationMethod: ValuationMethod.automaticQuote,
    valuationDate: _now,
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<ProviderContainer> pumpBatchBar(
  WidgetTester tester, {
  required RecordingHoldingRepository repo,
  Set<String> selection = const {},
  Future<String?> Function(String suggestedName)? savePath,
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(repo),
    if (savePath != null) holdingSavePathProvider.overrideWithValue(savePath),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const Scaffold(body: HoldingBatchBar()),
      ),
    ),
  );
  await tester.pump();
  container.read(holdingSelectionProvider.notifier).state = selection;
  await tester.pump();
  return container;
}

void main() {
  testWidgets('无选择时不显示,有选择时显示计数', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a')]);
    await pumpBatchBar(tester, repo: repo);
    expect(find.textContaining('已选'), findsNothing);

    await pumpBatchBar(tester, repo: repo, selection: {'a'});
    expect(find.text('已选 1 项'), findsOneWidget);
    for (final action in ['修改资产类别', '修改来源平台', '刷新行情', '导出', '删除', '取消选择']) {
      expect(find.text(action), findsOneWidget, reason: action);
    }
  });

  testWidgets('修改资产类别:事务内逐条 upsert 并标记人工修正', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a'), batchHolding('b')]);
    await pumpBatchBar(tester, repo: repo, selection: {'a', 'b'});

    await tester.tap(find.text('修改资产类别'));
    await tester.pumpAndSettle();
    expect(find.text('黄金'), findsOneWidget);
    await tester.tap(find.text('黄金'));
    await tester.pumpAndSettle();

    expect(repo.upserted, hasLength(2));
    for (final h in repo.upserted) {
      expect(h.assetClass, AssetClass.gold);
      expect(h.fieldProvenance['assetClass']!.kind, ProvenanceKind.userCorrected);
    }
    expect(find.text('已更新 2 项持仓'), findsOneWidget);
  });

  testWidgets('导出:经保存路径接缝写出 CSV 并提示', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a')]);
    final dir = Directory.systemTemp.createTempSync('fundlens-export-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/out.csv';
    await pumpBatchBar(
      tester,
      repo: repo,
      selection: {'a'},
      savePath: (suggested) async => path,
    );

    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();

    final content = File(path).readAsStringSync();
    expect(content, contains('产品名称'));
    expect(content, contains('产品a'));
    expect(find.textContaining('已导出'), findsOneWidget);
  });

  testWidgets('删除:二次确认后删除并清空选择', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a'), batchHolding('b')]);
    final container = await pumpBatchBar(
      tester,
      repo: repo,
      selection: {'a', 'b'},
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除选中的 2 项持仓吗?此操作不可撤销。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(repo.deletedIds, [
      ['a', 'b'],
    ]);
    expect(container.read(holdingSelectionProvider), isEmpty);
    expect(find.text('已删除 2 项持仓'), findsOneWidget);
  });

  testWidgets('刷新行情:服务未接线时禁用', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a')]);
    await pumpBatchBar(tester, repo: repo, selection: {'a'});
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '刷新行情'),
    );
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
- core：`cd packages/fundlens_core && /d/flutter/bin/cache/dart-sdk/bin/dart.exe test test/model/holding_test.dart` → FAIL（`copyWith` 未定义）
- widget（从 `apps/fundlens_windows`）：`/d/flutter/bin/flutter.bat test test/features/holdings/holding_batch_bar_test.dart` → FAIL（`holding_batch_bar.dart` 不存在）

- [ ] **Step 3: Write minimal implementation**

Append 到 `packages/fundlens_core/lib/src/model/holding.dart` 的 `Holding` 类内（放在 `effectiveCostAmount` getter 之后）:

```dart
  /// 定向拷贝:仅支持批量操作需要的非空字段。
  /// 未传的字段保持原值;可空字段不在此列(批量操作不清空数据)。
  Holding copyWith({
    SourcePlatform? sourcePlatform,
    AssetClass? assetClass,
    Map<String, FieldProvenance>? fieldProvenance,
    DateTime? updatedAt,
  }) {
    return Holding(
      id: id,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      instrumentType: instrumentType,
      assetClass: assetClass ?? this.assetClass,
      productName: productName,
      productCode: productCode,
      currency: currency,
      quantity: quantity,
      availableQuantity: availableQuantity,
      currentPrice: currentPrice,
      costPrice: costPrice,
      currentValue: currentValue,
      costAmount: costAmount,
      holdingProfit: holdingProfit,
      holdingReturn: holdingReturn,
      dailyProfit: dailyProfit,
      cumulativeProfit: cumulativeProfit,
      platformTags: platformTags,
      valuationMethod: valuationMethod,
      valuationDate: valuationDate,
      dataOrigin: dataOrigin,
      fieldProvenance: fieldProvenance ?? this.fieldProvenance,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
```

Create `apps/fundlens_windows/lib/features/holdings/holding_batch_bar.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_tokens.dart';
import 'holding_actions.dart';
import 'holding_filters.dart';

/// 保存路径选择(测试可覆写);返回 null 表示用户取消。
final holdingSavePathProvider =
    Provider<Future<String?> Function(String suggestedName)>((ref) {
  return (name) => FilePicker.platform.saveFile(
        dialogTitle: '导出持仓',
        fileName: name,
      );
});

/// 批量操作条:选中 ≥1 项持仓时浮现。
class HoldingBatchBar extends ConsumerWidget {
  const HoldingBatchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(holdingSelectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();

    final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
    final selected = [
      for (final h in holdings)
        if (selection.contains(h.id)) h,
    ];
    if (selected.isEmpty) return const SizedBox.shrink();

    final canRefresh = ref.watch(quoteRefreshServiceProvider) != null &&
        selected.any(holdingSupportsQuoteRefresh);

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: FundLensTokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: FundLensTokens.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space4),
      child: Row(
        children: [
          Text(
            '已选 ${selected.length} 项',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: FundLensTokens.space4),
          TextButton(
            onPressed: () => _changeAssetClass(context, ref, selected),
            child: const Text('修改资产类别'),
          ),
          TextButton(
            onPressed: () => _changeSourcePlatform(context, ref, selected),
            child: const Text('修改来源平台'),
          ),
          TextButton(
            onPressed: canRefresh
                ? () => _refreshQuotes(context, ref, selected)
                : null,
            child: const Text('刷新行情'),
          ),
          TextButton(
            onPressed: () => _export(context, ref, selected),
            child: const Text('导出'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: FundLensTokens.profit,
            ),
            onPressed: () => _delete(context, ref, selected),
            child: const Text('删除'),
          ),
          const Spacer(),
          TextButton(
            onPressed: () =>
                ref.read(holdingSelectionProvider.notifier).state = const {},
            child: const Text('取消选择'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeAssetClass(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final target = await showDialog<AssetClass>(
      context: context,
      builder: (context) => const _EnumPickerDialog<AssetClass>(
        title: '修改资产类别',
        options: HoldingLabels.assetClass,
      ),
    );
    if (target == null || !context.mounted) return;
    await _applyBatch(
      ref,
      selected,
      (h) => h.copyWith(
        assetClass: target,
        fieldProvenance: {
          ...h.fieldProvenance,
          'assetClass': const FieldProvenance(
            kind: ProvenanceKind.userCorrected,
            source: '批量修改',
          ),
        },
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    if (context.mounted) {
      showHoldingToast(context, '已更新 ${selected.length} 项持仓');
    }
  }

  Future<void> _changeSourcePlatform(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final target = await showDialog<SourcePlatform>(
      context: context,
      builder: (context) => const _EnumPickerDialog<SourcePlatform>(
        title: '修改来源平台',
        options: HoldingLabels.sourcePlatform,
      ),
    );
    if (target == null || !context.mounted) return;
    await _applyBatch(
      ref,
      selected,
      (h) => h.copyWith(
        sourcePlatform: target,
        fieldProvenance: {
          ...h.fieldProvenance,
          'sourcePlatform': const FieldProvenance(
            kind: ProvenanceKind.userCorrected,
            source: '批量修改',
          ),
        },
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    if (context.mounted) {
      showHoldingToast(context, '已更新 ${selected.length} 项持仓');
    }
  }

  Future<void> _applyBatch(
    WidgetRef ref,
    List<Holding> selected,
    Holding Function(Holding h) transform,
  ) async {
    final repo = ref.read(holdingRepositoryProvider);
    await repo.inTransaction(() async {
      for (final holding in selected) {
        await repo.upsert(transform(holding));
      }
    });
  }

  Future<void> _refreshQuotes(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final report = await HoldingActions.refreshQuotes(ref, selected);
    if (!context.mounted) return;
    showHoldingToast(
      context,
      '行情:更新 ${report?.updated.length ?? 0} · '
      '保留 ${report?.retained.length ?? 0} · '
      '失败 ${report?.failed.length ?? 0}',
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final path = await ref.read(holdingSavePathProvider)('holdings-$y$m$d.csv');
    if (path == null || !context.mounted) return;
    await HoldingActions.export(selected, path);
    if (context.mounted) {
      // 不引入 path 包:手动取文件名。
      final name = path.split(RegExp(r'[\\/]')).last;
      showHoldingToast(context, '已导出到 $name');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除持仓'),
        content: Text('确定删除选中的 ${selected.length} 项持仓吗?此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(holdingRepositoryProvider)
        .deleteByIds([for (final h in selected) h.id]);
    ref.read(holdingSelectionProvider.notifier).state = const {};
    showHoldingToast(context, '已删除 ${selected.length} 项持仓');
  }
}

/// 单选目标值对话框(批量修改类别/平台共用)。
class _EnumPickerDialog<T> extends StatelessWidget {
  const _EnumPickerDialog({required this.title, required this.options});

  final String title;
  final Map<T, String> options;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in options.entries)
              InkWell(
                onTap: () => Navigator.of(context).pop(entry.key),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FundLensTokens.space2,
                  ),
                  child: Text(entry.value),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
- core：`cd packages/fundlens_core && /d/flutter/bin/cache/dart-sdk/bin/dart.exe test` → 全过（19 个）
- widget（从 `apps/fundlens_windows`）：`/d/flutter/bin/flutter.bat test test/features/holdings/ && /d/flutter/bin/flutter.bat analyze`
Expected: 测试全过；analyze No issues。

- [ ] **Step 5: Commit**

```bash
git add packages/fundlens_core apps/fundlens_windows/lib/features/holdings/ apps/fundlens_windows/test/features/holdings/
git commit -m "feat(holdings): 批量操作条——类别/平台批改(copyWith)/行情刷新/导出/删除二次确认"
```

---

### Task 7: holdings_page.dart — 页面重组（状态/计数/空状态/全接线）

**Files:**
- Modify: `apps/fundlens_windows/lib/features/holdings/holdings_page.dart`（整体重写）
- Test: `apps/fundlens_windows/test/features/holdings/holdings_page_test.dart`（整体重写）

**Interfaces:**
- Consumes: Task 2 全部 provider；Task 3 `HoldingGrid`；Task 4 工具栏组件；Task 5 `showHoldingDetailDrawer`/`showHoldingToast`/`HoldingActions`；Task 6 `HoldingBatchBar`；`portfolioStateProvider`（PortfolioLoading/PortfolioDegraded/PortfolioEmpty/PortfolioReady）；`Actions.maybeInvoke(context, SelectDestinationIntent(AppDestination.importReview))`；`showHoldingEditorDialog`。
- Produces: 无新接口（终端集成任务）。

- [ ] **Step 1: Write the failing test**

Rewrite `apps/fundlens_windows/test/features/holdings/holdings_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/portfolio_providers.dart';
import 'package:fundlens_windows/features/holdings/holdings_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

import '../overview/asset_spectrum_test.dart' show FakeHoldingRepository;
import 'holding_detail_drawer_test.dart' show RecordingHoldingRepository;
import 'holding_grid_test.dart' show generateGridHoldings;

/// 默认 8 行:默认排序(当前金额降序)下首行是 产品0007(id h-7),
/// 8×56px 行高在 1440×900 页面内全部可见(避免虚拟化未构建导致断言失败)。
Future<ProviderContainer> pumpHoldings(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  HoldingRepository? repo,
  int holdingCount = 8,
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(
      repo ?? FakeHoldingRepository(generateGridHoldings(holdingCount)),
    ),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const Scaffold(body: HoldingsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('页头操作区:搜索/4 筛选/排序/添加共 7 项', (tester) async {
    await pumpHoldings(tester);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.dense);
    expect(scaffold.actions.length, 7);
    expect(find.text('资产类别'), findsOneWidget);
    expect(find.text('来源平台'), findsOneWidget);
    expect(find.text('数据状态'), findsOneWidget);
    expect(find.text('组合标签'), findsOneWidget);
    expect(find.text('当前金额 · 从高到低'), findsOneWidget);
    expect(find.text('添加持仓'), findsOneWidget);
    expect(find.text('共 8 项持仓'), findsOneWidget);
  });

  testWidgets('空持仓:两个入口', (tester) async {
    await pumpHoldings(tester, holdingCount: 0);
    expect(find.text('还没有持仓'), findsOneWidget);
    expect(find.text('导入资产'), findsOneWidget);
    expect(find.text('手动添加'), findsOneWidget);
  });

  testWidgets('筛选无结果:清除筛选恢复列表', (tester) async {
    await pumpHoldings(tester);
    await tester.enterText(find.byType(TextField), '不存在的产品');
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的持仓'), findsOneWidget);
    expect(find.text('共 0 项持仓'), findsOneWidget);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    expect(find.text('产品0007'), findsOneWidget);
    expect(find.text('共 8 项持仓'), findsOneWidget);
  });

  testWidgets('行点击打开详情抽屉并可关闭', (tester) async {
    await pumpHoldings(tester);
    await tester.tap(find.text('产品0007'));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('数据来源'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer-close')));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsNothing);
  });

  testWidgets('批量删除:全选后二次确认删除', (tester) async {
    final repo = RecordingHoldingRepository(generateGridHoldings(3));
    await pumpHoldings(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('select-all')));
    await tester.pumpAndSettle();
    expect(find.text('已选 3 项'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(repo.deletedIds.single, hasLength(3));
    expect(find.text('已删除 3 项持仓'), findsOneWidget);
  });

  testWidgets('1920 宽度无溢出', (tester) async {
    await pumpHoldings(tester, size: const Size(1920, 1080));
    expect(find.text('数据状态'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('125% 缩放等效宽度(约1092)下操作区不重叠', (tester) async {
    await pumpHoldings(tester, size: const Size(1092, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('添加持仓'), findsOneWidget);
  });

  testWidgets('页面文案无禁词', (tester) async {
    await pumpHoldings(tester);
    for (final word in ['建议', '应当', '调仓', '再平衡', '买入', '卖出']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });

  testWidgets('键盘:行聚焦后 Enter 打开抽屉', (tester) async {
    await pumpHoldings(tester);
    // 点击行使行 InkWell 获得焦点(抽屉随之打开);关闭抽屉后焦点恢复到该行。
    await tester.tap(find.text('产品0007'));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drawer-close')));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsNothing);
    // 焦点已恢复到行 InkWell,Enter 重新打开抽屉。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
  });
}
```

注意：键盘用例依赖"对话框 pop 后焦点恢复到行 InkWell"（Flutter 默认行为）与 InkWell 的 Enter 激活。若 Enter 未触发（焦点未恢复），允许实现做最小修正后重试——给 `_RowFrame` 的行 InkWell 包 `FocusableActionDetector` 显式接管焦点，或改用 `tester.sendKeyEvent(tab)` 移焦至行再 Enter——并在报告中说明采用的口径。

- [ ] **Step 2: Run test to verify it fails**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/holdings_page_test.dart`
Expected: FAIL — 新页面结构不存在（'还没有持仓'/清除筛选/计数等找不到）。

- [ ] **Step 3: Write minimal implementation**

Rewrite `apps/fundlens_windows/lib/features/holdings/holdings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../app/app_shell.dart';
import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../application/portfolio_state.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/page_scaffold.dart';
import 'holding_actions.dart';
import 'holding_batch_bar.dart';
import 'holding_detail_drawer.dart';
import 'holding_editor_dialog.dart';
import 'holding_filters.dart';
import 'holding_grid.dart';
import 'holding_status.dart';
import 'holding_toolbar.dart';

/// 全部持仓页:工具栏 + 批量条 + 计数 + 虚拟表格 + 空状态。
class HoldingsPage extends ConsumerWidget {
  const HoldingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioStateProvider);
    final filter = ref.watch(holdingFilterProvider);

    return PageScaffold(
      tier: PageWidthTier.dense,
      crumb: '组合',
      title: '全部持仓',
      actions: [
        HoldingSearchField(
          query: filter.query,
          onChanged: (value) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(query: value),
        ),
        HoldingFilterDropdown<AssetClass>(
          label: '资产类别',
          shortLabel: '类别',
          options: [
            for (final entry in HoldingLabels.assetClass.entries)
              (entry.key, entry.value),
          ],
          selected: filter.assetClasses,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state = filter
                  .copyWith(assetClasses: toggled(filter.assetClasses, v)),
        ),
        HoldingFilterDropdown<SourcePlatform>(
          label: '来源平台',
          shortLabel: '平台',
          options: [
            for (final entry in HoldingLabels.sourcePlatform.entries)
              (entry.key, entry.value),
          ],
          selected: filter.sources,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(sources: toggled(filter.sources, v)),
        ),
        HoldingFilterDropdown<HoldingDataStatus>(
          label: '数据状态',
          shortLabel: '状态',
          options: [
            for (final entry in holdingDataStatusLabels.entries)
              (entry.key, entry.value),
          ],
          selected: filter.statuses,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(statuses: toggled(filter.statuses, v)),
        ),
        HoldingFilterDropdown<String?>(
          label: '组合标签',
          shortLabel: '标签',
          options: [
            (null, '未标记'),
            for (final tag in ref.watch(holdingTagOptionsProvider)) (tag, tag),
          ],
          selected: filter.tags,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(tags: toggled(filter.tags, v)),
        ),
        HoldingSortMenu(
          sort: filter.sort,
          onSelected: (sort) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(sort: sort),
        ),
        FilledButton.icon(
          onPressed: () => _addHolding(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('添加持仓'),
        ),
      ],
      body: switch (state) {
        PortfolioLoading() =>
          const Center(child: CircularProgressIndicator()),
        PortfolioDegraded(:final error) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('持仓数据暂时不可用'),
                const SizedBox(height: FundLensTokens.space2),
                Text(
                  '$error',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        PortfolioEmpty() => const _EmptyHoldingsBody(),
        PortfolioReady() => const _ReadyBody(),
      },
    );
  }

  Future<void> _addHolding(BuildContext context, WidgetRef ref) async {
    final holding = await showHoldingEditorDialog(context);
    if (holding == null) return;
    await ref.read(holdingRepositoryProvider).upsert(holding);
    if (context.mounted) showHoldingToast(context, '已保存');
  }
}

/// 有持仓时的主体:批量条 + 计数 + 表格/无结果状态。
class _ReadyBody extends ConsumerWidget {
  const _ReadyBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleHoldingsProvider);
    final filter = ref.watch(holdingFilterProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HoldingBatchBar(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FundLensTokens.space4,
            vertical: FundLensTokens.space2,
          ),
          child: Text(
            '共 ${visible.length} 项持仓',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? (filter.hasActiveFilter
                  ? const _NoResultBody()
                  : const SizedBox.shrink())
              : HoldingGrid(
                  holdings: visible,
                  totalValue:
                      ref.watch(portfolioSummaryProvider).totalValue,
                  freshQuoteHoldingIds:
                      ref.watch(freshQuoteHoldingIdsProvider),
                  sort: filter.sort,
                  onSortChanged: (sort) =>
                      ref.read(holdingFilterProvider.notifier).state =
                          filter.copyWith(sort: sort),
                  selectedIds: ref.watch(holdingSelectionProvider),
                  onSelectedChanged: (id, selected) {
                    final next = {...ref.read(holdingSelectionProvider)};
                    if (selected) {
                      next.add(id);
                    } else {
                      next.remove(id);
                    }
                    ref.read(holdingSelectionProvider.notifier).state = next;
                  },
                  onSelectAllChanged: (all) {
                    ref.read(holdingSelectionProvider.notifier).state = all
                        ? {for (final h in visible) h.id}
                        : const <String>{};
                  },
                  onRowTap: (holding) =>
                      showHoldingDetailDrawer(context, holding.id),
                ),
        ),
      ],
    );
  }
}

/// 全库无持仓:导入与手动添加两个入口。
class _EmptyHoldingsBody extends ConsumerWidget {
  const _EmptyHoldingsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('还没有持仓', style: theme.textTheme.titleMedium),
          const SizedBox(height: FundLensTokens.space2),
          Text(
            '导入 Excel / CSV 或截图识别,或手动添加第一项。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: FundLensTokens.space4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                key: const ValueKey('empty-import'),
                onPressed: () => Actions.maybeInvoke(
                  context,
                  const SelectDestinationIntent(AppDestination.importReview),
                ),
                icon: const Icon(Icons.upload_file),
                label: const Text('导入资产'),
              ),
              const SizedBox(width: FundLensTokens.space3),
              OutlinedButton.icon(
                key: const ValueKey('empty-manual'),
                onPressed: () async {
                  final holding = await showHoldingEditorDialog(context);
                  if (holding == null) return;
                  await ref.read(holdingRepositoryProvider).upsert(holding);
                  if (context.mounted) showHoldingToast(context, '已保存');
                },
                icon: const Icon(Icons.add),
                label: const Text('手动添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 筛选/搜索无结果。
class _NoResultBody extends ConsumerWidget {
  const _NoResultBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(holdingFilterProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('没有符合条件的持仓'),
          const SizedBox(height: FundLensTokens.space3),
          OutlinedButton(
            key: const ValueKey('clear-filters'),
            onPressed: () =>
                ref.read(holdingFilterProvider.notifier).state =
                    filter.cleared(),
            child: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `/d/flutter/bin/flutter.bat test test/features/holdings/ && /d/flutter/bin/flutter.bat analyze`
Expected: 测试全过；analyze No issues。

- [ ] **Step 5: Commit**

```bash
git add apps/fundlens_windows/lib/features/holdings/ apps/fundlens_windows/test/features/holdings/
git commit -m "feat(holdings): 页面重组——工具栏/批量条/计数/空状态/抽屉接线"
```

---

### Task 8: 回归门禁

**Files:** 无代码改动（验证任务）。

- [ ] **Step 1: flutter analyze 零告警**

Run（从 `apps/fundlens_windows`）：`/d/flutter/bin/flutter.bat analyze`
Expected: `No issues found!`

- [ ] **Step 2: 全量 flutter test（sqlite3mc 包装）**

Run（从 `apps/fundlens_windows`）：`python ../../tools/with_sqlite3mc_server.py 8765 /d/flutter/bin/flutter.bat test`
Expected: 全过（基线 311 + 本分支新增约 40 个，总数 ≥ 351），0 失败。

- [ ] **Step 3: core dart test**

Run（从 `packages/fundlens_core`）：`/d/flutter/bin/cache/dart-sdk/bin/dart.exe test`
Expected: 全过（19 个）。

- [ ] **Step 4: 条件提交**

仅当上述步骤产生了文件修改（如 analyze 修复）才提交；全绿且无改动则无需提交。

```bash
git add -A apps/fundlens_windows packages/fundlens_core
git commit -m "chore(holdings): 回归门禁清理"
```
