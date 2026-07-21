import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/data_engine/data_engine_client.dart';
import 'package:fundlens_windows/data_engine/engine_message.dart';
import 'package:fundlens_windows/market/quote.dart';
import 'package:fundlens_windows/market/quote_refresh_service.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEngineClient implements DataEngineClient {
  _FakeEngineClient({this.response, this.error});

  Map<String, Object?>? response;
  Object? error;
  final List<String> calls = [];
  Map<String, Object?>? lastParams;

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    calls.add(method);
    lastParams = params;
    final failure = error;
    if (failure != null) throw failure;
    return Future.value(response ?? const {'quotes': <Object?>[]});
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> close() async {}
}

class _FakeQuoteCacheStore implements QuoteCacheStore {
  final List<CachedQuote> written = [];

  @override
  Future<void> upsertAll(List<CachedQuote> quotes) async {
    written.addAll(quotes);
  }
}

class _FakeHoldingRepository implements HoldingRepository {
  final Map<String, Holding> stored = {};
  var transactionCount = 0;

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
  Future<T> inTransaction<T>(Future<T> Function() action) {
    transactionCount++;
    return action();
  }

  @override
  Stream<List<Holding>> watchAll() => Stream.value(stored.values.toList());

  @override
  Future<List<Holding>> getAll() async => stored.values.toList();
}

Holding _holding({
  String id = 'h1',
  String? code,
  String? quantity,
  String value = '10000',
  String? currentPrice,
  SourcePlatform platform = SourcePlatform.ths,
  InstrumentType type = InstrumentType.etf,
  Map<String, FieldProvenance> provenance = const {},
}) {
  return Holding(
    id: id,
    sourcePlatform: platform,
    instrumentType: type,
    assetClass: AssetClass.equity,
    productName: '脱敏产品$id',
    productCode: code,
    currency: 'CNY',
    quantity: quantity == null ? null : DecimalValue.parse(quantity),
    currentPrice:
        currentPrice == null ? null : DecimalValue.parse(currentPrice),
    currentValue: DecimalValue.parse(value),
    valuationMethod: ValuationMethod.quantityTimesPrice,
    dataOrigin: DataOrigin.csv,
    fieldProvenance: provenance,
    createdAt: DateTime.utc(2026, 7, 19),
    updatedAt: DateTime.utc(2026, 7, 19),
  );
}

Map<String, Object?> _quoteJson(
  String code,
  String? value, {
  String status = 'fresh',
  String? valuationDate = '2026-07-20',
  String provider = 'baostock',
  String? errorCode,
}) {
  return {
    'product_code': code,
    'value': value,
    'valuation_date': valuationDate,
    'provider': provider,
    'status': status,
    'error_code': errorCode,
  };
}

void main() {
  DateTime clock() => DateTime.utc(2026, 7, 21, 10);

  QuoteRefreshService buildService(
    _FakeEngineClient engine,
    _FakeHoldingRepository repo,
    _FakeQuoteCacheStore cache,
  ) {
    return QuoteRefreshService(
      engine: engine,
      holdings: repo,
      quoteCache: cache,
      clock: clock,
    );
  }

  group('QuoteRefreshService', () {
    test('quote updates value only when code and quantity are confirmed',
        () async {
      final engine = _FakeEngineClient(
        response: {
          'quotes': [_quoteJson('510300', '4.455')],
        },
      );
      final repo = _FakeHoldingRepository();
      final cache = _FakeQuoteCacheStore();
      final service = buildService(engine, repo, cache);

      final holding = _holding(code: '510300', quantity: '2100');
      final report = await service.refresh([holding]);

      expect(report.updated.single.currentValue.canonical, '9355.5');
      expect(report.updated.single.currentPrice?.canonical, '4.455');
      expect(report.failed, isEmpty);
      expect(report.issues, isEmpty);
      // Quote cache written before applying updates.
      expect(cache.written.single.productCode, '510300');
      expect(cache.written.single.price, '4.455');
      // All holding updates happen in one transaction.
      expect(repo.transactionCount, 1);
      expect(repo.stored['h1']?.currentValue.canonical, '9355.5');
    });

    test('Alipay amount-only holding keeps confirmed value', () async {
      final engine = _FakeEngineClient(
        response: {
          'quotes': [
            _quoteJson('000001', '1.2345', provider: 'akshare'),
          ],
        },
      );
      final repo = _FakeHoldingRepository();
      final cache = _FakeQuoteCacheStore();
      final service = buildService(engine, repo, cache);

      final original = _holding(
        code: '000001',
        quantity: null,
        value: '78347.87',
        platform: SourcePlatform.alipay,
        type: InstrumentType.offExchangeFund,
      );
      final report = await service.refresh([original]);

      expect(report.updated, isEmpty);
      expect(report.retained.single.currentValue.canonical, '78347.87');
      expect(report.retained.single.currentPrice?.canonical, '1.2345');
    });

    test('inferred quantity is not recomputed from NAV alone', () async {
      final engine = _FakeEngineClient(
        response: {
          'quotes': [
            _quoteJson('000001', '1.2345', provider: 'akshare'),
          ],
        },
      );
      final repo = _FakeHoldingRepository();
      final service = buildService(engine, repo, _FakeQuoteCacheStore());

      final original = _holding(
        code: '000001',
        quantity: '5000',
        value: '78347.87',
        platform: SourcePlatform.alipay,
        type: InstrumentType.offExchangeFund,
        provenance: const {
          'quantity': FieldProvenance(
            kind: ProvenanceKind.inferred,
            source: 'estimate',
          ),
        },
      );
      final report = await service.refresh([original]);

      expect(report.updated, isEmpty);
      expect(report.retained.single.currentValue.canonical, '78347.87');
    });

    test('failed quote retains last valid value and becomes stale', () async {
      final engine = _FakeEngineClient(
        error: const DataEngineException(
          'engine.crashed',
          'engine process exited',
        ),
      );
      final repo = _FakeHoldingRepository();
      final cache = _FakeQuoteCacheStore();
      final service = buildService(engine, repo, cache);

      final cachedHolding = _holding(
        code: '510300',
        quantity: '2100',
        value: '9000',
        currentPrice: '4.30',
      );
      final report = await service.refresh([cachedHolding]);

      expect(report.updated, isEmpty);
      expect(report.failed.single.currentValue, cachedHolding.currentValue);
      expect(report.failed.single.currentPrice?.canonical, '4.3');
      expect(report.issues.single.code, 'market.quote_stale');
      // Nothing written on total engine failure.
      expect(repo.stored, isEmpty);
      expect(cache.written, isEmpty);
    });

    test('engine failed status retains value and reports stale', () async {
      final engine = _FakeEngineClient(
        response: {
          'quotes': [
            _quoteJson(
              '510300',
              null,
              status: 'failed',
              valuationDate: null,
              errorCode: 'market.provider_unavailable',
            ),
          ],
        },
      );
      final service = buildService(
        engine,
        _FakeHoldingRepository(),
        _FakeQuoteCacheStore(),
      );

      final report = await service.refresh([
        _holding(code: '510300', quantity: '100', value: '9000'),
      ]);

      expect(report.failed.single.currentValue.canonical, '9000');
      expect(report.issues.single.code, 'market.quote_stale');
    });

    test('zero or negative quotes are rejected', () async {
      final engine = _FakeEngineClient(
        response: {
          'quotes': [
            _quoteJson('510300', '0'),
            _quoteJson('600000', '-1.5'),
          ],
        },
      );
      final repo = _FakeHoldingRepository();
      final cache = _FakeQuoteCacheStore();
      final service = buildService(engine, repo, cache);

      final report = await service.refresh([
        _holding(id: 'a', code: '510300', quantity: '100', value: '9000'),
        _holding(
          id: 'b',
          code: '600000',
          quantity: '100',
          value: '8000',
          type: InstrumentType.stock,
        ),
      ]);

      expect(report.updated, isEmpty);
      expect(report.failed.length, 2);
      expect(
        report.issues.map((i) => i.code),
        everyElement('market.quote_stale'),
      );
      expect(cache.written, isEmpty);
      expect(repo.stored, isEmpty);
    });

    test('implausibly dated quotes are rejected', () async {
      final engine = _FakeEngineClient(
        response: {
          'quotes': [
            _quoteJson('510300', '4.455', valuationDate: '2000-01-01'),
            _quoteJson('600000', '12.0', valuationDate: '2099-01-01'),
          ],
        },
      );
      final cache = _FakeQuoteCacheStore();
      final service = buildService(
        engine,
        _FakeHoldingRepository(),
        cache,
      );

      final report = await service.refresh([
        _holding(id: 'a', code: '510300', quantity: '100', value: '9000'),
        _holding(
          id: 'b',
          code: '600000',
          quantity: '100',
          value: '8000',
          type: InstrumentType.stock,
        ),
      ]);

      expect(report.updated, isEmpty);
      expect(report.failed.length, 2);
      expect(cache.written, isEmpty);
    });

    test('manual gold, deposit and cash values are preserved', () async {
      final engine = _FakeEngineClient();
      final repo = _FakeHoldingRepository();
      final service = buildService(engine, repo, _FakeQuoteCacheStore());

      final report = await service.refresh([
        _holding(
          id: 'gold',
          value: '5000',
          platform: SourcePlatform.manual,
          type: InstrumentType.accumulatedGold,
        ),
        _holding(
          id: 'deposit',
          value: '20000',
          platform: SourcePlatform.manual,
          type: InstrumentType.bankDeposit,
        ),
        _holding(
          id: 'cash',
          value: '3000',
          platform: SourcePlatform.manual,
          type: InstrumentType.cashManagement,
        ),
      ]);

      // These instruments are never sent to the engine.
      expect(engine.calls, isEmpty);
      expect(report.updated, isEmpty);
      expect(report.failed, isEmpty);
      expect(report.issues, isEmpty);
      expect(repo.stored, isEmpty);
    });

    test('holdings without a product code are skipped', () async {
      final engine = _FakeEngineClient();
      final service = buildService(
        engine,
        _FakeHoldingRepository(),
        _FakeQuoteCacheStore(),
      );

      final report = await service.refresh([
        _holding(code: null, quantity: '100'),
      ]);

      expect(engine.calls, isEmpty);
      expect(report.updated, isEmpty);
      expect(report.failed, isEmpty);
    });
  });
}
