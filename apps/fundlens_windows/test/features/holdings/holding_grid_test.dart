import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_grid.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

List<Holding> generateHoldings(int count) {
  final now = DateTime.utc(2026, 7, 1);
  return [
    for (var i = 0; i < count; i++)
      Holding(
        id: 'h-$i',
        sourcePlatform: SourcePlatform.alipay,
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.equity,
        productName: '产品${i.toString().padLeft(4, '0')}',
        productCode: '00${i % 10}0001',
        currency: 'CNY',
        quantity: DecimalValue.parse('$i'),
        currentPrice: DecimalValue.parse('1.2345'),
        costAmount: DecimalValue.parse('900.00'),
        currentValue: DecimalValue.parse('1000.00'),
        holdingProfit: DecimalValue.parse('100.00'),
        valuationMethod: ValuationMethod.automaticQuote,
        dataOrigin: DataOrigin.excel,
        fieldProvenance: const {},
        createdAt: now,
        updatedAt: now,
      ),
  ];
}

Widget gridHarness({
  required List<Holding> holdings,
  HoldingColumnPreset preset = HoldingColumnPreset.portfolio,
}) {
  return MaterialApp(
    theme: FundLensTheme.light,
    home: Scaffold(
      body: HoldingGrid(holdings: holdings, preset: preset),
    ),
  );
}

void main() {
  testWidgets('1280 width keeps name and amount visible', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(gridHarness(holdings: generateHoldings(2000)));
    await tester.pump();
    expect(find.text('产品名称'), findsOneWidget);
    expect(find.text('当前金额'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2000 holdings build fewer than 100 row widgets', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(gridHarness(holdings: generateHoldings(2000)));
    await tester.pump();
    expect(find.byType(HoldingGridRow), findsWidgets);
    expect(
      tester.widgetList(find.byType(HoldingGridRow)).length,
      lessThan(100),
    );
    expect(
      tester.widgetList(find.byType(HoldingGridRowDetail)).length,
      lessThan(100),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical scroll moves both regions together', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(gridHarness(holdings: generateHoldings(2000)));
    await tester.pump();

    expect(find.text('产品0000'), findsOneWidget);
    expect(find.text('产品0030'), findsNothing);

    // Drag the frozen region down by 30 rows (30 x 56 px).
    await tester.drag(
      find.byKey(const ValueKey('holding-grid-frozen')),
      const Offset(0, -30 * 56),
    );
    await tester.pump();

    expect(find.text('产品0000'), findsNothing);
    expect(find.text('产品0030'), findsOneWidget);
    // The scrollable region is synchronized: row 30's quantity cell renders.
    expect(find.text('30'), findsWidgets);
    expect(
      tester.widgetList(find.byType(HoldingGridRow)).length,
      lessThan(100),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('platform preset shows provenance columns', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(gridHarness(
      holdings: generateHoldings(5),
      preset: HoldingColumnPreset.platform,
    ));
    await tester.pump();
    expect(find.text('估值方式'), findsOneWidget);
    expect(find.text('数据出处'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
