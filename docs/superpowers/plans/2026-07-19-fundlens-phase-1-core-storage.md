# FundLens Phase 1 Core and Encrypted Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立可独立测试的纯 Dart 资产领域模型、组合计算、不可变快照和 Windows 加密数据库，为后续数据引擎与 UI 提供稳定接口。

**Architecture:** `packages/fundlens_core` 不依赖 Flutter、数据库或网络；`apps/fundlens_windows` 通过 Drift repository 实现核心端口。数据库在后台 isolate 运行，使用 sqlite3mc 加密，随机数据库密钥只保存到 Windows 安全存储。

**Tech Stack:** Dart 3.10+、Flutter 3.38+、decimal、Drift、sqlite3/sqlite3mc、flutter_secure_storage、Riverpod、package:test、flutter_test。

## Global Constraints

- 只创建 Windows 平台应用；不得生成或启用 Android、iOS、Web、macOS、Linux。
- 所有领域数值使用 `Decimal`；SQLite 中以规范十进制字符串保存。
- 当前持仓可变，历史快照不可变。
- `cumulativeProfit` 不进入当前浮动盈亏汇总。
- 成本为空或为零时收益率为空。
- 快照比较只输出资产金额和结构变化，不输出投资收益。
- 数据库必须在 Windows release 构建中验证 `PRAGMA cipher` 非空；验证失败时拒绝启动正式数据库。
- 依赖解析后提交 `pubspec.lock`，后续任务不得隐式升级。

---

### Task 1: Bootstrap the Windows-only workspace

**Files:**
- Create: `tools/verify_windows_toolchain.ps1`
- Create: `apps/fundlens_windows/`（由 Flutter CLI 生成）
- Create: `packages/fundlens_core/`（由 Dart CLI 生成）
- Modify: `apps/fundlens_windows/pubspec.yaml`
- Modify: `packages/fundlens_core/pubspec.yaml`
- Modify: `apps/fundlens_windows/lib/main.dart`
- Delete: `apps/fundlens_windows/test/widget_test.dart`
- Test: `apps/fundlens_windows/test/app_smoke_test.dart`

**Interfaces:**
- Produces: Windows Flutter runner、`fundlens_core` Dart 包、固定依赖 lockfile。
- Consumes: Windows 10/11、Visual Studio 2022 C++ Desktop workload、C++ ATL、Flutter stable `>=3.38`、Dart `>=3.10`。

- [ ] **Step 1: Add the prerequisite gate**

```powershell
$ErrorActionPreference = 'Stop'
$commands = @('git', 'flutter', 'dart')
foreach ($command in $commands) {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $command"
  }
}

# Locate vswhere (installed with Visual Studio).
$vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path $vswhere)) {
  $vswhere = (Get-Command vswhere -ErrorAction SilentlyContinue)?.Source
}
if (-not $vswhere) {
  throw 'vswhere not found. Install Visual Studio 2022 with the C++ Desktop workload.'
}

$vsPath = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath
if (-not $vsPath) {
  throw 'Visual Studio 2022 C++ Desktop workload is not installed.'
}

$hasAtl = & $vswhere -latest -products * `
  -requires Microsoft.VisualStudio.Component.VC.ATL `
  -property installationPath
if (-not $hasAtl) {
  throw 'Visual Studio C++ ATL is not installed.'
}

foreach ($tool in @('cmake', 'ninja', 'cl')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "Missing Windows build tool: $tool"
  }
}

flutter config --enable-windows-desktop
$devices = flutter devices
if ($devices -notmatch 'Windows') {
  throw 'Flutter Windows desktop device is unavailable.'
}
flutter doctor -v
```

- [ ] **Step 2: Run the prerequisite gate**

Run: `powershell -ExecutionPolicy Bypass -File tools/verify_windows_toolchain.ps1`

Expected: exit code `0`; `flutter doctor -v` reports a usable Windows toolchain and the script confirms Visual Studio C++, C++ ATL, CMake, Ninja and the Windows SDK are present. Do not continue if any component is missing.

- [ ] **Step 3: Generate only the required projects**

```powershell
flutter create --platforms=windows --org com.fundlens apps/fundlens_windows
dart create --template=package packages/fundlens_core
cd packages/fundlens_core
dart pub add decimal collection meta
dart pub add --dev test lints
cd ../../apps/fundlens_windows
flutter pub add flutter_riverpod drift sqlite3 path path_provider flutter_secure_storage uuid
flutter pub add --dev drift_dev build_runner mocktail
```

Then add the local core dependency and sqlite3mc hook at the root of `apps/fundlens_windows/pubspec.yaml`:

```yaml
dependencies:
  fundlens_core:
    path: ../../packages/fundlens_core

hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

- [ ] **Step 4: Replace the generated counter with a deterministic shell**

Delete the generated counter test, then add:

```dart
// apps/fundlens_windows/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FundLensBootstrapApp()));
}

class FundLensBootstrapApp extends StatelessWidget {
  const FundLensBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FundLens',
        home: const Scaffold(body: Center(child: Text('FundLens'))),
      );
}
```

```dart
// apps/fundlens_windows/test/app_smoke_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/main.dart';

void main() {
  testWidgets('boots the Windows shell', (tester) async {
    await tester.pumpWidget(const FundLensBootstrapApp());
    expect(find.text('FundLens'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Verify and commit the bootstrap**

Run: `dart test packages/fundlens_core && flutter test apps/fundlens_windows && flutter analyze apps/fundlens_windows`

Expected: all tests pass; analyzer reports no issues; both lockfiles exist.

```bash
git add tools apps/fundlens_windows packages/fundlens_core
git commit -m "build: bootstrap FundLens Windows workspace"
```

---

### Task 2: Define canonical asset values and holdings

**Files:**
- Create: `packages/fundlens_core/lib/src/model/decimal_value.dart`
- Create: `packages/fundlens_core/lib/src/model/holding.dart`
- Create: `packages/fundlens_core/lib/src/model/field_provenance.dart`
- Modify: `packages/fundlens_core/lib/fundlens_core.dart`
- Test: `packages/fundlens_core/test/model/holding_test.dart`

**Interfaces:**
- Produces: `DecimalValue`, `Holding`, `SourcePlatform`, `InstrumentType`, `AssetClass`, `ValuationMethod`, `DataOrigin`, `FieldProvenance`.
- Consumes: `package:decimal/decimal.dart`.

- [ ] **Step 1: Write failing normalization tests**

```dart
import 'package:fundlens_core/fundlens_core.dart';
import 'package:test/test.dart';

void main() {
  test('decimal values serialize without binary floating point', () {
    expect(DecimalValue.parse('78347.8700').canonical, '78347.87');
    expect(DecimalValue.parse('-0.00').canonical, '0');
  });

  test('holding keeps cumulative profit separate from holding profit', () {
    final holding = Holding(
      id: 'h1',
      sourcePlatform: SourcePlatform.alipay,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.fixedIncome,
      productName: '脱敏纯债基金A',
      currency: 'CNY',
      currentValue: DecimalValue.parse('78347.87'),
      holdingProfit: DecimalValue.parse('428.96'),
      cumulativeProfit: DecimalValue.parse('888.88'),
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: DataOrigin.ocr,
      fieldProvenance: const {},
      createdAt: DateTime.utc(2026, 7, 19),
      updatedAt: DateTime.utc(2026, 7, 19),
    );
    expect(holding.currentFloatingProfit?.canonical, '428.96');
  });
}
```

- [ ] **Step 2: Run the model tests and confirm failure**

Run: `dart test packages/fundlens_core/test/model/holding_test.dart`

Expected: FAIL because `DecimalValue` and `Holding` do not exist.

- [ ] **Step 3: Implement canonical values and the complete holding contract**

```dart
// packages/fundlens_core/lib/src/model/decimal_value.dart
import 'package:decimal/decimal.dart';

final class DecimalValue implements Comparable<DecimalValue> {
  DecimalValue._(this.value);
  final Decimal value;

  factory DecimalValue.parse(String source) {
    final parsed = Decimal.parse(source);
    return DecimalValue._(parsed == Decimal.zero ? Decimal.zero : parsed);
  }

  static final zero = DecimalValue._(Decimal.zero);
  String get canonical => value.toString();
  DecimalValue operator +(DecimalValue other) => DecimalValue._(value + other.value);
  DecimalValue operator -(DecimalValue other) => DecimalValue._(value - other.value);
  DecimalValue operator *(DecimalValue other) => DecimalValue._(value * other.value);
  DecimalValue divide(DecimalValue other, {int scale = 8}) =>
      DecimalValue._((value / other.value).toDecimal(scaleOnInfinitePrecision: scale));
  bool get isZero => value == Decimal.zero;
  bool get isNegative => value < Decimal.zero;
  @override
  int compareTo(DecimalValue other) => value.compareTo(other.value);
  @override
  bool operator ==(Object other) => other is DecimalValue && value == other.value;
  @override
  int get hashCode => value.hashCode;
}
```

```dart
// packages/fundlens_core/lib/src/model/field_provenance.dart
enum ProvenanceKind { original, inferred, market, userCorrected }

final class FieldProvenance {
  const FieldProvenance({required this.kind, required this.source});
  final ProvenanceKind kind;
  final String source;
}
```

```dart
// packages/fundlens_core/lib/src/model/holding.dart
import 'decimal_value.dart';
import 'field_provenance.dart';

enum SourcePlatform { alipay, ths, manual }
enum InstrumentType { cashManagement, bankDeposit, stock, etf, lof, reit, offExchangeFund, accumulatedGold, physicalGold }
enum AssetClass { cash, deposit, equity, fixedIncome, mixed, gold, other }
enum ValuationMethod { automaticQuote, quantityTimesPrice, manualAmount }
enum DataOrigin { manual, excel, csv, ocr }

final class Holding {
  const Holding({
    required this.id,
    required this.sourcePlatform,
    required this.instrumentType,
    required this.assetClass,
    required this.productName,
    required this.currency,
    required this.currentValue,
    required this.valuationMethod,
    required this.dataOrigin,
    required this.fieldProvenance,
    required this.createdAt,
    required this.updatedAt,
    this.productCode,
    this.quantity,
    this.availableQuantity,
    this.currentPrice,
    this.costPrice,
    this.costAmount,
    this.holdingProfit,
    this.holdingReturn,
    this.dailyProfit,
    this.cumulativeProfit,
    this.platformTags = const [],
    this.valuationDate,
    this.note,
  });

  final String id;
  final SourcePlatform sourcePlatform;
  final InstrumentType instrumentType;
  final AssetClass assetClass;
  final String productName;
  final String? productCode;
  final String currency;
  final DecimalValue? quantity;
  final DecimalValue? availableQuantity;
  final DecimalValue? currentPrice;
  final DecimalValue? costPrice;
  final DecimalValue currentValue;
  final DecimalValue? costAmount;
  final DecimalValue? holdingProfit;
  final DecimalValue? holdingReturn;
  final DecimalValue? dailyProfit;
  final DecimalValue? cumulativeProfit;
  final List<String> platformTags;
  final ValuationMethod valuationMethod;
  final DateTime? valuationDate;
  final DataOrigin dataOrigin;
  final Map<String, FieldProvenance> fieldProvenance;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  DecimalValue? get currentFloatingProfit =>
      holdingProfit ?? (costAmount == null ? null : currentValue - costAmount!);

  /// Effective cost for return calculations.
  /// When [costAmount] is absent but [holdingProfit] is present, infer cost
  /// as `currentValue - holdingProfit` to keep Alipay-style holdings in the
  /// return denominator, matching the specification in §9.1.
  DecimalValue? get effectiveCostAmount =>
      costAmount ?? (holdingProfit == null ? null : currentValue - holdingProfit!);
}
```

Export all three files from `fundlens_core.dart`.

- [ ] **Step 4: Run tests and analyzer**

Run: `dart format packages/fundlens_core && dart test packages/fundlens_core && dart analyze packages/fundlens_core`

Expected: PASS with no analyzer issues.

- [ ] **Step 5: Commit the model**

```bash
git add packages/fundlens_core
git commit -m "feat(core): define canonical holding model"
```

---

### Task 3: Implement portfolio calculations and structural observations

**Files:**
- Create: `packages/fundlens_core/lib/src/analysis/portfolio_summary.dart`
- Create: `packages/fundlens_core/lib/src/analysis/portfolio_calculator.dart`
- Create: `packages/fundlens_core/lib/src/analysis/data_quality.dart`
- Test: `packages/fundlens_core/test/analysis/portfolio_calculator_test.dart`
- Modify: `packages/fundlens_core/lib/fundlens_core.dart`

**Interfaces:**
- Consumes: `List<Holding>`.
- Produces: `PortfolioCalculator.calculate(List<Holding>) -> PortfolioSummary`.

- [ ] **Step 1: Write the failing calculation test**

```dart
import 'package:fundlens_core/fundlens_core.dart';
import 'package:test/test.dart';

Holding h(String id, String value, {String? cost, AssetClass asset = AssetClass.equity}) => Holding(
  id: id,
  sourcePlatform: SourcePlatform.manual,
  instrumentType: InstrumentType.stock,
  assetClass: asset,
  productName: id,
  currency: 'CNY',
  currentValue: DecimalValue.parse(value),
  costAmount: cost == null ? null : DecimalValue.parse(cost),
  valuationMethod: ValuationMethod.manualAmount,
  dataOrigin: DataOrigin.manual,
  fieldProvenance: const {},
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('summary excludes missing cost from return denominator', () {
    final result = PortfolioCalculator().calculate([
      h('stock', '120', cost: '100'),
      h('deposit', '80', asset: AssetClass.deposit),
    ]);
    expect(result.totalValue.canonical, '200');
    expect(result.totalCost.canonical, '100');
    expect(result.totalFloatingProfit.canonical, '20');
    expect(result.totalReturn?.canonical, '0.2');
    expect(result.returnCoverage.canonical, '0.6');
    expect(result.byAssetClass[AssetClass.equity]?.canonical, '120');
    expect(result.cashAndDepositShare.canonical, '0.4');
    expect(result.largestHoldingShare.canonical, '0.6');
  });

  test('data quality applies valuation-method field requirements', () {
    final quality = DataQualityCalculator().calculate(
      [h('stock', '120', cost: '100')],
      freshQuoteHoldingIds: const {},
    );
    expect(quality.dataCompleteness.compareTo(DecimalValue.zero), greaterThan(0));
    expect(quality.quoteFreshness, isNull);
  });
}
```

- [ ] **Step 2: Run the test and confirm failure**

Run: `dart test packages/fundlens_core/test/analysis/portfolio_calculator_test.dart`

Expected: FAIL because calculator types do not exist.

- [ ] **Step 3: Implement the summary contract and calculator**

```dart
// portfolio_summary.dart
import '../model/decimal_value.dart';
import '../model/holding.dart';

final class PortfolioSummary {
  const PortfolioSummary({
    required this.totalValue,
    required this.totalCost,
    required this.totalFloatingProfit,
    required this.totalReturn,
    required this.returnCoverage,
    required this.byAssetClass,
    required this.byInstrumentType,
    required this.bySource,
    required this.holdingShares,
    required this.largestHoldingShare,
    required this.largestAssetClassShare,
    required this.cashAndDepositShare,
    required this.equityExposureShare,
  });
  final DecimalValue totalValue;
  final DecimalValue totalCost;
  final DecimalValue totalFloatingProfit;
  final DecimalValue? totalReturn;
  final DecimalValue returnCoverage;
  final Map<AssetClass, DecimalValue> byAssetClass;
  final Map<InstrumentType, DecimalValue> byInstrumentType;
  final Map<SourcePlatform, DecimalValue> bySource;
  final Map<String, DecimalValue> holdingShares;
  final DecimalValue largestHoldingShare;
  final DecimalValue largestAssetClassShare;
  final DecimalValue cashAndDepositShare;
  final DecimalValue equityExposureShare;
}
```

```dart
// portfolio_calculator.dart
import '../model/decimal_value.dart';
import '../model/holding.dart';
import 'portfolio_summary.dart';

final class PortfolioCalculator {
  PortfolioSummary calculate(List<Holding> holdings) {
    var total = DecimalValue.zero;
    var cost = DecimalValue.zero;
    var coveredValue = DecimalValue.zero;
    var profit = DecimalValue.zero;
    final byClass = <AssetClass, DecimalValue>{};
    final byType = <InstrumentType, DecimalValue>{};
    final bySource = <SourcePlatform, DecimalValue>{};
    for (final holding in holdings) {
      total += holding.currentValue;
      byClass[holding.assetClass] = (byClass[holding.assetClass] ?? DecimalValue.zero) + holding.currentValue;
      byType[holding.instrumentType] = (byType[holding.instrumentType] ?? DecimalValue.zero) + holding.currentValue;
      bySource[holding.sourcePlatform] = (bySource[holding.sourcePlatform] ?? DecimalValue.zero) + holding.currentValue;
      // Infer cost from holdingProfit when costAmount is missing (Alipay-style).
      final effectiveCost = holding.effectiveCostAmount;
      if (effectiveCost != null && !effectiveCost.isZero) {
        cost += effectiveCost;
        coveredValue += holding.currentValue;
        profit += holding.currentFloatingProfit ?? (holding.currentValue - effectiveCost);
      }
    }
    final shares = <String, DecimalValue>{
      for (final holding in holdings)
        holding.id: total.isZero ? DecimalValue.zero : holding.currentValue.divide(total),
    };
    final classShares = byClass.values
        .map((value) => total.isZero ? DecimalValue.zero : value.divide(total))
        .toList(growable: false);
    final cashAndDeposits = (byClass[AssetClass.cash] ?? DecimalValue.zero) +
        (byClass[AssetClass.deposit] ?? DecimalValue.zero);
    final equities = byClass[AssetClass.equity] ?? DecimalValue.zero;
    return PortfolioSummary(
      totalValue: total,
      totalCost: cost,
      totalFloatingProfit: profit,
      totalReturn: cost.isZero ? null : profit.divide(cost),
      returnCoverage: total.isZero ? DecimalValue.zero : coveredValue.divide(total),
      byAssetClass: Map.unmodifiable(byClass),
      byInstrumentType: Map.unmodifiable(byType),
      bySource: Map.unmodifiable(bySource),
      holdingShares: Map.unmodifiable(shares),
      largestHoldingShare: shares.values.fold(DecimalValue.zero, (a, b) => a.compareTo(b) >= 0 ? a : b),
      largestAssetClassShare: classShares.fold(DecimalValue.zero, (a, b) => a.compareTo(b) >= 0 ? a : b),
      cashAndDepositShare: total.isZero ? DecimalValue.zero : cashAndDeposits.divide(total),
      equityExposureShare: total.isZero ? DecimalValue.zero : equities.divide(total),
    );
  }
}
```

```dart
// data_quality.dart
final class DataQualitySummary {
  const DataQualitySummary({required this.dataCompleteness, required this.quoteFreshness});
  final DecimalValue dataCompleteness;
  final DecimalValue? quoteFreshness;
}

final class DataQualityCalculator {
  DataQualitySummary calculate(List<Holding> holdings, {required Set<String> freshQuoteHoldingIds}) {
    var requiredFields = 0;
    var completeFields = 0;
    var quotedValue = DecimalValue.zero;
    var freshQuotedValue = DecimalValue.zero;
    for (final h in holdings) {
      // Base required fields for every holding.
      final checks = <bool>[
        h.productName.trim().isNotEmpty,
        h.currency.trim().isNotEmpty,
        !h.currentValue.isNegative,
      ];
      if (h.valuationMethod == ValuationMethod.automaticQuote) {
        checks.addAll([
          h.productCode != null && h.productCode!.trim().isNotEmpty,
          h.quantity != null,
          h.currentPrice != null,
          h.valuationDate != null,
        ]);
        quotedValue += h.currentValue;
        if (freshQuoteHoldingIds.contains(h.id)) freshQuotedValue += h.currentValue;
      } else if (h.valuationMethod == ValuationMethod.quantityTimesPrice) {
        checks.addAll([
          h.quantity != null,
          h.currentPrice != null,
          h.valuationDate != null,
        ]);
      }
      requiredFields += checks.length;
      completeFields += checks.where((value) => value).length;
    }
    return DataQualitySummary(
      dataCompleteness: requiredFields == 0
          ? DecimalValue.zero
          : DecimalValue.parse(completeFields.toString()).divide(DecimalValue.parse(requiredFields.toString())),
      quoteFreshness: quotedValue.isZero ? null : freshQuotedValue.divide(quotedValue),
    );
  }
}
```

- [ ] **Step 4: Add edge cases and run all core tests**

Extend the test file with empty portfolio, zero cost, negative profit, gold ETF dual-axis classification, `cumulativeProfit` exclusion, automatic-quote completeness and value-weighted quote freshness assertions. Then run:

Run: `dart test packages/fundlens_core && dart analyze packages/fundlens_core`

Expected: PASS; no floating point literals are used in calculation code.

- [ ] **Step 5: Commit calculations**

```bash
git add packages/fundlens_core
git commit -m "feat(core): calculate portfolio structure and returns"
```

---

### Task 4: Add immutable snapshots and amount-change comparison

**Files:**
- Create: `packages/fundlens_core/lib/src/snapshot/portfolio_snapshot.dart`
- Create: `packages/fundlens_core/lib/src/snapshot/snapshot_diff.dart`
- Test: `packages/fundlens_core/test/snapshot/snapshot_diff_test.dart`
- Modify: `packages/fundlens_core/lib/fundlens_core.dart`

**Interfaces:**
- Produces: `PortfolioSnapshot`, `SnapshotHolding`, `SnapshotDiffService.compare`.
- Consumes: frozen copies of `Holding`; no repository dependency.

- [ ] **Step 1: Write a failing immutable comparison test**

```dart
test('comparison reports amount change without return language', () {
  final before = PortfolioSnapshot.fixture('s1', '100');
  final after = PortfolioSnapshot.fixture('s2', '125');
  final diff = SnapshotDiffService().compare(before, after);
  expect(diff.totalAmountChange.canonical, '25');
  expect(diff.metricLabel, '资产金额变化');
});
```

Add a local `fixture` factory in the test that creates complete `SnapshotHolding` values; do not add fixture-only APIs to production classes.

- [ ] **Step 2: Run the snapshot test and confirm failure**

Run: `dart test packages/fundlens_core/test/snapshot/snapshot_diff_test.dart`

Expected: FAIL because snapshot types do not exist.

- [ ] **Step 3: Implement frozen snapshots and diff output**

```dart
final class PortfolioSnapshot {
  const PortfolioSnapshot({required this.id, required this.label, required this.createdAt, required this.holdings});
  final String id;
  final String label;
  final DateTime createdAt;
  final List<SnapshotHolding> holdings;
}

final class SnapshotHolding {
  const SnapshotHolding({
    required this.holdingId,
    required this.productName,
    required this.instrumentType,
    required this.assetClass,
    required this.sourcePlatform,
    required this.currentValue,
    required this.fieldProvenance,
    this.productCode,
    this.quantity,
    this.currentPrice,
    this.costAmount,
    this.holdingProfit,
    this.dailyProfit,
    this.cumulativeProfit,
    this.valuationDate,
  });
  final String holdingId;
  final String productName;
  final String? productCode;
  final InstrumentType instrumentType;
  final AssetClass assetClass;
  final SourcePlatform sourcePlatform;
  final DecimalValue? quantity;
  final DecimalValue? currentPrice;
  final DecimalValue currentValue;
  final DecimalValue? costAmount;
  final DecimalValue? holdingProfit;
  final DecimalValue? dailyProfit;
  final DecimalValue? cumulativeProfit;
  final DateTime? valuationDate;
  final Map<String, FieldProvenance> fieldProvenance;
}

final class SnapshotDiff {
  const SnapshotDiff({required this.totalAmountChange, required this.holdingAmountChanges, required this.assetClassAmountChanges});
  final String metricLabel = '资产金额变化';
  final DecimalValue totalAmountChange;
  final Map<String, DecimalValue> holdingAmountChanges;
  final Map<AssetClass, DecimalValue> assetClassAmountChanges;
}
```

Implement `SnapshotDiffService.compare(before, after)` by building maps keyed by `holdingId` and `assetClass`, substituting zero for missing sides, and subtracting before from after.

- [ ] **Step 4: Verify added, removed and reclassified holdings**

Run: `dart test packages/fundlens_core && dart analyze packages/fundlens_core`

Expected: PASS for added/removed holdings and asset-class changes; production code contains no `收益` label for snapshot differences.

- [ ] **Step 5: Commit snapshots**

```bash
git add packages/fundlens_core
git commit -m "feat(core): add immutable portfolio snapshots"
```

---

### Task 5: Persist holdings and snapshots in an encrypted Drift database

**Files:**
- Create: `apps/fundlens_windows/lib/storage/app_database.dart`
- Create: `apps/fundlens_windows/lib/storage/tables.dart`
- Create: `apps/fundlens_windows/lib/storage/database_opener.dart`
- Create: `apps/fundlens_windows/lib/storage/database_key_store.dart`
- Create: `apps/fundlens_windows/lib/storage/holding_repository.dart`
- Create: `apps/fundlens_windows/lib/storage/snapshot_repository.dart`
- Create: `apps/fundlens_windows/test/storage/app_database_test.dart`
- Create: `apps/fundlens_windows/integration_test/encrypted_database_test.dart`

**Interfaces:**
- Produces: `HoldingRepository`, `SnapshotRepository`, `openEncryptedDatabase(File, String)`.
- Consumes: core models and `DatabaseKeyStore.readOrCreate()`.

- [ ] **Step 1: Write failing repository and immutability tests**

```dart
test('replacePlatform is atomic and does not touch manual holdings', () async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final repo = DriftHoldingRepository(db);
  await repo.upsert(manualHolding('manual-1'));
  await repo.replacePlatform(SourcePlatform.alipay, [alipayHolding('a1')]);
  final all = await repo.watchAll().first;
  expect(all.map((h) => h.id), containsAll(['manual-1', 'a1']));
});

test('snapshot rows remain unchanged after current holding update', () async {
  final snapshotId = await snapshots.createFromCurrent(label: '2026-07-19');
  await holdings.upsert(changedHolding);
  final saved = await snapshots.getById(snapshotId);
  expect(saved.holdings.single.currentValue.canonical, originalValue);
});
```

- [ ] **Step 2: Run the storage tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/storage/app_database_test.dart`

Expected: FAIL because the database and repositories do not exist.

- [ ] **Step 3: Define schema and encrypted opener**

Define Drift tables for `holding`, `snapshot`, `snapshot_holding`, `import_batch`, `draft_holding`, `data_issue`, `quote_cache`, `classification_rule`, and `app_setting`. Store every decimal as `TEXT`, enums by stable lowercase wire name, tags/provenance as JSON, and timestamps as UTC epoch milliseconds. Add foreign keys with `ON DELETE CASCADE` only from snapshot to snapshot holdings; never cascade from current holdings to snapshots.

```dart
QueryExecutor openEncryptedDatabase(File file, String keyHex) {
  final escaped = keyHex.replaceAll("'", "''");
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      if (rawDb.select('PRAGMA cipher;').isEmpty) {
        throw StateError('Encrypted SQLite runtime is unavailable.');
      }
      rawDb.execute("PRAGMA key = '$escaped';");
      rawDb.execute('PRAGMA foreign_keys = ON;');
      rawDb.execute('PRAGMA journal_mode = WAL;');
      rawDb.select('SELECT count(*) FROM sqlite_master;');
    },
  );
}
```

> **Note on sqlite3mc provisioning:** the `sqlite3` package hooks download the
> sqlite3mc native binary at build time. If this fails due to network, TLS, or
> proxy issues, set `SQLITE3MC_LIBRARY_PATH` to a locally downloaded
> `sqlite3mc.dll` or override the `sqlite3` dependency with a local binary
> source before retrying. Do not proceed with a non-encrypted SQLite runtime.

```dart
abstract interface class DatabaseKeyStore {
  Future<String> readOrCreate();
  Future<void> write(String keyHex);
}

final class SecureDatabaseKeyStore implements DatabaseKeyStore {
  SecureDatabaseKeyStore(this.storage, this.randomBytes);
  final FlutterSecureStorage storage;
  final List<int> Function(int length) randomBytes;
  static const _key = 'fundlens.database.key.v1';

  @override
  Future<String> readOrCreate() async {
    final existing = await storage.read(key: _key);
    if (existing != null) return existing;
    final value = randomBytes(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _key, value: value);
    return value;
  }

  @override
  Future<void> write(String keyHex) => storage.write(key: _key, value: keyHex);
}
```

- [ ] **Step 4: Implement transactional repositories**

`DriftHoldingRepository.replacePlatform` must execute delete/upsert in one `transaction`, and `DriftSnapshotRepository.createFromCurrent` must copy current rows into snapshot rows in the same transaction. Add mappers that round-trip all `Holding` fields and throw on unknown enum wire names instead of defaulting silently.

Run: `cd apps/fundlens_windows && dart run build_runner build --delete-conflicting-outputs && flutter test test/storage/app_database_test.dart`

Expected: PASS, including rollback after an injected insert failure.

- [ ] **Step 5: Prove encryption on Windows**

```dart
test('release runtime exposes cipher and rejects a wrong key', () async {
  final file = File('${Directory.systemTemp.path}/fundlens-cipher-smoke.db');
  final keyA = List.filled(32, '11').join();
  final keyB = List.filled(32, '22').join();
  final db = AppDatabase(openEncryptedDatabase(file, keyA));
  await db.customSelect('PRAGMA cipher;').getSingle();
  await db.close();
  final wrongKeyDb = AppDatabase(openEncryptedDatabase(file, keyB));
  await expectLater(wrongKeyDb.customSelect('SELECT * FROM holding').get(), throwsA(anything));
  await wrongKeyDb.close();
});
```

Run on Windows: `flutter test integration_test/encrypted_database_test.dart -d windows`

Expected: PASS. Also verify the database file does not contain an inserted synthetic product name with `Select-String`.

- [ ] **Step 6: Run the phase gate and commit**

Run: `dart test packages/fundlens_core && flutter test apps/fundlens_windows && flutter analyze apps/fundlens_windows`

Expected: PASS with no analyzer issues.

```bash
git add apps/fundlens_windows packages/fundlens_core
git commit -m "feat(storage): persist encrypted holdings and snapshots"
```

## Phase 1 Completion Gate

- [ ] Pure Dart tests cover every asset class, missing/zero cost, negative profit and cumulative-profit exclusion.
- [ ] Snapshot tests prove immutability and use only “资产金额变化”.
- [ ] Repository tests prove partial platform replacement isolation and transaction rollback.
- [ ] Windows integration test proves sqlite3mc is active and a wrong key cannot read the database.
- [ ] No OCR, market, backup or investment-advice behavior has leaked into the core package.
