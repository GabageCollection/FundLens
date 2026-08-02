import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/features/settings/backup_section.dart';
import 'package:fundlens_windows/features/settings/settings_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

final class _NoopBackupService implements BackupService {
  @override
  Future<void> create(String destination, String password) async {}
}

final class _NoopRestoreService implements DatabaseRestoreService {
  @override
  Future<void> restore(String source, String password) async {}

  @override
  Future<RestoreSession> prepareRestore(String source, String password) async {
    throw UnimplementedError('not exercised in this harness');
  }

  @override
  Future<void> confirmRestore(RestoreSession session) async {}

  @override
  Future<void> cancelRestore(RestoreSession session) async {}
}

Future<ProviderContainer> pumpSettings(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SettingsPage)),
  );
}

void main() {
  testWidgets('设置页使用 form 档 PageScaffold', (tester) async {
    await pumpSettings(tester);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.form);
    expect(find.text('设置与备份'), findsOneWidget);
    expect(find.text('数据'), findsWidgets); // 面包屑
  });

  testWidgets('asset rules are opt-in and advanced settings collapsed',
      (tester) async {
    await pumpSettings(tester);
    final rulesSection = find.byKey(const ValueKey('asset-rules-section'));
    expect(rulesSection, findsOneWidget);
    expect(find.text('资产识别规则'), findsOneWidget);
    expect(find.text('高级设置'), findsOneWidget);
    expect(find.textContaining('理想比例'), findsNothing);
    // 折叠时不渲染参数输入框。
    expect(
      find.byKey(const ValueKey('threshold-maxSingleHoldingShare')),
      findsNothing,
    );
  });

  testWidgets('market section shows toggle, frequency, manual refresh and status',
      (tester) async {
    await pumpSettings(tester);
    expect(find.text('自动刷新行情'), findsOneWidget);
    final marketSection = find.byKey(const ValueKey('market-section'));
    expect(
      find.descendant(of: marketSection, matching: find.byType(Switch)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: marketSection, matching: find.text('每天')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: marketSection, matching: find.text('每周')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: marketSection, matching: find.text('仅手动')),
      findsOneWidget,
    );
    expect(find.text('手动刷新行情'), findsOneWidget);
    // No quote service wired in this harness: degraded state is factual.
    expect(find.textContaining('行情引擎不可用'), findsOneWidget);
  });

  testWidgets('privacy section states local-only processing', (tester) async {
    await pumpSettings(tester);
    expect(find.textContaining('仅在本机处理'), findsOneWidget);
    expect(find.textContaining('临时副本'), findsOneWidget);
    expect(find.textContaining('脱敏'), findsOneWidget);
  });

  testWidgets('backup section offers create and restore controls', (tester) async {
    await pumpSettings(tester);
    final backupSection = find.byKey(const ValueKey('backup-section'));
    expect(backupSection, findsOneWidget);
    expect(
      find.descendant(of: backupSection, matching: find.text('加密备份')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: backupSection, matching: find.text('创建加密备份')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: backupSection,
        matching: find.text('选择备份文件并恢复'),
      ),
      findsOneWidget,
    );
    // No backup services are wired in this harness: controls are disabled.
    expect(
      find.descendant(of: backupSection, matching: find.text('备份功能当前不可用。')),
      findsOneWidget,
    );
  });

  testWidgets('backup controls are enabled when backup services are wired',
      (tester) async {
    await pumpSettings(
      tester,
      overrides: [
        backupServiceProvider.overrideWithValue(_NoopBackupService()),
        databaseRestoreServiceProvider.overrideWithValue(_NoopRestoreService()),
      ],
    );

    expect(find.text('备份功能当前不可用。'), findsNothing);

    final createPassword = find.byKey(const ValueKey('backup-create-password'));
    await tester.ensureVisible(createPassword);
    await tester.pumpAndSettle();
    await tester.enterText(createPassword, 'pw');
    await tester.pumpAndSettle();
    final confirmField = find.byKey(const ValueKey('backup-create-confirm'));
    await tester.ensureVisible(confirmField);
    await tester.pumpAndSettle();
    await tester.enterText(confirmField, 'pw');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
              find.byKey(const ValueKey('backup-create-button')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('backup-restore-password')),
      'pw',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
              find.byKey(const ValueKey('backup-restore-button')))
          .onPressed,
      isNotNull,
    );
  });
}
