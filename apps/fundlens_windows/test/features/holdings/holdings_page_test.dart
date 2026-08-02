import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holdings_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

import '../overview/asset_spectrum_test.dart' show FakeHoldingRepository;
import 'holding_grid_test.dart' show generateGridHoldings;

void main() {
  Future<void> pumpHoldings(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    final container = ProviderContainer(overrides: [
      holdingRepositoryProvider.overrideWithValue(
        FakeHoldingRepository(generateGridHoldings(20)),
      ),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
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
          home: const Scaffold(body: HoldingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('持仓页使用 dense 档 PageScaffold,操作区在页头', (tester) async {
    await pumpHoldings(tester);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.dense);
    expect(scaffold.crumb, '组合');
    expect(find.text('全部持仓'), findsOneWidget);
    expect(find.text('添加持仓'), findsOneWidget);
    // 搜索/4 筛选下拉/排序下拉/添加持仓位于页头操作区。
    expect(scaffold.actions.length, 7);
  });

  testWidgets('125% 缩放等效宽度(约1092)下操作区不重叠', (tester) async {
    await pumpHoldings(tester, size: const Size(1092, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('添加持仓'), findsOneWidget);
  });
}
