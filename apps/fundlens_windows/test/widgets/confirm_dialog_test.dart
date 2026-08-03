import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';
import 'package:fundlens_windows/widgets/confirm_dialog.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    bool destructive = false,
    String confirmLabel = '确认',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showConfirmDialog(
                  context,
                  title: '高风险操作',
                  content: const Text('确定要执行该操作吗？此操作不可撤销。'),
                  confirmLabel: confirmLabel,
                  destructive: destructive,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('展示标题、影响说明与操作按钮', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('高风险操作'), findsOneWidget);
    expect(find.text('确定要执行该操作吗？此操作不可撤销。'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
  });

  testWidgets('点击取消关闭对话框', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('高风险确认默认聚焦取消按钮(避免误触 Enter 确认)', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('取消'), findsOneWidget);
    final hasFocus = Focus.of(tester.element(find.text('取消'))).hasFocus;
    expect(hasFocus, isTrue);
  });

  testWidgets('破坏性操作确认按钮使用红色实心样式', (tester) async {
    await pumpApp(tester, destructive: true, confirmLabel: '删除');
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    final deleteButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('删除'),
        matching: find.byType(FilledButton),
      ),
    );
    final background = deleteButton.style?.backgroundColor?.resolve({});
    expect(background, FundLensTokens.profit);
  });
}
