# FundLens Phase 3 Asset Spectrum Windows UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将核心能力和数据引擎整合成完整的六页 FundLens Windows 桌面界面，实现手工持仓、资产分析、快照比较与截图校对工作流。

**Architecture:** Flutter 界面只消费 Riverpod application providers，不直接访问数据库表或 Python 包。Asset Spectrum 使用自定义绘制和可访问语义；2,000 行持仓使用虚拟化双区表格，固定名称/金额列并同步滚动。

**Tech Stack:** Flutter Material 3 基础组件、Riverpod、CustomPainter、file_picker、intl、golden tests、内置 Noto CJK 与 IBM Plex Mono 字体资产。

## Global Constraints

- 保持 Windows-only，不创建 Android 构建或触控专用导航。
- 最低窗口 `1280 × 720`；产品名称和当前金额必须始终可见。
- 六个固定页面：资产总览、资产分析、全部持仓、历史快照、导入与识别、设置与备份。
- 数据问题只在“导入与识别”集中处理，其他页面只提供跳转入口。
- 颜色令牌固定：Graphite `#121817`、Frost `#F2F5F3`、Paper `#FFFFFF`、Lens Indigo `#625BD4`、Profit `#C54B40`、Loss `#2E8162`。
- 盈利为红、亏损为绿，但所有状态还必须显示 `+/-` 符号和文本/图标。
- 金融数字使用等宽字体与 `tabularFigures`；领域计算结果不得在 Widget 内重新计算。
- 只有资产光谱在导入/快照切换时使用 300–450 ms 编排动画；系统减少动态效果时禁用。
- 所有关键操作支持键盘焦点；不得把必要信息只放在 hover 中。
- 不出现买入、卖出、加仓、减仓、调仓、再平衡或“快照收益”文案。

---

### Task 1: Implement design tokens, bundled fonts and the six-page shell

**Files:**
- Create: `apps/fundlens_windows/assets/fonts/NotoSansSC-Regular.otf`
- Create: `apps/fundlens_windows/assets/fonts/NotoSansSC-Medium.otf`
- Create: `apps/fundlens_windows/assets/fonts/NotoSerifSC-SemiBold.otf`
- Create: `apps/fundlens_windows/assets/fonts/IBMPlexMono-Regular.ttf`
- Create: `apps/fundlens_windows/assets/fonts/OFL-Noto.txt`
- Create: `apps/fundlens_windows/assets/fonts/OFL-IBMPlex.txt`
- Modify: `apps/fundlens_windows/pubspec.yaml`
- Create: `apps/fundlens_windows/lib/theme/fundlens_tokens.dart`
- Create: `apps/fundlens_windows/lib/theme/fundlens_theme.dart`
- Create: `apps/fundlens_windows/lib/app/fundlens_app.dart`
- Create: `apps/fundlens_windows/lib/app/app_shell.dart`
- Test: `apps/fundlens_windows/test/app/app_shell_test.dart`
- Test: `apps/fundlens_windows/test/theme/theme_test.dart`

**Interfaces:**
- Produces: `FundLensTokens`, `FundLensTheme.light`, `AppDestination`, `AppShell`.
- Consumes: six page widgets injected by `FundLensApp`.

- [x] **Step 1: Add licensed font files and failing token tests**

Acquire the exact font files from the official Google Noto CJK and IBM Plex repositories, include their OFL license files, and register them locally in `pubspec.yaml`; the application must not fetch fonts at runtime.

```dart
test('financial semantic colors follow the approved China convention', () {
  expect(FundLensTokens.profit, const Color(0xFFC54B40));
  expect(FundLensTokens.loss, const Color(0xFF2E8162));
});

testWidgets('shell exposes all six destinations', (tester) async {
  await tester.pumpWidget(const TestFundLensApp());
  for (final label in ['资产总览','资产分析','全部持仓','历史快照','导入与识别','设置与备份']) {
    expect(find.text(label), findsOneWidget);
  }
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/theme apps/fundlens_windows/test/app`

Expected: FAIL because tokens and shell do not exist.

- [x] **Step 3: Implement tokens and theme**

```dart
abstract final class FundLensTokens {
  static const graphite = Color(0xFF121817);
  static const frost = Color(0xFFF2F5F3);
  static const paper = Color(0xFFFFFFFF);
  static const lensIndigo = Color(0xFF625BD4);
  static const profit = Color(0xFFC54B40);
  static const loss = Color(0xFF2E8162);
  static const divider = Color(0xFFDDE3DF);
  static const muted = Color(0xFF65706C);
  static const double navWidth = 224;
  static const double pagePadding = 28;
  static const double rowHeight = 56;
}
```

`FundLensTheme.light` must use Frost scaffold background, Paper surfaces, Graphite text, 1 px dividers, 4/8 px corner radii, no broad elevation shadows, Noto Sans SC for UI, Noto Serif SC for page titles, and IBM Plex Mono for `financialNumber` text style.

- [x] **Step 4: Implement the desktop shell**

```dart
enum AppDestination { overview, analysis, holdings, snapshots, importReview, settings }

const destinationLabels = {
  AppDestination.overview: '资产总览',
  AppDestination.analysis: '资产分析',
  AppDestination.holdings: '全部持仓',
  AppDestination.snapshots: '历史快照',
  AppDestination.importReview: '导入与识别',
  AppDestination.settings: '设置与备份',
};
```

Build `AppShell` as a `Row` with a fixed-width Graphite navigation region and an `Expanded` content region. Use `IndexedStack` so page switches retain search/filter state. Add `Shortcuts` for `Ctrl+1` through `Ctrl+6`, visible focus indicators, and a top data-status button that navigates to `importReview` without adding another destination.

- [x] **Step 5: Verify at all target sizes and commit**

Run: `flutter test apps/fundlens_windows/test/theme apps/fundlens_windows/test/app && flutter analyze apps/fundlens_windows`

Expected: PASS at test surfaces `1280×720`, `1440×900`, `1920×1080`; no overflow exceptions.

```bash
git add apps/fundlens_windows/assets apps/fundlens_windows/pubspec.yaml apps/fundlens_windows/lib/theme apps/fundlens_windows/lib/app apps/fundlens_windows/test/theme apps/fundlens_windows/test/app
git commit -m "feat(ui): add Asset Spectrum desktop shell"
```

---

### Task 2: Wire repository streams into stable application providers

**Files:**
- Create: `apps/fundlens_windows/lib/application/app_dependencies.dart`
- Create: `apps/fundlens_windows/lib/application/portfolio_state.dart`
- Create: `apps/fundlens_windows/lib/application/portfolio_providers.dart`
- Create: `apps/fundlens_windows/lib/application/selection_state.dart`
- Test: `apps/fundlens_windows/test/application/portfolio_providers_test.dart`

**Interfaces:**
- Produces: `holdingsProvider`, `portfolioSummaryProvider`, `dataQualityProvider`, `snapshotsProvider`, `dataIssuesProvider`, `selectedAssetClassProvider`.
- Consumes: Phase 1 repositories, `PortfolioCalculator`, Phase 2 import and quote services.

- [x] **Step 1: Write failing provider cache tests**

```dart
test('page consumers share one holdings subscription', () async {
  final repository = CountingHoldingRepository([fixtureHolding]);
  final container = ProviderContainer(overrides: [holdingRepositoryProvider.overrideWithValue(repository)]);
  addTearDown(container.dispose);
  await container.read(holdingsProvider.future);
  container.read(portfolioSummaryProvider);
  container.read(filteredHoldingsProvider);
  expect(repository.watchCount, 1);
});
```

- [x] **Step 2: Run test and confirm failure**

Run: `flutter test apps/fundlens_windows/test/application/portfolio_providers_test.dart`

Expected: FAIL because providers do not exist.

- [x] **Step 3: Implement application providers**

```dart
final holdingsProvider = StreamProvider<List<Holding>>((ref) {
  return ref.watch(holdingRepositoryProvider).watchAll();
});

final portfolioSummaryProvider = Provider<PortfolioSummary>((ref) {
  final holdings = ref.watch(holdingsProvider).valueOrNull ?? <Holding>[];
  return ref.watch(portfolioCalculatorProvider).calculate(holdings);
});

final selectedAssetClassProvider = StateProvider<AssetClass?>((ref) => null);

final dataQualityProvider = Provider<DataQualitySummary>((ref) {
  final holdings = ref.watch(holdingsProvider).valueOrNull ?? <Holding>[];
  final freshIds = ref.watch(freshQuoteHoldingIdsProvider);
  return ref.watch(dataQualityCalculatorProvider).calculate(holdings, freshQuoteHoldingIds: freshIds);
});

final filteredHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(holdingsProvider).valueOrNull ?? <Holding>[];
  final selected = ref.watch(selectedAssetClassProvider);
  return selected == null ? holdings : holdings.where((h) => h.assetClass == selected).toList(growable: false);
});
```

Create dependency providers that throw `UnimplementedError` unless overridden by bootstrap, then override them once in `main.dart` after database/engine initialization. Widgets must never instantiate repositories or engine clients.

- [x] **Step 4: Verify one subscription and deterministic loading/error states**

Run: `flutter test apps/fundlens_windows/test/application && flutter analyze apps/fundlens_windows`

Expected: PASS; loading, empty, data and degraded states are distinct.

- [x] **Step 5: Commit state wiring**

```bash
git add apps/fundlens_windows/lib/application apps/fundlens_windows/test/application apps/fundlens_windows/lib/main.dart
git commit -m "feat(app): expose portfolio application state"
```

---

### Task 3: Build manual CRUD and the virtualized holdings table

**Files:**
- Create: `apps/fundlens_windows/lib/features/holdings/holdings_page.dart`
- Create: `apps/fundlens_windows/lib/features/holdings/holding_grid.dart`
- Create: `apps/fundlens_windows/lib/features/holdings/holding_filters.dart`
- Create: `apps/fundlens_windows/lib/features/holdings/holding_editor_dialog.dart`
- Create: `apps/fundlens_windows/lib/features/holdings/holding_export_service.dart`
- Test: `apps/fundlens_windows/test/features/holdings/holding_editor_test.dart`
- Test: `apps/fundlens_windows/test/features/holdings/holding_grid_test.dart`
- Test: `apps/fundlens_windows/test/features/holdings/holding_export_test.dart`

**Interfaces:**
- Produces: three `HoldingColumnPreset` values: portfolio, trading, platform.
- Consumes: `filteredHoldingsProvider`, holding repository, quote refresh service.

- [x] **Step 1: Write failing editor and grid tests**

```dart
testWidgets('manual editor requires name and current amount', (tester) async {
  await tester.pumpWidget(editorHarness());
  await tester.tap(find.text('保存'));
  await tester.pump();
  expect(find.text('请输入产品名称'), findsOneWidget);
  expect(find.text('请输入当前金额'), findsOneWidget);
});

testWidgets('1280 width keeps name and amount visible', (tester) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(gridHarness(holdings: generateHoldings(2000)));
  expect(find.text('产品名称'), findsOneWidget);
  expect(find.text('当前金额'), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/features/holdings`

Expected: FAIL because holdings widgets do not exist.

- [x] **Step 3: Implement manual editor and filtering**

The editor fields are source, product form, asset class, name, code, quantity, price, current amount, cost, valuation date and note. Parse decimals with `DecimalValue.parse`, show field-level errors, and submit only a full `Holding` with `DataOrigin.manual` and user-corrected provenance. Delete requires a dialog naming the product; refresh is disabled for manual amount-only assets.

```dart
enum HoldingColumnPreset { portfolio, trading, platform }

final class HoldingFilterState {
  const HoldingFilterState({this.query = '', this.sources = const {}, this.assetClasses = const {}, this.preset = HoldingColumnPreset.portfolio, this.sort = HoldingSort.currentValueDescending});
  final String query;
  final Set<SourcePlatform> sources;
  final Set<AssetClass> assetClasses;
  final HoldingColumnPreset preset;
  final HoldingSort sort;
}
```

- [x] **Step 4: Implement the virtualized frozen grid and CSV export**

Use two `ListView.builder` regions: a 420 px frozen region for name/source and current amount, plus a horizontally scrollable region for preset-specific columns. Synchronize vertical controllers with a reentrancy guard. Both lists must use `itemExtent = FundLensTokens.rowHeight` and build only visible rows. Format values in a dedicated formatter; do not compute profits in row widgets.

`HoldingExportService.exportCsv(filtered, path)` exports exactly the current sorted/filtered rows, UTF-8 BOM, canonical decimal strings and Chinese headers.

- [x] **Step 5: Verify 2,000 rows and commit**

Run: `flutter test apps/fundlens_windows/test/features/holdings && flutter analyze apps/fundlens_windows`

Expected: PASS; a builder-count assertion proves fewer than 100 row widgets are built for 2,000 holdings.

```bash
git add apps/fundlens_windows/lib/features/holdings apps/fundlens_windows/test/features/holdings
git commit -m "feat(ui): add virtualized holdings workspace"
```

---

### Task 4: Build the overview and interactive Asset Spectrum

**Files:**
- Create: `apps/fundlens_windows/lib/features/overview/overview_page.dart`
- Create: `apps/fundlens_windows/lib/features/overview/asset_spectrum.dart`
- Create: `apps/fundlens_windows/lib/features/overview/summary_strip.dart`
- Create: `apps/fundlens_windows/lib/features/overview/structure_observations.dart`
- Test: `apps/fundlens_windows/test/features/overview/asset_spectrum_test.dart`
- Test: `apps/fundlens_windows/test/features/overview/overview_golden_test.dart`
- Create: `apps/fundlens_windows/test/goldens/overview_1440x900.png`

**Interfaces:**
- Consumes: `PortfolioSummary`, holdings, selected asset class, data freshness.
- Produces: selection events updating `selectedAssetClassProvider` and a semantic description per segment.

- [x] **Step 1: Write failing spectrum interaction and semantic tests**

```dart
testWidgets('clicking a spectrum segment filters holdings', (tester) async {
  await tester.pumpWidget(overviewHarness());
  await tester.tap(find.byKey(const ValueKey('spectrum-equity')));
  await tester.pump();
  expect(container.read(selectedAssetClassProvider), AssetClass.equity);
});

testWidgets('segment semantics include class amount and share', (tester) async {
  final semantics = tester.ensureSemantics();
  await tester.pumpWidget(overviewHarness());
  expect(find.bySemanticsLabel(contains('权益')), findsOneWidget);
  expect(find.bySemanticsLabel(contains('占比')), findsOneWidget);
  semantics.dispose();
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/features/overview`

Expected: FAIL because overview widgets do not exist.

- [x] **Step 3: Implement segment geometry and painter**

```dart
final class SpectrumSegment {
  const SpectrumSegment({required this.assetClass, required this.start, required this.end, required this.color, required this.amount, required this.share});
  final AssetClass assetClass;
  final double start;
  final double end;
  final Color color;
  final DecimalValue amount;
  final DecimalValue share;
}
```

Map exact Decimal shares to cumulative double geometry only at the rendering boundary. Paint a 20 px horizontal spectrum with 2 px Paper separators, focused Indigo outline and a selected detail rail. Wrap each segment in a positioned transparent `Semantics`/`FocusableActionDetector` hit target. Arrow keys move focus; Enter/Space selects; Escape clears.

- [x] **Step 4: Build the overview composition**

Top summary strip shows total assets, covered cost, floating profit, total return and return coverage. Below it place the spectrum, structure observations, top holdings and quote freshness. Empty portfolios show one direct “添加第一项资产” action. Observations use factual text such as “最大单项占总资产 34.9%”; no ideal allocation or action verbs.

Animate only segment bounds for 400 ms with `Curves.easeOutCubic`; if `MediaQuery.disableAnimations` is true, duration is zero.

- [x] **Step 5: Verify golden and commit**

Run: `flutter test apps/fundlens_windows/test/features/overview --update-goldens` once after visual review, then rerun without `--update-goldens`.

Expected: golden matches at `1440×900`; profit/loss signs remain readable in grayscale semantics.

```bash
git add apps/fundlens_windows/lib/features/overview apps/fundlens_windows/test/features/overview apps/fundlens_windows/test/goldens
git commit -m "feat(ui): add interactive Asset Spectrum overview"
```

---

### Task 5: Implement structural analysis and snapshot comparison pages

**Files:**
- Create: `apps/fundlens_windows/lib/features/analysis/analysis_page.dart`
- Create: `apps/fundlens_windows/lib/features/analysis/composition_table.dart`
- Create: `apps/fundlens_windows/lib/features/analysis/concentration_panel.dart`
- Create: `apps/fundlens_windows/lib/features/snapshots/snapshots_page.dart`
- Create: `apps/fundlens_windows/lib/features/snapshots/snapshot_compare_view.dart`
- Test: `apps/fundlens_windows/test/features/analysis/analysis_page_test.dart`
- Test: `apps/fundlens_windows/test/features/snapshots/snapshot_compare_test.dart`

**Interfaces:**
- Consumes: `PortfolioSummary`, user thresholds, `SnapshotRepository`, `SnapshotDiffService`.
- Produces: class/type/source composition views and two-snapshot comparison.

- [x] **Step 1: Write failing language and comparison tests**

```dart
testWidgets('analysis does not emit allocation advice', (tester) async {
  await tester.pumpWidget(analysisHarness());
  for (final forbidden in ['建议', '应当', '调仓', '再平衡', '买入', '卖出']) {
    expect(find.textContaining(forbidden), findsNothing);
  }
});

testWidgets('snapshot comparison labels the delta as amount change', (tester) async {
  await tester.pumpWidget(snapshotHarness());
  expect(find.text('资产金额变化'), findsOneWidget);
  expect(find.textContaining('快照收益'), findsNothing);
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/features/analysis apps/fundlens_windows/test/features/snapshots`

Expected: FAIL because pages do not exist.

- [x] **Step 3: Implement factual structure analysis**

Use tab-like segmented controls for asset class, instrument type and source. Each view renders an exact amount/share table plus a thin proportional bar. Show largest holding, largest class, cash+deposit share, equity exposure, data completeness, return coverage and quote freshness. Compare only against thresholds explicitly set by the user; when none exist, show actual values without status judgment.

- [x] **Step 4: Implement snapshot creation, deletion and comparison**

Snapshot creation opens a label dialog, then invokes `createFromCurrent`. Deletion names the date/label and requires confirmation. Two selectors default to the two latest snapshots; comparison shows total amount change, class changes and holding changes, with added/removed badges. Disable compare when fewer than two snapshots exist. Never edit snapshot rows.

- [x] **Step 5: Run tests and commit**

Run: `flutter test apps/fundlens_windows/test/features/analysis apps/fundlens_windows/test/features/snapshots && flutter analyze apps/fundlens_windows`

Expected: PASS; forbidden-copy scan finds no advice language.

```bash
git add apps/fundlens_windows/lib/features/analysis apps/fundlens_windows/lib/features/snapshots apps/fundlens_windows/test/features/analysis apps/fundlens_windows/test/features/snapshots
git commit -m "feat(ui): add structure and snapshot analysis"
```

---

### Task 6: Build the import, OCR review and data-issue workspace

**Files:**
- Create: `apps/fundlens_windows/lib/features/import_review/import_review_page.dart`
- Create: `apps/fundlens_windows/lib/features/import_review/import_source_panel.dart`
- Create: `apps/fundlens_windows/lib/features/import_review/ocr_field_editor.dart`
- Create: `apps/fundlens_windows/lib/features/import_review/screenshot_crop_view.dart`
- Create: `apps/fundlens_windows/lib/features/import_review/import_diff_panel.dart`
- Create: `apps/fundlens_windows/lib/features/import_review/data_issue_list.dart`
- Create: `apps/fundlens_windows/lib/features/import_review/import_review_controller.dart`
- Test: `apps/fundlens_windows/test/features/import_review/import_review_test.dart`
- Test: `apps/fundlens_windows/test/features/import_review/ocr_field_editor_test.dart`

**Interfaces:**
- Consumes: file picker, `DataEngineClient`, tabular parser, import planner/commit service.
- Produces: resumable import draft state and explicit commit action.

- [x] **Step 1: Write failing safety workflow tests**

```dart
testWidgets('screenshot import defaults to partial mode', (tester) async {
  await tester.pumpWidget(importHarness());
  await tester.tap(find.text('导入截图'));
  await tester.pump();
  expect(find.text('部分持仓'), findsOneWidget);
  expect(selectedMode(), ImportMode.partial);
});

testWidgets('blocking OCR issue disables confirmation', (tester) async {
  await tester.pumpWidget(importHarness(issue: blockingSignIssue));
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '确认写入')).onPressed, isNull);
});

testWidgets('field selection shows its source crop', (tester) async {
  await tester.pumpWidget(importHarness(field: lowConfidenceAmount));
  await tester.tap(find.text('78,347.87'));
  await tester.pump();
  expect(find.byKey(const ValueKey('ocr-crop-current_value')), findsOneWidget);
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/features/import_review`

Expected: FAIL because import review widgets do not exist.

- [x] **Step 3: Implement controller state machine**

```dart
sealed class ImportReviewState { const ImportReviewState(); }
final class ImportIdle extends ImportReviewState { const ImportIdle(); }
final class ImportParsing extends ImportReviewState { const ImportParsing(this.progress); final double? progress; }
final class ImportEditing extends ImportReviewState { const ImportEditing(this.draft, this.plan); final ImportDraft draft; final ImportPlan plan; }
final class ImportCommitting extends ImportReviewState { const ImportCommitting(); }
final class ImportCommitted extends ImportReviewState { const ImportCommitted(this.report); final ImportCommitReport report; }
final class ImportFailed extends ImportReviewState { const ImportFailed(this.message, this.retryable); final String message; final bool retryable; }
```

The controller persists drafts, supports cancel, restores an uncommitted draft after restart, and clears temporary screenshot copies only after successful commit or explicit discard. It never deletes the user's original selected files.

- [x] **Step 4: Implement side-by-side review and diff**

Left panel shows the selected screenshot and exact field crop; right panel shows editable fields with confidence badges and provenance. Selecting an issue focuses the corresponding field/crop. The bottom diff lists added, updated, possible duplicates and possible removals. Full mode uses a warning panel and a second confirmation listing removal count. Product candidates require an explicit radio selection.

- [x] **Step 5: Verify end-to-end import UI and commit**

Run: `flutter test apps/fundlens_windows/test/features/import_review && flutter analyze apps/fundlens_windows`

Expected: PASS for CSV, Excel, Alipay OCR, THS OCR, cancellation, draft recovery, partial commit, full commit and blocking issues.

```bash
git add apps/fundlens_windows/lib/features/import_review apps/fundlens_windows/test/features/import_review
git commit -m "feat(ui): add import and OCR review workspace"
```

---

### Task 7: Add settings surface and cross-page UI acceptance

**Files:**
- Create: `apps/fundlens_windows/lib/features/settings/settings_page.dart`
- Create: `apps/fundlens_windows/lib/features/settings/structure_thresholds_section.dart`
- Create: `apps/fundlens_windows/lib/features/settings/market_settings_section.dart`
- Create: `apps/fundlens_windows/lib/features/settings/privacy_section.dart`
- Create: `apps/fundlens_windows/integration_test/windows_workflow_test.dart`
- Test: `apps/fundlens_windows/test/features/settings/settings_page_test.dart`
- Test: `apps/fundlens_windows/test/accessibility/keyboard_navigation_test.dart`
- Test: `apps/fundlens_windows/test/accessibility/copy_boundary_test.dart`

**Interfaces:**
- Consumes: app settings repository, daily refresh policy, privacy flags.
- Produces: user-defined optional thresholds and quote refresh controls; Phase 4 attaches the backup actions before any release build is produced.

- [x] **Step 1: Write failing settings and forbidden-copy tests**

```dart
testWidgets('thresholds are opt-in with no ideal defaults', (tester) async {
  await tester.pumpWidget(settingsHarness());
  expect(find.textContaining('理想比例'), findsNothing);
  expect(find.byType(TextField), findsNothing);
  await tester.tap(find.text('添加结构阈值'));
  await tester.pump();
  expect(find.byType(TextField), findsWidgets);
});

test('localized copy has no advice or return mislabeling', () {
  const forbidden = ['再平衡建议','调仓建议','建议买入','建议卖出','快照收益'];
  for (final phrase in forbidden) {
    expect(allChineseCopy.contains(phrase), isFalse);
  }
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/features/settings apps/fundlens_windows/test/accessibility`

Expected: FAIL because settings and copy registry do not exist.

- [x] **Step 3: Implement settings and keyboard behavior**

Add optional user thresholds for max single holding, max class, minimum cash+deposit and maximum equity exposure. Each threshold displays “由你设置，仅用于结构提示”. Add daily auto-refresh toggle, last attempt/source/date, manual refresh and degraded engine state. Privacy shows local-only processing, temporary screenshot cleanup and redacted logging. Reserve a Paper section titled “加密备份” with a factual description; Phase 4 adds functioning buttons before release.

Keyboard acceptance: `Ctrl+1..6` navigation, Tab logical order, Space/Enter activation, Escape closes dialogs/clears spectrum selection, arrow navigation in spectrum and radio groups. Focus indicator contrast must be at least 3:1.

- [x] **Step 4: Run the Windows workflow test**

The integration test uses in-memory repositories and fake engine to: add manual deposit → import synthetic Alipay partial screenshot → resolve one low-confidence field → commit → refresh a quote → save two snapshots → compare them → export filtered holdings.

Run on Windows: `flutter test integration_test/windows_workflow_test.dart -d windows`

Expected: PASS at `1280×720`; no overflow, unhandled exception, network call or Python process outside the fake.

- [x] **Step 5: Run the phase gate and commit**

Run: `flutter test apps/fundlens_windows && flutter analyze apps/fundlens_windows`

Expected: PASS, including goldens and accessibility tests.

```bash
git add apps/fundlens_windows/lib/features/settings apps/fundlens_windows/test apps/fundlens_windows/integration_test
git commit -m "feat(ui): complete FundLens Windows workflows"
```

## Phase 3 Completion Gate

- [x] All six destinations are functional and reachable by mouse and keyboard.
- [x] Asset Spectrum selection filters holdings and has full semantics.
- [x] 2,000-row grid remains virtualized and preserves frozen columns at 1280×720.
- [x] OCR review always shows field confidence and source crop before commit.
- [x] Snapshot comparison uses only “资产金额变化”.
- [x] Golden tests match the approved Asset Spectrum direction.
- [x] Copy scan contains no advice, rebalancing or transaction wording.
