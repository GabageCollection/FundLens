import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/features/settings/privacy_section.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

Future<void> pumpSection(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const Scaffold(body: PrivacySection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the local-only privacy facts with a pending cleanup row',
      (tester) async {
    await pumpSection(tester);

    expect(find.text('隐私与安全'), findsOneWidget);
    expect(find.text('持仓、截图与备份仅保存在本机'), findsOneWidget);
    expect(find.text('数据库 SQLCipher 加密，密钥由系统凭据保管'), findsOneWidget);
    expect(find.text('日志中的路径与敏感信息已脱敏'), findsOneWidget);
    expect(find.text('仅在行情任务或手动刷新时联网'), findsOneWidget);
    // Sweep has not run in this harness: the row stays in its pending state.
    expect(find.text('正在启动时检查…'), findsOneWidget);
  });

  testWidgets('a clean sweep reports how many orphaned dirs were removed',
      (tester) async {
    await pumpSection(tester, overrides: [
      tempCleanupResultProvider.overrideWith(
        (ref) => const TempCleanupResult(removedJobs: 3, issueReported: false),
      ),
    ]);

    expect(find.text('已清理 3 个过期临时目录'), findsOneWidget);
  });

  testWidgets('a cleanup issue is surfaced with a retry note', (tester) async {
    await pumpSection(tester, overrides: [
      tempCleanupResultProvider.overrideWith(
        (ref) => const TempCleanupResult(removedJobs: 1, issueReported: true),
      ),
    ]);

    expect(find.text('部分临时目录未能清理，将在下次启动重试'), findsOneWidget);
  });
}
