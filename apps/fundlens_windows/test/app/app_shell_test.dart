import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/app/app_shell.dart';
import 'package:fundlens_windows/app/fundlens_app.dart';

Widget buildTestApp() {
  return FundLensApp(
    pages: [
      for (final destination in AppDestination.values)
        Center(child: Text('page-${destination.name}')),
    ],
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

  testWidgets('top data-status button navigates to importReview', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    expect(find.text('page-importReview'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('data-status-button')));
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
}
