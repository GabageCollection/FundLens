import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holdings_page.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

import '../overview/asset_spectrum_test.dart' show FakeHoldingRepository;
import 'holding_detail_drawer_test.dart' show RecordingHoldingRepository;
import 'holding_grid_test.dart' show generateGridHoldings;

/// 默认 8 行:默认排序(当前金额降序)下首行是 产品0007(id h-7),
/// 8×56px 行高在 1440×900 页面内全部可见(避免虚拟化未构建导致断言失败)。
Future<ProviderContainer> pumpHoldings(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  HoldingRepository? repo,
  int holdingCount = 8,
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(
      repo ?? FakeHoldingRepository(generateGridHoldings(holdingCount)),
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
  return container;
}

void main() {
  testWidgets('页头操作区:搜索/4 筛选/排序/添加共 7 项', (tester) async {
    await pumpHoldings(tester);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.dense);
    expect(scaffold.actions.length, 7);
    // 工具栏下拉按钮与表格列头共用标签(资产类别/来源平台/数据状态),
    // 用 OutlinedButton 精确定位工具栏按钮而非任意文本。
    expect(
      find.widgetWithText(OutlinedButton, '资产类别'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, '来源平台'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, '数据状态'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, '组合标签'),
      findsOneWidget,
    );
    expect(find.text('当前金额 · 从高到低'), findsOneWidget);
    expect(find.text('添加持仓'), findsOneWidget);
    expect(find.text('共 8 项持仓'), findsOneWidget);
  });

  testWidgets('空持仓:两个入口', (tester) async {
    await pumpHoldings(tester, holdingCount: 0);
    expect(find.text('还没有持仓'), findsOneWidget);
    expect(find.text('导入资产'), findsOneWidget);
    expect(find.text('手动添加'), findsOneWidget);
  });

  testWidgets('筛选无结果:清除筛选恢复列表', (tester) async {
    await pumpHoldings(tester);
    await tester.enterText(find.byType(TextField), '不存在的产品');
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的持仓'), findsOneWidget);
    expect(find.text('共 0 项持仓'), findsOneWidget);

    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    expect(find.text('产品0007'), findsOneWidget);
    expect(find.text('共 8 项持仓'), findsOneWidget);
  });

  testWidgets('行点击打开详情抽屉并可关闭', (tester) async {
    await pumpHoldings(tester);
    await tester.tap(find.text('产品0007'));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('数据来源'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('drawer-close')));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsNothing);
  });

  testWidgets('批量删除:全选后二次确认删除', (tester) async {
    final repo = RecordingHoldingRepository(generateGridHoldings(3));
    await pumpHoldings(tester, repo: repo);
    await tester.tap(find.byKey(const ValueKey('select-all')));
    await tester.pumpAndSettle();
    expect(find.text('已选 3 项'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(repo.deletedIds.single, hasLength(3));
    expect(find.text('已删除 3 项持仓'), findsOneWidget);
  });

  testWidgets('1920 宽度无溢出', (tester) async {
    await pumpHoldings(tester, size: const Size(1920, 1080));
    expect(
      find.widgetWithText(OutlinedButton, '数据状态'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('125% 缩放等效宽度(约1092)下操作区不重叠', (tester) async {
    await pumpHoldings(tester, size: const Size(1092, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('添加持仓'), findsOneWidget);
  });

  testWidgets('页面文案无禁词', (tester) async {
    await pumpHoldings(tester);
    for (final word in ['建议', '应当', '调仓', '再平衡', '买入', '卖出']) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
  });

  testWidgets('键盘:行聚焦后 Enter 打开抽屉', (tester) async {
    await pumpHoldings(tester);
    // 点击行使行 InkWell 获得焦点(抽屉随之打开);关闭抽屉后焦点恢复到该行。
    await tester.tap(find.text('产品0007'));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drawer-close')));
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsNothing);
    // 焦点已恢复到行 InkWell,Enter 重新打开抽屉。
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('基本信息'), findsOneWidget);
  });
}
