import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';
import 'package:fundlens_windows/widgets/error_retry_view.dart';

void main() {
  testWidgets('展示标题、影响说明与重试按钮', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorRetryView(
            title: '持仓数据暂时不可用',
            message: '持仓数据加载失败，本地数据未受影响，请重试。',
            onRetry: _noop,
          ),
        ),
      ),
    );
    expect(find.text('持仓数据暂时不可用'), findsOneWidget);
    expect(find.text('持仓数据加载失败，本地数据未受影响，请重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('点击重试触发回调', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorRetryView(
            title: '持仓数据暂时不可用',
            message: '持仓数据加载失败，本地数据未受影响，请重试。',
            onRetry: () => retried++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('重试'));
    expect(retried, 1);
  });

  testWidgets('错误图标用警示文字档颜色,不依赖颜色单通道', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorRetryView(
            title: '持仓数据暂时不可用',
            message: '持仓数据加载失败，本地数据未受影响，请重试。',
            onRetry: _noop,
          ),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, FundLensTokens.warnText);
  });
}

void _noop() {}
