import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/app/app_shell.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_status.dart';
import 'package:fundlens_windows/features/holdings/holdings_page.dart';
import 'package:fundlens_windows/features/data_health/data_health_providers.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

import '../overview/asset_spectrum_test.dart' show FakeHoldingRepository;

final _now = DateTime.utc(2026, 7, 20);

Holding _holding(
  String id, {
  DecimalValue? costAmount,
  AssetClass assetClass = AssetClass.equity,
}) {
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
    costAmount: costAmount,
    valuationMethod: ValuationMethod.automaticQuote,
    valuationDate: _now,
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

ProviderContainer _makeContainer(List<Holding> holdings) {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(FakeHoldingRepository(holdings)),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
    freshQuoteHoldingIdsProvider.overrideWith(
      (ref) => {for (final h in holdings) h.id},
    ),
    lastImportRecordProvider.overrideWithValue(null),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// 组合 AppShell:持仓页用真实页面,其余用占位页,验证完整跳转链路。
Widget _buildShell(ProviderContainer container, List<Holding> holdings) {
  final pages = <Widget>[
    for (final destination in AppDestination.values)
      if (destination == AppDestination.holdings)
        const HoldingsPage()
      else
        Center(child: Text('page-${destination.name}')),
  ];
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: FundLensTheme.light,
      home: AppShell(pages: pages),
    ),
  );
}

Future<void> _pumpShell(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_buildShell(container, []));
  await tester.pumpAndSettle();
}

Future<void> _openPopover(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('data-status-button')));
  await tester.pumpAndSettle();
}

void main() {
  group('数据健康面板跳转 + 预选筛选', () {
    testWidgets('查看缺失数据:切到持仓页并应用数据状态筛选', (tester) async {
      final container = _makeContainer([
        _holding('no-cost'),
        _holding('has-cost', costAmount: DecimalValue.parse('50')),
      ]);
      await _pumpShell(tester, container);

      await _openPopover(tester);
      expect(find.text('查看缺失数据'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('data-health-missing')));
      await tester.pumpAndSettle();

      // 已切到持仓页且筛选生效:只剩缺成本项。
      expect(
        container.read(holdingFilterProvider).statuses,
        {
          HoldingDataStatus.incomplete,
          HoldingDataStatus.noQuote,
          HoldingDataStatus.staleQuote,
          HoldingDataStatus.missingCost,
        },
      );
      expect(container.read(pendingHoldingFilterProvider), isNull);
      expect(find.text('共 1 项持仓'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('补充资产分类:切到持仓页并应用"其他"类别筛选', (tester) async {
      final container = _makeContainer([
        _holding('equity', assetClass: AssetClass.equity),
        _holding('other', assetClass: AssetClass.other),
      ]);
      await _pumpShell(tester, container);

      await _openPopover(tester);
      expect(find.text('补充资产分类'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('data-health-classify')));
      await tester.pumpAndSettle();

      expect(
        container.read(holdingFilterProvider).assetClasses,
        {AssetClass.other},
      );
      expect(container.read(pendingHoldingFilterProvider), isNull);
      expect(find.text('共 1 项持仓'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
