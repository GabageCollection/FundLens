import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/overview/overview_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

import 'asset_spectrum_test.dart' show FakeHoldingRepository, FakeSnapshotRepository;

Holding goldenHolding({
  required String id,
  required AssetClass assetClass,
  required InstrumentType instrumentType,
  required String productName,
  required String currentValue,
  String? costAmount,
  String? holdingProfit,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.manual,
    instrumentType: instrumentType,
    assetClass: assetClass,
    productName: productName,
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

void main() {
  testWidgets('overview golden at 1440x900', (tester) async {
    final holdings = [
      goldenHolding(
        id: 'h-1',
        assetClass: AssetClass.equity,
        instrumentType: InstrumentType.offExchangeFund,
        productName: '稳健成长混合基金',
        currentValue: '52340.00',
        costAmount: '48000.00',
        holdingProfit: '4340.00',
      ),
      goldenHolding(
        id: 'h-2',
        assetClass: AssetClass.fixedIncome,
        instrumentType: InstrumentType.offExchangeFund,
        productName: '安泰纯债债券基金',
        currentValue: '40120.00',
        costAmount: '41000.00',
        holdingProfit: '-880.00',
      ),
      goldenHolding(
        id: 'h-3',
        assetClass: AssetClass.cash,
        instrumentType: InstrumentType.cashManagement,
        productName: '余额现金管理',
        currentValue: '31000.00',
      ),
      goldenHolding(
        id: 'h-4',
        assetClass: AssetClass.gold,
        instrumentType: InstrumentType.accumulatedGold,
        productName: '积存金',
        currentValue: '26540.00',
        costAmount: '25000.00',
        holdingProfit: '1540.00',
      ),
    ];
    final container = ProviderContainer(overrides: [
      holdingRepositoryProvider.overrideWithValue(FakeHoldingRepository(holdings)),
      snapshotRepositoryProvider.overrideWithValue(FakeSnapshotRepository()),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FundLensTheme.light,
          home: const Scaffold(body: OverviewPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OverviewPage),
      matchesGoldenFile('../../goldens/overview_1440x900.png'),
    );
  });
}
