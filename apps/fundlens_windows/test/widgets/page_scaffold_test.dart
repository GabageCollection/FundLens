import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_header.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

Finder get bodyFinder =>
    find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == Colors.red);

void main() {
  Future<void> pumpScaffold(
    WidgetTester tester,
    PageWidthTier tier, {
    double width = 1920,
  }) async {
    tester.view.physicalSize = Size(width, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(
          body: PageScaffold(
            tier: tier,
            crumb: '组合',
            title: '测试页',
            body: const ColoredBox(color: Colors.red, child: SizedBox.expand()),
          ),
        ),
      ),
    );
  }

  testWidgets('standard 档在 1920 宽屏下限宽 1440 并居中', (tester) async {
    await pumpScaffold(tester, PageWidthTier.standard);
    final headerLeft = tester.getTopLeft(find.byType(PageHeader)).dx;
    final bodySize = tester.getSize(bodyFinder);
    // 正文宽度 = 1440 - 左右各 24 padding
    expect(bodySize.width, 1440 - 48);
    // 居中:左侧空白 = (1920 - 1440) / 2 + 24
    expect(headerLeft, (1920 - 1440) / 2 + 24);
  });

  testWidgets('dense 档限宽 1680', (tester) async {
    await pumpScaffold(tester, PageWidthTier.dense);
    expect(tester.getSize(bodyFinder).width, 1680 - 48);
  });

  testWidgets('form 档限宽 1120', (tester) async {
    await pumpScaffold(tester, PageWidthTier.form);
    expect(tester.getSize(bodyFinder).width, 1120 - 48);
  });

  testWidgets('窗口窄于档位时不溢出,跟随可用宽度', (tester) async {
    await pumpScaffold(tester, PageWidthTier.standard, width: 900);
    expect(tester.getSize(bodyFinder).width, 900 - 48);
    expect(tester.takeException(), isNull);
  });
}
