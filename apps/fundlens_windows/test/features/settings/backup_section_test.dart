import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/backup/backup_cipher.dart';
import 'package:fundlens_windows/backup/backup_format.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/features/settings/backup_section.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final class _FakeBackupService implements BackupService {
  Future<void> Function(String destination, String password)? onCreate;
  final List<({String destination, String password})> calls = [];

  @override
  Future<void> create(String destination, String password) {
    calls.add((destination: destination, password: password));
    final handler = onCreate;
    return handler == null ? Future.value() : handler(destination, password);
  }
}

final class _FakeRestoreService implements DatabaseRestoreService {
  Future<void> Function(String source, String password)? onRestore;
  final List<({String source, String password})> calls = [];

  @override
  Future<void> restore(String source, String password) {
    calls.add((source: source, password: password));
    final handler = onRestore;
    return handler == null ? Future.value() : handler(source, password);
  }
}

final class _FakeBackupFilePicker implements BackupFilePicker {
  String? savePath;
  String? openPath;

  @override
  Future<String?> pickBackupSaveLocation() async => savePath;

  @override
  Future<String?> pickBackupFile() async => openPath;
}

void main() {
  late _FakeBackupService backupService;
  late _FakeRestoreService restoreService;
  late _FakeBackupFilePicker picker;

  setUp(() {
    backupService = _FakeBackupService();
    restoreService = _FakeRestoreService();
    picker = _FakeBackupFilePicker();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(backupService),
          databaseRestoreServiceProvider.overrideWithValue(restoreService),
          backupFilePickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(
          theme: FundLensTheme.light,
          home: const Scaffold(body: SingleChildScrollView(child: BackupSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterCreatePasswords(
    WidgetTester tester,
    String password,
    String confirmation,
  ) async {
    await tester.enterText(
      find.byKey(const ValueKey('backup-create-password')),
      password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('backup-create-confirm')),
      confirmation,
    );
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String key) {
    final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
    return field.controller!.text;
  }

  testWidgets('create requires matching non-empty passwords', (tester) async {
    await pumpSection(tester);
    final button = find.byKey(const ValueKey('backup-create-button'));
    expect(
      tester.widget<FilledButton>(button).onPressed,
      isNull,
      reason: 'empty passwords must keep the button disabled',
    );

    await enterCreatePasswords(tester, 'one', 'two');
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await enterCreatePasswords(tester, 'same', 'same');
    expect(find.text('两次输入的密码不一致'), findsNothing);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('successful create uses the picked path and clears passwords',
      (tester) async {
    picker.savePath = '/out/weekly$kFundLensBackupExtension';
    await pumpSection(tester);
    await enterCreatePasswords(tester, 'pw', 'pw');

    await tester.tap(find.byKey(const ValueKey('backup-create-button')));
    await tester.pumpAndSettle();

    expect(backupService.calls, hasLength(1));
    expect(
      backupService.calls.single.destination,
      '/out/weekly$kFundLensBackupExtension',
    );
    expect(backupService.calls.single.password, 'pw');
    expect(find.textContaining('备份已创建'), findsOneWidget);
    expect(fieldText(tester, 'backup-create-password'), isEmpty);
    expect(fieldText(tester, 'backup-create-confirm'), isEmpty);
  });

  testWidgets('create appends the backup extension when missing',
      (tester) async {
    picker.savePath = '/out/weekly';
    await pumpSection(tester);
    await enterCreatePasswords(tester, 'pw', 'pw');

    await tester.tap(find.byKey(const ValueKey('backup-create-button')));
    await tester.pumpAndSettle();

    expect(
      backupService.calls.single.destination,
      '/out/weekly$kFundLensBackupExtension',
    );
  });

  testWidgets('create failure shows an error and clears passwords',
      (tester) async {
    picker.savePath = '/out/weekly$kFundLensBackupExtension';
    backupService.onCreate = (_, _) =>
        Future.error(const BackupFailedException('disk full'));
    await pumpSection(tester);
    await enterCreatePasswords(tester, 'pw', 'pw');

    await tester.tap(find.byKey(const ValueKey('backup-create-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('备份创建失败'), findsOneWidget);
    expect(fieldText(tester, 'backup-create-password'), isEmpty);
    expect(fieldText(tester, 'backup-create-confirm'), isEmpty);
  });

  testWidgets('restore confirmation names the file and the recovery copy; '
      'cancel never calls the service', (tester) async {
    picker.openPath = 'D:/backups/my backup$kFundLensBackupExtension';
    await pumpSection(tester);
    await tester.enterText(
      find.byKey(const ValueKey('backup-restore-password')),
      'pw',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('backup-restore-button')));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('my backup$kFundLensBackupExtension'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('恢复副本')),
      findsOneWidget,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(restoreService.calls, isEmpty);
    expect(fieldText(tester, 'backup-restore-password'), isEmpty);
  });

  testWidgets('confirmed restore calls the service and clears the password',
      (tester) async {
    picker.openPath = 'D:/backups/my backup$kFundLensBackupExtension';
    await pumpSection(tester);
    await tester.enterText(
      find.byKey(const ValueKey('backup-restore-password')),
      'pw',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('backup-restore-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();

    expect(restoreService.calls, hasLength(1));
    expect(restoreService.calls.single.source,
        'D:/backups/my backup$kFundLensBackupExtension');
    expect(restoreService.calls.single.password, 'pw');
    expect(find.textContaining('恢复完成'), findsOneWidget);
    expect(fieldText(tester, 'backup-restore-password'), isEmpty);
  });

  testWidgets('wrong restore password shows an authentication error',
      (tester) async {
    picker.openPath = 'D:/backups/my backup$kFundLensBackupExtension';
    restoreService.onRestore = (_, _) =>
        Future.error(const BackupAuthenticationException());
    await pumpSection(tester);
    await tester.enterText(
      find.byKey(const ValueKey('backup-restore-password')),
      'wrong',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('backup-restore-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();

    expect(find.textContaining('备份密码不正确或备份文件已损坏'), findsOneWidget);
    expect(fieldText(tester, 'backup-restore-password'), isEmpty);
  });

  testWidgets('busy state disables actions and shows progress', (tester) async {
    picker.savePath = '/out/weekly$kFundLensBackupExtension';
    final pending = Completer<void>();
    backupService.onCreate = (_, _) => pending.future;
    await pumpSection(tester);
    await enterCreatePasswords(tester, 'pw', 'pw');

    await tester.tap(find.byKey(const ValueKey('backup-create-button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
              find.byKey(const ValueKey('backup-create-button')))
          .onPressed,
      isNull,
    );

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cancelling the save picker never calls the service',
      (tester) async {
    picker.savePath = null;
    await pumpSection(tester);
    await enterCreatePasswords(tester, 'pw', 'pw');

    await tester.tap(find.byKey(const ValueKey('backup-create-button')));
    await tester.pumpAndSettle();

    expect(backupService.calls, isEmpty);
  });
}
