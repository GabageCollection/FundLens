import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/schedule_policy.dart';
import 'package:fundlens_windows/data_engine/data_engine_client.dart';
import 'package:fundlens_windows/features/holdings/holding_actions.dart';
import 'package:fundlens_windows/features/settings/persisted_settings.dart';
import 'package:fundlens_windows/market/quote.dart';
import 'package:fundlens_windows/market/quote_refresh_service.dart';
import 'package:fundlens_windows/market/startup_refresh_coordinator.dart';
import 'package:fundlens_windows/storage/app_settings_repository.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';

final _now = DateTime.utc(2026, 7, 20);

Holding _refreshableHolding(String id) => Holding(
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

final class _SuccessEngine implements DataEngineClient {
  int callCount = 0;

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    callCount++;
    return {
      'quotes': [
        {
          'product_code': '110011',
          'provider': 'baostock',
          'status': 'fresh',
          'value': '1.2',
          'valuation_date': '2026-07-20',
          'error_code': null,
        },
      ],
    };
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> close() async {}
}

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

final class _FakeAppSettingsRepository implements AppSettingsRepository {
  final Map<String, String> map = {};

  @override
  Future<String?> get(String key) async => map[key];

  @override
  Future<Map<String, String>> getAll() async => Map.of(map);

  @override
  Future<void> set(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  late ProviderContainer container;
  late _FakeAppSettingsRepository settings;
  late _FakeHoldingRepository repo;
  late _SuccessEngine successEngine;
  late _FailingEngine failingEngine;

  void buildContainer({
    QuoteRefreshService? service,
    bool enabled = true,
    ScheduleFrequency frequency = ScheduleFrequency.daily,
    DateTime? lastAttempt,
  }) {
    settings = _FakeAppSettingsRepository();
    repo = _FakeHoldingRepository({'h-1': _refreshableHolding('h-1')});
    successEngine = _SuccessEngine();
    failingEngine = _FailingEngine();
    container = ProviderContainer(
      overrides: [
        holdingRepositoryProvider.overrideWithValue(repo),
        quoteRefreshServiceProvider.overrideWithValue(
          service ??
              QuoteRefreshService(
                engine: successEngine,
                holdings: repo,
                quoteCache: _NoopQuoteCache(),
                clock: () => _now,
              ),
        ),
        appSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    container.read(dailyAutoRefreshEnabledProvider.notifier).state = enabled;
    container.read(refreshFrequencyProvider.notifier).state = frequency;
    container.read(lastRefreshAttemptAtUtcProvider.notifier).state = lastAttempt;
  }

  StartupRefreshCoordinator coordinator({
    DateTime Function() clock = _defaultClock,
  }) {
    return StartupRefreshCoordinator(
      container: container,
      policy: SchedulePolicy(clock),
    );
  }

  test('disabled toggle: nothing runs, nothing recorded', () async {
    buildContainer(enabled: false);
    await coordinator().runIfDue();
    expect(successEngine.callCount, 0);
    expect(container.read(lastRefreshAttemptAtUtcProvider), isNull);
    expect(settings.map, isEmpty);
  });

  test('manual frequency: nothing runs', () async {
    buildContainer(frequency: ScheduleFrequency.manual);
    await coordinator().runIfDue();
    expect(successEngine.callCount, 0);
    expect(container.read(lastRefreshAttemptAtUtcProvider), isNull);
  });

  test('due daily: refreshes holdings and records the attempt', () async {
    buildContainer(lastAttempt: DateTime.utc(2026, 7, 19, 9));
    await coordinator().runIfDue();
    expect(successEngine.callCount, 1);
    final attempt = container.read(lastRefreshAttemptAtUtcProvider);
    expect(attempt, isNotNull);
    expect(
      settings.map[SettingKeys.lastRefreshAttemptAtUtc],
      attempt!.toUtc().toIso8601String(),
    );
  });

  test('not due (ran today): no refresh', () async {
    buildContainer(lastAttempt: DateTime.utc(2026, 7, 20, 8));
    await coordinator().runIfDue();
    expect(successEngine.callCount, 0);
  });

  test('engine unavailable: attempt still recorded so startup is not retried',
      () async {
    buildContainer(service: null, lastAttempt: DateTime.utc(2026, 7, 19, 9));
    await coordinator().runIfDue();
    expect(container.read(lastRefreshAttemptAtUtcProvider), isNotNull);
    expect(
      settings.map.containsKey(SettingKeys.lastRefreshAttemptAtUtc),
      isTrue,
    );
  });

  test('refresh failure: attempt still recorded', () async {
    buildContainer(
      service: QuoteRefreshService(
        engine: failingEngine,
        holdings: repo,
        quoteCache: _NoopQuoteCache(),
        clock: () => _now,
      ),
      lastAttempt: DateTime.utc(2026, 7, 19, 9),
    );
    await coordinator().runIfDue();
    expect(container.read(lastRefreshAttemptAtUtcProvider), isNotNull);
    expect(
      settings.map.containsKey(SettingKeys.lastRefreshAttemptAtUtc),
      isTrue,
    );
  });
}

DateTime _defaultClock() => _now;
