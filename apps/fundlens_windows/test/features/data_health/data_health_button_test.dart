import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/data_health/data_health_button.dart';
import 'package:fundlens_windows/features/data_health/data_health_providers.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final _now = DateTime.utc(2026, 7, 20);

/// 一条行情正常、有成本、有分类的持仓。
Holding _healthyHolding(String id) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: '产品$id',
    productCode: '110011',
    currency: 'CNY',
    quantity: DecimalValue.parse('100'),
    currentPrice: DecimalValue.parse('1.5'),
    costAmount: DecimalValue.parse('100'),
    currentValue: DecimalValue.parse('150'),
    valuationMethod: ValuationMethod.automaticQuote,
    valuationDate: _now,
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

final class _FakeHoldingRepository implements HoldingRepository {
  _FakeHoldingRepository(this.stored);

  final Map<String, Holding> stored;

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

  @override
  Stream<List<Holding>> watchAll() => Stream.value(stored.values.toList());

  @override
  Future<List<Holding>> getAll() async => stored.values.toList();
}

/// 组装按钮测试容器:默认一条健康持仓且行情新鲜。
ProviderContainer makeContainer(
  List<Holding> holdings, {
  Set<String> freshIds = const {},
  LastImportRecord? lastImport,
}) {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(
      _FakeHoldingRepository({for (final h in holdings) h.id: h}),
    ),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
    freshQuoteHoldingIdsProvider.overrideWith((ref) => freshIds),
    lastImportRecordProvider.overrideWithValue(lastImport),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> pumpButton(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(
          body: Center(child: DataHealthButton()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('DataHealthButton 五态', () {
    testWidgets('正常:check_circle_outline + 正常文字', (tester) async {
      final h = _healthyHolding('h-1');
      final container = makeContainer([h], freshIds: {'h-1'});
      await pumpButton(tester, container);

      expect(find.byKey(const ValueKey('data-status-button')), findsOneWidget);
      expect(find.text('正常'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('部分缺失:error_outline + 部分缺失文字', (tester) async {
      // 缺成本持仓:行情新鲜(在 freshIds),但无有效成本 → 部分缺失。
      final noCost = Holding(
        id: 'h-2',
        sourcePlatform: SourcePlatform.alipay,
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.other,
        productName: '缺成本',
        productCode: '110011',
        currency: 'CNY',
        quantity: DecimalValue.parse('100'),
        currentPrice: DecimalValue.parse('1.5'),
        currentValue: DecimalValue.parse('150'),
        valuationMethod: ValuationMethod.automaticQuote,
        valuationDate: _now,
        dataOrigin: DataOrigin.excel,
        fieldProvenance: const {},
        createdAt: _now,
        updatedAt: _now,
      );
      final container = makeContainer([noCost], freshIds: {'h-2'});
      await pumpButton(tester, container);

      expect(find.text('部分缺失'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('需要更新:update 图标 + 需要更新文字', (tester) async {
      final container = makeContainer(
        [_healthyHolding('h-1')],
        freshIds: const {},
      );
      await pumpButton(tester, container);

      expect(find.text('需要更新'), findsOneWidget);
      expect(find.byIcon(Icons.update), findsOneWidget);
    });

    testWidgets('正在刷新:sync 图标 + 正在刷新文字', (tester) async {
      final container = makeContainer(
        [_healthyHolding('h-1')],
        freshIds: const {'h-1'},
      );
      await pumpButton(tester, container);
      container
          .read(quoteRefreshUiStateProvider.notifier)
          .state = const QuoteRefreshInProgress();
      await tester.pump();

      expect(find.text('正在刷新'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
    });

    testWidgets('刷新失败:error_outline + 刷新失败文字', (tester) async {
      final container = makeContainer(
        [_healthyHolding('h-1')],
        freshIds: const {'h-1'},
      );
      await pumpButton(tester, container);
      container.read(quoteRefreshUiStateProvider.notifier).state =
          const QuoteRefreshFailed('引擎不可用');
      await tester.pump();

      expect(find.text('刷新失败'), findsOneWidget);
      // 面板未打开时 MenuAnchor 的 menuChildren 不在 widget 树中,
      // 因此只断言按钮自身的一枚状态图标。
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('DataHealthPopover 内容', () {
    testWidgets('点击按钮打开面板,展示指标与计算方式', (tester) async {
      final container = makeContainer(
        [_healthyHolding('h-1')],
        freshIds: const {'h-1'},
      );
      await pumpButton(tester, container);

      await tester.tap(find.byKey(const ValueKey('data-status-button')));
      await tester.pumpAndSettle();

      // 数据截至时间。
      expect(find.text('数据截至 2026-07-20'), findsOneWidget);
      // 指标:识别率/分类率/成本/行情/收益覆盖率,每项带"n/n"计算方式。
      expect(find.text('持仓识别率'), findsOneWidget);
      expect(find.text('1/1'), findsNWidgets(4)); // 识别/分类/成本/行情
      expect(find.text('资产分类率'), findsOneWidget);
      expect(find.text('成本覆盖率'), findsOneWidget);
      expect(find.text('行情覆盖率'), findsOneWidget);
      expect(find.text('收益覆盖率'), findsOneWidget);
      // 计数型指标以"标签 + 数值(条)"分行呈现。
      expect(find.text('过期行情'), findsOneWidget);
      expect(find.text('待处理异常'), findsOneWidget);
      expect(find.text('0 条'), findsNWidgets(2));
      // 操作区四个入口。
      expect(find.text('刷新行情'), findsOneWidget);
      expect(find.text('查看缺失数据'), findsOneWidget);
      expect(find.text('补充资产分类'), findsOneWidget);
      expect(find.text('查看导入记录'), findsOneWidget);
    });

    testWidgets('刷新失败时展示原因与重试入口', (tester) async {
      final container = makeContainer(
        [_healthyHolding('h-1')],
        freshIds: const {'h-1'},
      );
      await pumpButton(tester, container);
      container.read(quoteRefreshUiStateProvider.notifier).state =
          const QuoteRefreshFailed('行情引擎不可用');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('data-status-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('行情引擎不可用'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });

    testWidgets('最近导入与最近刷新记录展示', (tester) async {
      final import = LastImportRecord(
        committedAt: DateTime.utc(2026, 7, 18),
        inserted: 3,
        updated: 1,
        removed: 0,
        skipped: 2,
      );
      final container = makeContainer(
        [_healthyHolding('h-1')],
        freshIds: const {'h-1'},
        lastImport: import,
      );
      container.read(lastQuoteRefreshAttemptProvider.notifier).state =
          QuoteRefreshAttempt(
        at: DateTime.utc(2026, 7, 19, 8, 30),
        source: 'baostock',
        updated: 2,
        failed: 1,
      );
      await pumpButton(tester, container);

      await tester.tap(find.byKey(const ValueKey('data-status-button')));
      await tester.pumpAndSettle();

      expect(find.text('最近导入'), findsOneWidget);
      expect(find.textContaining('新增 3'), findsOneWidget);
      expect(find.text('最近行情刷新'), findsOneWidget);
      expect(find.textContaining('更新 2'), findsOneWidget);
    });
  });
}
