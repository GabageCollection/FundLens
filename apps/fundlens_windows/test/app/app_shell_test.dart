import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/app/app_shell.dart';
import 'package:fundlens_windows/app/fundlens_app.dart';
import 'package:fundlens_windows/features/data_health/data_health_providers.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

import '../features/overview/asset_spectrum_test.dart' show FakeHoldingRepository;

/// 顶栏已含全局数据健康按钮(ConsumerWidget),需提供最小 ProviderScope:
/// 空持仓仓库 + 计算器 + 最近导入记录(null),其余依赖走默认值。
Widget buildTestApp() {
  return ProviderScope(
    overrides: [
      holdingRepositoryProvider.overrideWithValue(FakeHoldingRepository(const [])),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      lastImportRecordProvider.overrideWithValue(null),
    ],
    child: FundLensApp(
      pages: [
        for (final destination in AppDestination.values)
          Center(child: Text('page-${destination.name}')),
      ],
    ),
  );
}

Future<void> pumpAtSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(buildTestApp());
  await tester.pumpAndSettle();
}

void main() {
  const sizes = [Size(1280, 720), Size(1440, 900), Size(1920, 1080)];

  for (final size in sizes) {
    testWidgets('shell exposes all six destinations at ${size.width}x${size.height}', (tester) async {
      await pumpAtSize(tester, size);
      for (final label in ['资产总览', '资产分析', '全部持仓', '历史快照', '导入与识别', '设置与备份']) {
        expect(
          find.descendant(of: find.byKey(const ValueKey('app-nav')), matching: find.text(label)),
          findsOneWidget,
          reason: '$label missing at $size',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow and content visible at ${size.width}x${size.height}', (tester) async {
      await pumpAtSize(tester, size);
      expect(find.text('page-overview'), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('page switches retain state via IndexedStack', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    expect(find.byType(IndexedStack), findsOneWidget);
    await tester.tap(find.text('全部持仓'));
    await tester.pumpAndSettle();
    expect(find.text('page-holdings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+1..6 switches destinations by keyboard', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('page-snapshots'), findsOneWidget);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('page-analysis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data-status button opens popover; 查看导入记录 navigates to importReview', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    expect(find.text('page-importReview'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('data-status-button')));
    await tester.pumpAndSettle();
    // 面板打开:出现四个操作入口。
    expect(find.text('查看导入记录'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('data-health-imports')));
    await tester.pumpAndSettle();
    expect(find.text('page-importReview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation shows a visible focus indicator', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('≥1280 完整侧栏宽度为 216', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navWidth,
    );
  });

  testWidgets('768–1279 可手动折叠为 64px 图标栏', (tester) async {
    await pumpAtSize(tester, const Size(1100, 800));
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navWidth,
    );
    await tester.tap(find.byKey(const ValueKey('nav-collapse-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navRailWidth,
    );
    // 折叠后文字标签隐藏
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-nav')),
        matching: find.text('资产总览'),
      ),
      findsNothing,
    );
    // 再次点击恢复
    await tester.tap(find.byKey(const ValueKey('nav-collapse-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navWidth,
    );
  });

  testWidgets('<768 切换为抽屉导航', (tester) async {
    await pumpAtSize(tester, const Size(700, 800));
    expect(find.byKey(const ValueKey('app-nav')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-drawer-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-nav')), findsOneWidget);
    await tester.tap(find.text('全部持仓'));
    await tester.pumpAndSettle();
    expect(find.text('page-holdings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶栏不再渲染页面标题(下沉到 PageHeader)', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    // 替身页面只含 page-<name> 文本;侧栏导航项必然含「资产总览」标签,
    // 因此全局应恰好只剩这 1 个 —— 若顶栏仍渲染标题则会出现第 2 个。
    expect(find.text('资产总览'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-nav')),
        matching: find.text('资产总览'),
      ),
      findsOneWidget,
    );
  });
}
