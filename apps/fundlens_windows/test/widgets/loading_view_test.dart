import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/widgets/loading_view.dart';

void main() {
  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LoadingView())),
    );
  }

  testWidgets('展示加载指示与说明文字', (tester) async {
    await pumpView(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在加载…'), findsOneWidget);
  });

  testWidgets('自定义标签被渲染并进入语义树', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoadingView(label: '正在读取快照…')),
      ),
    );
    expect(find.text('正在读取快照…'), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byType(LoadingView),
    );
    expect(
      semantics.label,
      contains('正在读取快照'),
    );
  });
}
