import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/portfolio_providers.dart';
import 'package:fundlens_windows/application/portfolio_state.dart';
import 'package:fundlens_windows/application/selection_state.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';

final class CountingHoldingRepository implements HoldingRepository {
  CountingHoldingRepository(this._holdings, {this.stream});

  final List<Holding> _holdings;
  final Stream<List<Holding>>? stream;
  var watchCount = 0;

  @override
  Stream<List<Holding>> watchAll() {
    watchCount++;
    return stream ?? Stream.value(_holdings);
  }

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
  FakeSnapshotRepository(this._snapshots);

  final List<PortfolioSnapshot> _snapshots;

  @override
  Future<List<PortfolioSnapshot>> getAll() async => _snapshots;

  @override
  Future<PortfolioSnapshot> getById(String id) async =>
      _snapshots.firstWhere((s) => s.id == id);

  @override
  Future<String> createFromCurrent({required String label}) async => 'unused';

  @override
  Future<void> deleteById(String id) async {}
}

Holding fixtureHolding({
  String id = 'h-1',
  AssetClass assetClass = AssetClass.equity,
  String currentValue = '1000.00',
  ValuationMethod valuationMethod = ValuationMethod.manualAmount,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.manual,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: '测试基金',
    currency: 'CNY',
    currentValue: DecimalValue.parse(currentValue),
    valuationMethod: valuationMethod,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

ProviderContainer makeContainer({
  required HoldingRepository holdings,
  SnapshotRepository? snapshots,
  Set<String> freshQuoteHoldingIds = const {},
}) {
  return ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(holdings),
    snapshotRepositoryProvider
        .overrideWithValue(snapshots ?? FakeSnapshotRepository(const [])),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
    dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
    freshQuoteHoldingIdsProvider.overrideWith((ref) => freshQuoteHoldingIds),
  ]);
}

/// Keeps [holdingsProvider] alive and waits for its first emission.
Future<List<Holding>> firstEmission(ProviderContainer container) {
  final subscription = container.listen(holdingsProvider, (_, _) {});
  addTearDown(subscription.close);
  return container.read(holdingsProvider.future);
}

void main() {
  test('page consumers share one holdings subscription', () async {
    final repository = CountingHoldingRepository([fixtureHolding()]);
    final container = makeContainer(holdings: repository);
    addTearDown(container.dispose);

    await firstEmission(container);
    container.read(portfolioSummaryProvider);
    container.read(filteredHoldingsProvider);
    container.read(dataQualityProvider);
    container.read(dataIssuesProvider);

    expect(repository.watchCount, 1);
  });

  test('loading state is distinct while the stream has not emitted', () {
    final controller = StreamController<List<Holding>>();
    addTearDown(controller.close);
    final repository =
        CountingHoldingRepository(const [], stream: controller.stream);
    final container = makeContainer(holdings: repository);
    addTearDown(container.dispose);

    expect(container.read(portfolioStateProvider), isA<PortfolioLoading>());
    expect(container.read(holdingsProvider), isA<AsyncLoading>());
  });

  test('empty portfolio is distinct from data state', () async {
    final repository = CountingHoldingRepository(const []);
    final container = makeContainer(holdings: repository);
    addTearDown(container.dispose);

    await firstEmission(container);

    expect(container.read(portfolioStateProvider), isA<PortfolioEmpty>());
    final summary = container.read(portfolioSummaryProvider);
    expect(summary.totalValue, DecimalValue.zero);
    expect(container.read(filteredHoldingsProvider), isEmpty);
  });

  test('data state exposes summary, quality and snapshots', () async {
    final repository = CountingHoldingRepository([
      fixtureHolding(currentValue: '1000.00'),
      fixtureHolding(
        id: 'h-2',
        assetClass: AssetClass.deposit,
        currentValue: '3000.00',
      ),
    ]);
    final snapshot = PortfolioSnapshot(
      id: 's-1',
      label: '六月快照',
      createdAt: DateTime.utc(2026, 6, 30),
      holdings: const [],
    );
    final container = makeContainer(
      holdings: repository,
      snapshots: FakeSnapshotRepository([snapshot]),
    );
    addTearDown(container.dispose);

    await firstEmission(container);

    final state = container.read(portfolioStateProvider);
    expect(state, isA<PortfolioReady>());
    expect((state as PortfolioReady).holdings, hasLength(2));

    final summary = container.read(portfolioSummaryProvider);
    expect(summary.totalValue, DecimalValue.parse('4000.00'));

    final quality = container.read(dataQualityProvider);
    expect(quality.dataCompleteness, DecimalValue.parse('1'));

    final snapshots = await container.read(snapshotsProvider.future);
    expect(snapshots, hasLength(1));
    expect(snapshots.single.label, '六月快照');
  });

  test('degraded state is distinct when the stream errors', () async {
    final controller = StreamController<List<Holding>>();
    addTearDown(controller.close);
    final repository =
        CountingHoldingRepository(const [], stream: controller.stream);
    final container = makeContainer(holdings: repository);
    addTearDown(container.dispose);

    // Keep the provider alive so the error lands in the container.
    final subscription = container.listen(holdingsProvider, (_, _) {});
    addTearDown(subscription.close);
    controller.addError(StateError('database unavailable'));
    await pumpEventQueue();

    expect(container.read(portfolioStateProvider), isA<PortfolioDegraded>());
  });

  test('filtered holdings follow the selected asset class', () async {
    final repository = CountingHoldingRepository([
      fixtureHolding(id: 'h-1'),
      fixtureHolding(id: 'h-2', assetClass: AssetClass.deposit),
    ]);
    final container = makeContainer(holdings: repository);
    addTearDown(container.dispose);

    await firstEmission(container);
    expect(container.read(filteredHoldingsProvider), hasLength(2));

    container.read(selectedAssetClassProvider.notifier).state =
        AssetClass.deposit;
    final filtered = container.read(filteredHoldingsProvider);
    expect(filtered, hasLength(1));
    expect(filtered.single.id, 'h-2');

    container.read(selectedAssetClassProvider.notifier).state = null;
    expect(container.read(filteredHoldingsProvider), hasLength(2));
  });

  test('stale automatic quotes surface as data issues and degrade quality',
      () async {
    final repository = CountingHoldingRepository([
      fixtureHolding(
        valuationMethod: ValuationMethod.automaticQuote,
      ),
    ]);
    final container = makeContainer(holdings: repository);
    addTearDown(container.dispose);

    await firstEmission(container);

    final issues = container.read(dataIssuesProvider);
    expect(
      issues.where((issue) => issue.code == 'stale_quote'),
      hasLength(1),
    );
    expect(
      issues.singleWhere((issue) => issue.code == 'stale_quote').severity,
      IssueSeverity.info,
    );

    final freshContainer = makeContainer(
      holdings: repository,
      freshQuoteHoldingIds: const {'h-1'},
    );
    addTearDown(freshContainer.dispose);
    await firstEmission(freshContainer);
    expect(
      freshContainer
          .read(dataIssuesProvider)
          .where((issue) => issue.code == 'stale_quote'),
      isEmpty,
    );
  });
}
