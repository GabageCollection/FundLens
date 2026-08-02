import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/backup/backup_cipher.dart';
import 'package:fundlens_windows/backup/backup_format.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/features/settings/backup_section.dart';
import 'package:fundlens_windows/features/settings/persisted_settings.dart';
import 'package:fundlens_windows/storage/app_settings_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

import '../../backup/backup_test_harness.dart';

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
  /// When set, [prepareRestore] throws the returned error.
  Object? Function(String source, String password)? onPrepare;

  /// When false, [confirmRestore] throws.
  bool confirmSucceeds = true;

  final List<String> prepared = [];
  final List<String> confirmed = [];
  final List<String> cancelled = [];

  @override
  Future<RestoreSession> prepareRestore(String source, String password) async {
    prepared.add(source);
    final error = onPrepare?.call(source, password);
    if (error is Exception) throw error;
    return RestoreSession(
      tempDir: '/temp/stage',
      candidatePath: '/temp/stage/candidate.db',
      databaseKeyHex: '0' * 64,
      summary: RestoreSummary(
        createdAtUtc: DateTime.utc(2026, 7, 20),
        holdingCount: 7,
        snapshotCount: 3,
        schemaVersion: 1,
      ),
    );
  }

  @override
  Future<void> confirmRestore(RestoreSession session) async {
    confirmed.add(session.tempDir);
    if (!confirmSucceeds) {
      throw const RestoreFailedException('injected failure');
    }
  }

  @override
  Future<void> cancelRestore(RestoreSession session) async {
    cancelled.add(session.tempDir);
  }

  @override
  Future<void> restore(String source, String password) async {
    final session = await prepareRestore(source, password);
    await confirmRestore(session);
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

final class _FakeSettingsRepository implements AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  late _FakeBackupService backupService;
  late _FakeRestoreService restoreService;
  late _FakeBackupFilePicker picker;
  late _FakeSettingsRepository settings;
  late InMemoryBackupFileSystem files;

  setUp(() {
    backupService = _FakeBackupService();
    restoreService = _FakeRestoreService();
    picker = _FakeBackupFilePicker();
    settings = _FakeSettingsRepository();
    files = InMemoryBackupFileSystem();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(backupService),
          databaseRestoreServiceProvider.overrideWithValue(restoreService),
          backupFilePickerProvider.overrideWithValue(picker),
          appSettingsRepositoryProvider.overrideWithValue(settings),
          backupFileSystemProvider.overrideWithValue(files),
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
    await tester.pumpAndSettle();
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

  testWidgets('successful create records backup metadata into info rows',
      (tester) async {
    final destination = '/out/weekly$kFundLensBackupExtension';
    picker.savePath = destination;
    files.seed(destination, List.filled(2048, 0));
    await pumpSection(tester);
    await enterCreatePasswords(tester, 'pw', 'pw');

    await tester.tap(find.byKey(const ValueKey('backup-create-button')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupSection)),
    );
    final info = container.read(lastBackupInfoProvider);
    expect(info, isNotNull);
    expect(info!.path, destination);
    expect(info.bytes, 2048);
    expect(settings.values[SettingKeys.backupLastPath], destination);
    expect(
      int.parse(settings.values[SettingKeys.backupLastFileSizeBytes]!),
      2048,
    );
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('AES-256-GCM · 已加密'), findsOneWidget);
    expect(find.text('手动 · 未启用'), findsOneWidget);
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

  testWidgets('password strength hint appears once a password is typed',
      (tester) async {
    await pumpSection(tester);
    expect(find.textContaining('密码强度'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('backup-create-password')),
      'aA1!aA1!aA1!',
    );
    await tester.pumpAndSettle();

    expect(find.text('密码强度较好。'), findsOneWidget);
    expect(find.textContaining('一旦遗失，备份将无法恢复'), findsOneWidget);
  });

  testWidgets('restore shows the staged summary and cancel never confirms',
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

    expect(restoreService.prepared, hasLength(1));
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.textContaining('备份时间')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('持仓 7 条')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('快照 3 份')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.textContaining('恢复副本')),
      findsOneWidget,
    );

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(restoreService.confirmed, isEmpty);
    expect(restoreService.cancelled, hasLength(1));
    expect(fieldText(tester, 'backup-restore-password'), isEmpty);
  });

  testWidgets('confirmed restore swaps the candidate and refreshes providers',
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

    expect(restoreService.confirmed, hasLength(1));
    expect(restoreService.cancelled, isEmpty);
    expect(find.textContaining('恢复完成'), findsOneWidget);
    expect(fieldText(tester, 'backup-restore-password'), isEmpty);
    // A successful restore refreshes database-dependent providers.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupSection)),
    );
    expect(container.read(databaseRevisionProvider), 1);
  });

  testWidgets('wrong restore password fails during prepare with an error',
      (tester) async {
    picker.openPath = 'D:/backups/my backup$kFundLensBackupExtension';
    restoreService.onPrepare = (_, _) =>
        const BackupAuthenticationException();
    await pumpSection(tester);
    await tester.enterText(
      find.byKey(const ValueKey('backup-restore-password')),
      'wrong',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('backup-restore-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('备份密码不正确或备份文件已损坏'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(restoreService.confirmed, isEmpty);
    expect(restoreService.cancelled, isEmpty);
    expect(fieldText(tester, 'backup-restore-password'), isEmpty);
    // A failed prepare must not refresh providers: nothing was replaced.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BackupSection)),
    );
    expect(container.read(databaseRevisionProvider), 0);
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
