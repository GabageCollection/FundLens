import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_status.dart';
import 'package:fundlens_windows/features/holdings/holdings_page.dart';
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
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpHoldingsPage(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const Scaffold(body: HoldingsPage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('HoldingsPage 消费预选筛选', () {
    testWidgets('挂载前设置 pending:首帧应用到筛选并清空', (tester) async {
      final container = _makeContainer([_holding('h-1')]);
      container.read(pendingHoldingFilterProvider.notifier).state =
          const HoldingFilterState(statuses: {HoldingDataStatus.missingCost});

      await _pumpHoldingsPage(tester, container);
      await tester.pump();

      expect(
        container.read(holdingFilterProvider).statuses,
        {HoldingDataStatus.missingCost},
      );
      expect(container.read(pendingHoldingFilterProvider), isNull);
    });

    testWidgets('挂载后设置 pending:帧末应用到筛选并清空', (tester) async {
      final container = _makeContainer([_holding('h-1')]);
      await _pumpHoldingsPage(tester, container);

      container.read(pendingHoldingFilterProvider.notifier).state =
          const HoldingFilterState(statuses: {HoldingDataStatus.missingCost});
      await tester.pump();

      expect(
        container.read(holdingFilterProvider).statuses,
        {HoldingDataStatus.missingCost},
      );
      expect(container.read(pendingHoldingFilterProvider), isNull);
    });

    testWidgets('预选筛选影响可见持仓:只保留缺成本项', (tester) async {
      final container = _makeContainer([
        _holding('no-cost'),
        _holding('has-cost', costAmount: DecimalValue.parse('50')),
      ]);
      container.read(pendingHoldingFilterProvider.notifier).state =
          const HoldingFilterState(statuses: {HoldingDataStatus.missingCost});

      await _pumpHoldingsPage(tester, container);
      await tester.pump();

      expect(
        container.read(visibleHoldingsProvider).map((h) => h.id),
        ['no-cost'],
      );
    });
  });
}
