import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/data_engine/data_engine_client.dart';
import 'package:fundlens_windows/features/data_health/data_health_providers.dart';
import 'package:fundlens_windows/features/holdings/holding_actions.dart';
import 'package:fundlens_windows/market/quote.dart';
import 'package:fundlens_windows/market/quote_refresh_service.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';

final _now = DateTime.utc(2026, 7, 20);

Holding _refreshableHolding(String id) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
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

/// 返回固定 quotes 的行情引擎 fake:刷新成功路径。
final class _SuccessEngine implements DataEngineClient {
  _SuccessEngine(this.quotes);

  final Map<String, Object?> quotes;
  int callCount = 0;

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    callCount++;
    return quotes;
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> close() async {}
}

/// 调用即抛 Error 的行情引擎 fake:模拟引擎整体不可用。
/// 抛 Error 而非 Exception:`QuoteRefreshService._fetchQuotes` 只吞 Exception,
/// Error 穿透到 refresh 抛出,由 HoldingActions.refreshQuotes 捕获。
final class _FailingEngine implements DataEngineClient {
  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    throw StateError('engine down');
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> close() async {}
}

final class _NoopQuoteCache implements QuoteCacheStore {
  @override
  Future<void> upsertAll(List<CachedQuote> quotes) async {}
}

final class _FakeHoldingRepository implements HoldingRepository {
  _FakeHoldingRepository(this.stored);

  final Map<String, Holding> stored;

  @override
  Future<void> upsert(Holding holding) async {
    stored[holding.id] = holding;
  }

  @override
  Future<void> replacePlatform(
    SourcePlatform platform,
    List<Holding> holdings,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    for (final id in ids) {
      stored.remove(id);
    }
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();

  @override
  Stream<List<Holding>> watchAll() => Stream.value(stored.values.toList());

  @override
  Future<List<Holding>> getAll() async => stored.values.toList();
}

QuoteRefreshService _service({
  required DataEngineClient engine,
  required _FakeHoldingRepository repo,
}) {
  return QuoteRefreshService(
    engine: engine,
    holdings: repo,
    quoteCache: _NoopQuoteCache(),
    clock: () => _now,
  );
}

ProviderContainer _container({
  QuoteRefreshService? service,
  _FakeHoldingRepository? repo,
}) {
  final container = ProviderContainer(
    overrides: [
      holdingRepositoryProvider.overrideWithValue(repo ?? _FakeHoldingRepository({})),
      quoteRefreshServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Map<String, Object?> _freshQuoteJson() {
  return {
    'product_code': '110011',
    'provider': 'baostock',
    'status': 'fresh',
    'value': '1.2',
    'valuation_date': '2026-07-20',
    'error_code': null,
  };
}

void main() {
  group('HoldingActions.refreshQuotes 刷新状态与新鲜集合', () {
    test('成功:刷新集写入 updated 的 id,状态回到空闲,记录最近刷新', () async {
      final h = _refreshableHolding('h-1');
      final repo = _FakeHoldingRepository({'h-1': h});
      final engine = _SuccessEngine({'quotes': [_freshQuoteJson()]});
      final container = _container(
        service: _service(engine: engine, repo: repo),
        repo: repo,
      );

      final report =
          await HoldingActions.refreshQuotes(container, [h]);

      expect(report, isNotNull);
      expect(engine.callCount, 1);
      expect(container.read(freshQuoteHoldingIdsProvider), {'h-1'});
      expect(
        container.read(quoteRefreshUiStateProvider),
        const QuoteRefreshIdle(),
      );
      final attempt = container.read(lastQuoteRefreshAttemptProvider);
      expect(attempt, isNotNull);
      expect(attempt!.updated, 1);
      expect(attempt.failed, 0);
    });

    test('失败:状态置为刷新失败并携带原因,返回 null', () async {
      final h = _refreshableHolding('h-1');
      final repo = _FakeHoldingRepository({'h-1': h});
      final container = _container(
        service: _service(engine: _FailingEngine(), repo: repo),
        repo: repo,
      );

      final report =
          await HoldingActions.refreshQuotes(container, [h]);

      expect(report, isNull);
      final state = container.read(quoteRefreshUiStateProvider);
      expect(state, isA<QuoteRefreshFailed>());
      expect((state as QuoteRefreshFailed).reason, contains('engine down'));
      // 失败不污染新鲜集合。
      expect(container.read(freshQuoteHoldingIdsProvider), isEmpty);
    });

    test('并发拦截:已在刷新时直接返回 null,不重复调用服务', () async {
      final h = _refreshableHolding('h-1');
      final repo = _FakeHoldingRepository({'h-1': h});
      final engine = _SuccessEngine({'quotes': [_freshQuoteJson()]});
      final container = _container(
        service: _service(engine: engine, repo: repo),
        repo: repo,
      );
      container
          .read(quoteRefreshUiStateProvider.notifier)
          .state = const QuoteRefreshInProgress();

      final report =
          await HoldingActions.refreshQuotes(container, [h]);

      expect(report, isNull);
      expect(engine.callCount, 0);
    });

    test('服务未接线:返回 null,状态保持空闲', () async {
      final h = _refreshableHolding('h-1');
      final container = _container(service: null);

      final report =
          await HoldingActions.refreshQuotes(container, [h]);

      expect(report, isNull);
      expect(
        container.read(quoteRefreshUiStateProvider),
        const QuoteRefreshIdle(),
      );
    });

    test('无可刷新资产:返回 null,不置为刷新中', () async {
      final container = _container(service: null);

      final report =
          await HoldingActions.refreshQuotes(container, []);

      expect(report, isNull);
      expect(
        container.read(quoteRefreshUiStateProvider),
        const QuoteRefreshIdle(),
      );
    });
  });
}
