import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/app/fundlens_app.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/data_engine/data_engine_client.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/import_review/import_review_harness.dart';

/// Holding repository preloaded with the large fixture. Every full read of
/// the holdings list — an explicit `getAll` or a stream emission — is
/// counted so the budget test can prove pages derive from one shared read
/// instead of re-scanning the repository per page.
final class CountingHoldingRepository implements HoldingRepository {
  CountingHoldingRepository(List<Holding> initial) : holdings = List.of(initial);

  final List<Holding> holdings;
  var fullReadCount = 0;
  late final StreamController<List<Holding>> _controller =
      StreamController<List<Holding>>.broadcast(onListen: _emit);

  void _emit() {
    if (_controller.isClosed) return;
    fullReadCount++;
    _controller.add(List.of(holdings));
  }

  @override
  Future<void> upsert(Holding holding) async {
    holdings.removeWhere((h) => h.id == holding.id);
    holdings.add(holding);
    _emit();
  }

  @override
  Future<void> replacePlatform(
    SourcePlatform platform,
    List<Holding> next,
  ) async {
    holdings.removeWhere((h) => h.sourcePlatform == platform);
    holdings.addAll(next);
    _emit();
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    holdings.removeWhere((h) => ids.contains(h.id));
    _emit();
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();

  @override
  Stream<List<Holding>> watchAll() => _controller.stream;

  @override
  Future<List<Holding>> getAll() async {
    fullReadCount++;
    return List.of(holdings);
  }
}

/// Snapshot repository preloaded with frozen snapshots; reads are counted
/// for diagnostics.
final class CountingSnapshotRepository implements SnapshotRepository {
  CountingSnapshotRepository(List<PortfolioSnapshot> initial)
      : snapshots = List.of(initial);

  final List<PortfolioSnapshot> snapshots;
  var fullReadCount = 0;

  @override
  Future<String> createFromCurrent({required String label}) async {
    throw UnimplementedError('not used by the performance test');
  }

  @override
  Future<PortfolioSnapshot> getById(String id) async =>
      snapshots.firstWhere((s) => s.id == id);

  @override
  Future<List<PortfolioSnapshot>> getAll() async {
    fullReadCount++;
    return List.of(snapshots);
  }

  @override
  Future<void> deleteById(String id) async {
    snapshots.removeWhere((s) => s.id == id);
  }
}

/// Engine client that mirrors the process client's lazy-start semantics:
/// the child process starts once and only a `close` (crash/reset) followed
/// by a new call would start it again. [startCount] therefore proves the
/// measured interactions never restarted the engine.
final class CountingDataEngineClient implements DataEngineClient {
  var startCount = 0;
  var _running = false;

  /// Simulates the one engine start performed by the app bootstrap.
  void start() {
    if (_running) return;
    _running = true;
    startCount++;
  }

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    start();
    throw StateError('unexpected engine call in performance test: $method');
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> close() async {
    _running = false;
  }
}

/// Large portfolio fixture: 2,000 holdings and 500 frozen snapshots,
/// matching the V1 acceptance data volume.
final class LargePortfolioFixture {
  LargePortfolioFixture._({
    required this.repository,
    required this.snapshotRepository,
    required this.engine,
  });

  final CountingHoldingRepository repository;
  final CountingSnapshotRepository snapshotRepository;
  final CountingDataEngineClient engine;

  static Future<LargePortfolioFixture> create({
    required int holdings,
    required int snapshots,
  }) async {
    final now = DateTime.utc(2026, 7, 1);
    const assetClasses = AssetClass.values;
    const platforms = SourcePlatform.values;
    final holdingList = <Holding>[
      for (var i = 0; i < holdings; i++)
        Holding(
          id: 'perf-$i',
          sourcePlatform: platforms[i % platforms.length],
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: assetClasses[i % assetClasses.length],
          productName: '性能测试基金$i',
          productCode: (100000 + i).toString(),
          currency: 'CNY',
          quantity: DecimalValue.parse('100'),
          currentPrice: DecimalValue.parse('1.${(i % 90) + 10}'),
          currentValue: DecimalValue.parse('${1000 + i}.00'),
          costAmount: DecimalValue.parse('${900 + i}.00'),
          holdingProfit: DecimalValue.parse('100.00'),
          valuationMethod: ValuationMethod.automaticQuote,
          dataOrigin: DataOrigin.csv,
          fieldProvenance: const {},
          createdAt: now,
          updatedAt: now,
        ),
    ];
    final snapshotList = <PortfolioSnapshot>[
      for (var i = 0; i < snapshots; i++)
        PortfolioSnapshot(
          id: 'snap-$i',
          label: '快照$i',
          createdAt: now.subtract(Duration(days: snapshots - i)),
          holdings: [
            for (var j = 0; j < 3; j++)
              SnapshotHolding(
                holdingId: 'perf-$j',
                productName: '性能测试基金$j',
                instrumentType: InstrumentType.offExchangeFund,
                assetClass: AssetClass.equity,
                sourcePlatform: SourcePlatform.alipay,
                currentValue: DecimalValue.parse('${1000 + j + i}.00'),
                fieldProvenance: const {},
              ),
          ],
        ),
    ];
    final engine = CountingDataEngineClient()..start();
    return LargePortfolioFixture._(
      repository: CountingHoldingRepository(holdingList),
      snapshotRepository: CountingSnapshotRepository(snapshotList),
      engine: engine,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('2000 holdings and 500 snapshots meet interaction budgets',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fixture =
        await LargePortfolioFixture.create(holdings: 2000, snapshots: 500);

    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(fixture.repository),
          snapshotRepositoryProvider
              .overrideWithValue(fixture.snapshotRepository),
          portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
          dataQualityCalculatorProvider
              .overrideWithValue(DataQualityCalculator()),
          dataEngineClientProvider.overrideWithValue(fixture.engine),
          importFilePickerProvider.overrideWithValue(FakeImportFilePicker()),
          screenshotTempStoreProvider
              .overrideWithValue(FakeScreenshotTempStore()),
          importDraftStoreProvider
              .overrideWithValue(InMemoryImportDraftStore()),
        ],
        child: const FundLensApp(),
      ),
    );
    await tester.pumpAndSettle();
    final initialMs = stopwatch.elapsedMilliseconds;
    // ignore: avoid_print
    print('PERF initial pumpAndSettle: ${initialMs}ms');
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)),
        reason: 'initial render took ${initialMs}ms (budget 3000ms)');

    stopwatch
      ..reset()
      ..start();
    await tester.tap(find.text('资产分析'));
    await tester.pumpAndSettle();
    final analysisMs = stopwatch.elapsedMilliseconds;
    // ignore: avoid_print
    print('PERF tap 资产分析 + settle: ${analysisMs}ms');
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 500)),
        reason: 'analysis navigation took ${analysisMs}ms (budget 500ms)');

    // ignore: avoid_print
    print('PERF repository.fullReadCount: ${fixture.repository.fullReadCount}');
    // ignore: avoid_print
    print('PERF snapshots.fullReadCount: '
        '${fixture.snapshotRepository.fullReadCount}');
    // ignore: avoid_print
    print('PERF engine.startCount: ${fixture.engine.startCount}');
    expect(fixture.repository.fullReadCount, 1,
        reason: 'holdings must be read once via the shared stream');
    expect(fixture.engine.startCount, 1,
        reason: 'the engine must start once and never restart');
    expect(tester.takeException(), isNull);
  });
}
