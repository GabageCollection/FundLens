import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/features/analysis/structure_thresholds.dart';
import 'package:fundlens_windows/features/settings/backup_section.dart';
import 'package:fundlens_windows/features/settings/settings_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final class _NoopBackupService implements BackupService {
  @override
  Future<void> create(String destination, String password) async {}
}

final class _NoopRestoreService implements DatabaseRestoreService {
  @override
  Future<void> restore(String source, String password) async {}
}

Future<ProviderContainer> pumpSettings(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1280, 720);
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
  testWidgets('thresholds are opt-in with no ideal defaults', (tester) async {
    await pumpSettings(tester);
    final thresholdsSection =
        find.byKey(const ValueKey('structure-thresholds-section'));
    expect(find.textContaining('理想比例'), findsNothing);
    expect(
      find.descendant(of: thresholdsSection, matching: find.byType(TextField)),
      findsNothing,
    );
    await tester.tap(find.text('添加结构阈值'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: thresholdsSection, matching: find.byType(TextField)),
      findsWidgets,
    );
  });

  testWidgets('each threshold is labeled as user-set hint only', (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('添加结构阈值'));
    await tester.pumpAndSettle();
    expect(find.text('由你设置，仅用于结构提示'), findsNWidgets(4));
    expect(find.text('单一持仓占比上限'), findsOneWidget);
    expect(find.text('单一类别占比上限'), findsOneWidget);
    expect(find.text('现金及存款占比下限'), findsOneWidget);
    expect(find.text('权益仓位占比上限'), findsOneWidget);
  });

  testWidgets('editing a threshold writes structureThresholdsProvider',
      (tester) async {
    final container = await pumpSettings(tester);
    await tester.tap(find.text('添加结构阈值'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('threshold-maxSingleHoldingShare')),
      '35',
    );
    await tester.pumpAndSettle();

    final thresholds = container.read(structureThresholdsProvider);
    expect(thresholds.maxSingleHoldingShare, isNotNull);
    expect(
      thresholds.maxSingleHoldingShare!.value.toDouble(),
      closeTo(0.35, 0.0001),
    );
    expect(thresholds.maxAssetClassShare, isNull);
  });

  testWidgets('market section shows toggle, manual refresh and status',
      (tester) async {
    await pumpSettings(tester);
    expect(find.text('每日自动刷新'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
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
    await tester.enterText(
      find.byKey(const ValueKey('backup-create-confirm')),
      'pw',
    );
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
