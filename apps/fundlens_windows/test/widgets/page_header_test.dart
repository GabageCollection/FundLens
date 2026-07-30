import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_header.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    double width = 1200,
    List<Widget> actions = const [],
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(
          body: PageHeader(crumb: '组合', title: '资产总览', actions: actions),
        ),
      ),
    );
  }

  testWidgets('面包屑与标题形成层级:面包屑小字在上,标题大字在下', (tester) async {
    await pumpHeader(tester);
    final crumb = tester.widget<Text>(find.text('组合'));
    final title = tester.widget<Text>(find.text('资产总览'));
    expect(crumb.style!.fontSize, 12);
    expect(title.style!.fontSize, greaterThanOrEqualTo(20));
    // 面包屑位于标题上方
    expect(
      tester.getTopLeft(find.text('组合')).dy,
      lessThan(tester.getTopLeft(find.text('资产总览')).dy),
    );
  });

  testWidgets('操作按钮显示在标题行右侧', (tester) async {
    await pumpHeader(
      tester,
      actions: [FilledButton(onPressed: () {}, child: const Text('新建快照'))],
    );
    expect(find.text('新建快照'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('新建快照')).dx,
      greaterThan(tester.getTopLeft(find.text('资产总览')).dx),
    );
  });

  testWidgets('窄屏下操作按钮换行且不溢出', (tester) async {
    await pumpHeader(
      tester,
      width: 420,
      actions: [
        const SizedBox(width: 280, child: TextField()),
        FilledButton(onPressed: () {}, child: const Text('添加持仓')),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('添加持仓'), findsOneWidget);
  });
}
