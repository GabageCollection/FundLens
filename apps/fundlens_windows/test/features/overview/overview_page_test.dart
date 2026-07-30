import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/overview/overview_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

import 'asset_spectrum_test.dart'
    show FakeHoldingRepository, FakeSnapshotRepository;
import 'overview_golden_test.dart' show goldenHolding;

void main() {
  Future<void> pumpOverview(WidgetTester tester, {Size size = const Size(1600, 900)}) async {
    final container = ProviderContainer(overrides: [
      holdingRepositoryProvider.overrideWithValue(
        FakeHoldingRepository([
          goldenHolding(
            id: 'h-1',
            assetClass: AssetClass.equity,
            instrumentType: InstrumentType.offExchangeFund,
            productName: '稳健成长混合基金',
            currentValue: '52340.00',
          ),
        ]),
      ),
      snapshotRepositoryProvider.overrideWithValue(FakeSnapshotRepository()),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = size;
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
  }

  testWidgets('总览页使用 standard 档 PageScaffold,标题只出现一次', (tester) async {
    await pumpOverview(tester);
    expect(find.byType(PageScaffold), findsOneWidget);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.standard);
    expect(find.text('资产总览'), findsOneWidget);
    expect(find.text('组合'), findsOneWidget);
  });

  testWidgets('窄屏下 KPI 条换行堆叠且不溢出', (tester) async {
    await pumpOverview(tester, size: const Size(760, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('总资产'), findsOneWidget);
  });
}
