import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/portfolio_providers.dart';
import 'package:fundlens_windows/application/selection_state.dart';
import 'package:fundlens_windows/features/overview/overview_page.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

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

final class FakeSnapshotRepository implements SnapshotRepository {
  @override
  Future<List<PortfolioSnapshot>> getAll() async => const [];

  @override
  Future<PortfolioSnapshot> getById(String id) =>
      throw UnimplementedError('unused');

  @override
  Future<String> createFromCurrent({required String label}) async => 'unused';

  @override
  Future<void> deleteById(String id) async {}
}

Holding fixtureHolding({
  required String id,
  required AssetClass assetClass,
  required String currentValue,
  String? costAmount,
  String? holdingProfit,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.manual,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: '产品$id',
    currency: 'CNY',
    currentValue: DecimalValue.parse(currentValue),
    costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
    holdingProfit:
        holdingProfit == null ? null : DecimalValue.parse(holdingProfit),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

List<Holding> twoClassHoldings() => [
      fixtureHolding(
        id: 'h-equity',
        assetClass: AssetClass.equity,
        currentValue: '5000.00',
        costAmount: '4000.00',
        holdingProfit: '1000.00',
      ),
      fixtureHolding(
        id: 'h-cash',
        assetClass: AssetClass.cash,
        currentValue: '5000.00',
      ),
    ];

Widget overviewHarness(
  ProviderContainer container, {
  bool disableAnimations = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: FundLensTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: const Scaffold(body: OverviewPage()),
      ),
    ),
  );
}

Future<ProviderContainer> pumpOverview(
  WidgetTester tester, {
  List<Holding>? holdings,
  bool disableAnimations = false,
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider
        .overrideWithValue(FakeHoldingRepository(holdings ?? twoClassHoldings())),
    snapshotRepositoryProvider.overrideWithValue(FakeSnapshotRepository()),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
    dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    overviewHarness(container, disableAnimations: disableAnimations),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('clicking a spectrum segment filters holdings', (tester) async {
    final container = await pumpOverview(tester);
    await tester.tap(find.byKey(const ValueKey('spectrum-equity')));
    await tester.pump();
    expect(container.read(selectedAssetClassProvider), AssetClass.equity);
    expect(container.read(filteredHoldingsProvider).length, 1);
    expect(
      container.read(filteredHoldingsProvider).single.assetClass,
      AssetClass.equity,
    );
  });

  testWidgets('clicking the selected segment again clears the filter',
      (tester) async {
    final container = await pumpOverview(tester);
    await tester.tap(find.byKey(const ValueKey('spectrum-cash')));
    await tester.pump();
    expect(container.read(selectedAssetClassProvider), AssetClass.cash);
    await tester.tap(find.byKey(const ValueKey('spectrum-cash')));
    await tester.pump();
    expect(container.read(selectedAssetClassProvider), isNull);
  });

  testWidgets('segment semantics include class amount and share',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpOverview(tester);
    expect(find.bySemanticsLabel(RegExp('权益')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('占比')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('arrow keys move focus, Enter selects, Escape clears',
      (tester) async {
    final container = await pumpOverview(tester);
    // Focus the first segment, then move with the arrow key.
    await tester.tap(find.byKey(const ValueKey('spectrum-cash')));
    await tester.pump();
    expect(container.read(selectedAssetClassProvider), AssetClass.cash);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    final equityContext =
        tester.element(find.byKey(const ValueKey('spectrum-equity')));
    expect(Focus.of(equityContext).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(container.read(selectedAssetClassProvider), AssetClass.equity);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(container.read(selectedAssetClassProvider), isNull);
  });

  testWidgets('summary strip shows floating profit with explicit + sign',
      (tester) async {
    await pumpOverview(tester);
    expect(find.textContaining('+1000'), findsWidgets);
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('收益覆盖率'), findsOneWidget);
  });

  testWidgets('observations are factual shares without advice', (tester) async {
    await pumpOverview(tester);
    expect(find.textContaining('最大单项占总资产'), findsOneWidget);
    expect(find.textContaining('50.0%'), findsWidgets);
    for (final forbidden in ['建议', '应当', '调仓', '再平衡', '买入', '卖出']) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('empty portfolio shows the add-first-asset action',
      (tester) async {
    await pumpOverview(tester, holdings: const []);
    expect(find.text('添加第一项资产'), findsOneWidget);
  });

  testWidgets('disableAnimations settles without spectrum animation',
      (tester) async {
    final container = await pumpOverview(tester, disableAnimations: true);
    expect(find.byKey(const ValueKey('spectrum-equity')), findsOneWidget);
    expect(container.read(selectedAssetClassProvider), isNull);
    expect(tester.takeException(), isNull);
  });
}
