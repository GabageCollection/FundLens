import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/widgets/grid_row.dart';

Finder get redBoxFinder =>
    find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == Colors.red);

Finder get blueBoxFinder =>
    find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == Colors.blue);

void main() {
  Future<void> pumpGrid(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridRow(
            children: const [
              GridCol(span: 7, child: ColoredBox(color: Colors.red, child: SizedBox(height: 40))),
              GridCol(span: 5, child: ColoredBox(color: Colors.blue, child: SizedBox(height: 40))),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('宽模式按 12 列比例分配宽度', (tester) async {
    await pumpGrid(tester, 1216); // 去掉 11 个 gutter 后每列 (1216-176)/12≈86.67
    final first = tester.getSize(redBoxFinder).width;
    final second = tester.getSize(blueBoxFinder).width;
    expect(first / second, closeTo(7 / 5, 0.02));
    expect(first + second + 16, closeTo(1216, 0.5));
  });

  testWidgets('低于 collapseBelow 时降为纵向堆叠', (tester) async {
    await pumpGrid(tester, 800);
    final firstTop = tester.getTopLeft(redBoxFinder).dy;
    final secondTop = tester.getTopLeft(blueBoxFinder).dy;
    expect(secondTop, greaterThan(firstTop));
    // 堆叠时两列同宽
    expect(
      tester.getSize(redBoxFinder).width,
      tester.getSize(blueBoxFinder).width,
    );
    expect(tester.takeException(), isNull);
  });
}
