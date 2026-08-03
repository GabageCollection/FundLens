import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/widgets/app_toast.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showAppToast(context, '已保存'),
                child: const Text('触发'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('成功提示展示文案', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('触发'));
    await tester.pump();
    expect(find.text('已保存'), findsOneWidget);
  });

  testWidgets('错误提示带错误图标以区分成功', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showAppToast(context, '保存失败', isError: true),
                child: const Text('触发'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('触发'));
    await tester.pump();
    expect(find.text('保存失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('连续触发时替换旧提示,不堆积', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showAppToast(context, '第一次'),
                child: const Text('触发'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('触发'));
    await tester.pump();
    await tester.tap(find.text('触发'));
    await tester.pump();
    expect(find.text('第一次'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
