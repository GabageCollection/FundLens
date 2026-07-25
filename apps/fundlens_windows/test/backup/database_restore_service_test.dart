import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/backup/backup_cipher.dart';
import 'package:fundlens_windows/backup/backup_format.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/backup/pointycastle_backup_cipher.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/database_opener.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:path/path.dart' as p;

import 'backup_test_harness.dart';

void main() {
  const databasePath = '/data/fundlens.db';
  const backupPath = '/backups/my backup$kFundLensBackupExtension';
  const recoveryBase = '/recovery';
  final currentKey = 'a' * 64;
  final backupKey = 'b' * 64;

  group('DatabaseRestoreService.restore (in-memory file system)', () {
    late InMemoryBackupFileSystem files;
    late FakeDatabaseLifecycle lifecycle;
    late InMemoryDatabaseKeyStore keyStore;
    late FakeBackupDatabaseInspector inspector;
    late PointyCastleBackupCipher cipher;
    late DatabaseRestoreService service;

    setUp(() {
      files = InMemoryBackupFileSystem();
      lifecycle = FakeDatabaseLifecycle();
      keyStore = InMemoryDatabaseKeyStore(currentKey);
      inspector = FakeBackupDatabaseInspector(files);
      cipher = PointyCastleBackupCipher();
      service = DatabaseRestoreService(
        databasePath: databasePath,
        lifecycle: lifecycle,
        keyStore: keyStore,
        cipher: cipher,
        files: files,
        inspector: inspector,
        supportedSchemaVersion: 1,
        recoveryDirectoryPath: recoveryBase,
      );
      files.seed(databasePath, syntheticDatabase('current'));
    });

    Future<void> seedValidBackup({String password = 'secret'}) async {
      final backup = await buildBackup(
        cipher: cipher,
        databaseKeyHex: backupKey,
        databaseBytes: syntheticDatabase('from-backup'),
        password: password,
      );
      files.seed(backupPath, backup);
      inspector.versionsByContent['synthetic-db:from-backup'] = 1;
    }

    test('wrong password never closes or replaces current database', () async {
      await seedValidBackup(password: 'secret');

      await expectLater(
        service.restore(backupPath, 'wrong'),
        throwsA(isA<BackupAuthenticationException>()),
      );
      expect(files.bytesAt(databasePath), syntheticDatabase('current'));
      expect(lifecycle.closeCount, 0);
      expect(keyStore.keyHex, currentKey);
    });

    test('corrupt file is rejected before touching the current database',
        () async {
      files.seed(backupPath, [1, 2, 3, 4]);

      await expectLater(
        service.restore(backupPath, 'secret'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(files.bytesAt(databasePath), syntheticDatabase('current'));
      expect(lifecycle.closeCount, 0);
    });

    test('oversized backup is rejected before authentication', () async {
      files.seed(backupPath, List.filled(kMaxBackupBytes + 1, 0));

      await expectLater(
        service.restore(backupPath, 'secret'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(files.bytesAt(databasePath), syntheticDatabase('current'));
      expect(lifecycle.closeCount, 0);
    });

    test('unsupported future schema is rejected before closing', () async {
      await seedValidBackup();
      inspector.versionsByContent['synthetic-db:from-backup'] = 99;

      await expectLater(
        service.restore(backupPath, 'secret'),
        throwsA(isA<RestoreFailedException>()),
      );
      expect(files.bytesAt(databasePath), syntheticDatabase('current'));
      expect(lifecycle.closeCount, 0);
      expect(keyStore.keyHex, currentKey);
    });

    test('successful restore replaces database and key, keeps recovery copy',
        () async {
      await seedValidBackup();

      await service.restore(backupPath, 'secret');

      expect(files.bytesAt(databasePath), syntheticDatabase('from-backup'));
      expect(keyStore.keyHex, backupKey);
      expect(lifecycle.closeCount, 1);
      expect(lifecycle.reopenedWith, [backupKey]);
      // Timestamped recovery directory keeps the pre-restore database.
      final recoveryFiles = files.files.keys
          .where((path) =>
              path.replaceAll('\\', '/').startsWith('$recoveryBase/'))
          .toList();
      expect(recoveryFiles, isNotEmpty);
      expect(
        files.bytesAt(recoveryFiles.first),
        syntheticDatabase('current'),
      );
      // Staging directory is cleaned.
      expect(files.leftoverTempFiles(), isEmpty);
    });

    test('replacement failure restores the pre-restore copy', () async {
      await seedValidBackup();
      files.failAtomicMove = true;

      await expectLater(
        service.restore(backupPath, 'secret'),
        throwsA(isA<RestoreFailedException>()),
      );
      expect(files.bytesAt(databasePath), syntheticDatabase('current'));
      expect(keyStore.keyHex, currentKey);
      expect(lifecycle.closeCount, 1);
      expect(lifecycle.reopenedWith, [currentKey]);
    });

    test('reopen failure after replacement rolls back database and key',
        () async {
      await seedValidBackup();
      lifecycle.failReopenWithKey = backupKey;

      await expectLater(
        service.restore(backupPath, 'secret'),
        throwsA(isA<RestoreFailedException>()),
      );
      expect(files.bytesAt(databasePath), syntheticDatabase('current'));
      expect(keyStore.keyHex, currentKey);
      expect(lifecycle.reopenedWith, [currentKey]);
    });
  });

  group('end-to-end with sqlite3mc encrypted databases', () {
    final keyA = 'a' * 64;
    final keyB = 'b' * 64;

    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('fundlens-restore-');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    Holding holding(String id, String value) => Holding(
          id: id,
          sourcePlatform: SourcePlatform.alipay,
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: AssetClass.fixedIncome,
          productName: '脱敏基金$id',
          currency: 'CNY',
          currentValue: DecimalValue.parse(value),
          valuationMethod: ValuationMethod.manualAmount,
          dataOrigin: DataOrigin.manual,
          fieldProvenance: const {},
          createdAt: DateTime.utc(2026, 7, 19),
          updatedAt: DateTime.utc(2026, 7, 19),
        );

    Future<AppDatabase> openDatabase(File file, String keyHex) async {
      final db = AppDatabase(openEncryptedDatabase(file, keyHex));
      // Force the connection open so a wrong key fails here, not later.
      await db.customSelect('SELECT count(*) FROM sqlite_master').get();
      return db;
    }

    Future<List<String>> holdingIds(AppDatabase db) async {
      final holdings = await DriftHoldingRepository(db).watchAll().first;
      return holdings.map((h) => h.id).toList();
    }

    test('backup then restore returns the database and key to backup state',
        () async {
      final dbFile = File(p.join(tempRoot.path, 'fundlens.db'));
      final backupPath = p.join(tempRoot.path, 'copy$kFundLensBackupExtension');
      final cipher = PointyCastleBackupCipher();
      final keyStore = InMemoryDatabaseKeyStore(keyA);
      const files = IoBackupFileSystem();

      // Create the live database and back it up.
      var db = await openDatabase(dbFile, keyA);
      await DriftHoldingRepository(db).upsert(holding('h1', '1000'));
      final backupLifecycle =
          DriftDatabaseLifecycle(databaseFile: dbFile, database: db);
      await BackupService(
        databasePath: dbFile.path,
        lifecycle: backupLifecycle,
        keyStore: keyStore,
        cipher: cipher,
        files: files,
      ).create(backupPath, 'correct horse');
      await db.close();

      // Simulate later state: a different key and different holdings.
      await dbFile.delete();
      db = await openDatabase(dbFile, keyB);
      await DriftHoldingRepository(db).upsert(holding('h2', '2000'));
      await keyStore.write(keyB);
      final lifecycle =
          DriftDatabaseLifecycle(databaseFile: dbFile, database: db);
      addTearDown(() => lifecycle.currentDatabase.close());

      await DatabaseRestoreService(
        databasePath: dbFile.path,
        lifecycle: lifecycle,
        keyStore: keyStore,
        cipher: cipher,
        files: files,
        inspector: const SqliteBackupDatabaseInspector(),
        supportedSchemaVersion: 1,
        recoveryDirectoryPath: p.join(tempRoot.path, 'recovery'),
      ).restore(backupPath, 'correct horse');

      expect(keyStore.keyHex, keyA);
      expect(await holdingIds(lifecycle.currentDatabase), ['h1']);
    });

    test('injected replacement failure keeps the live database readable',
        () async {
      final dbFile = File(p.join(tempRoot.path, 'fundlens.db'));
      final backupPath = p.join(tempRoot.path, 'copy$kFundLensBackupExtension');
      final cipher = PointyCastleBackupCipher();
      final keyStore = InMemoryDatabaseKeyStore(keyA);
      const files = IoBackupFileSystem();

      var db = await openDatabase(dbFile, keyA);
      await DriftHoldingRepository(db).upsert(holding('h1', '1000'));
      final backupLifecycle =
          DriftDatabaseLifecycle(databaseFile: dbFile, database: db);
      await BackupService(
        databasePath: dbFile.path,
        lifecycle: backupLifecycle,
        keyStore: keyStore,
        cipher: cipher,
        files: files,
      ).create(backupPath, 'correct horse');
      await db.close();

      await dbFile.delete();
      db = await openDatabase(dbFile, keyB);
      await DriftHoldingRepository(db).upsert(holding('h2', '2000'));
      await keyStore.write(keyB);
      final lifecycle =
          DriftDatabaseLifecycle(databaseFile: dbFile, database: db);
      addTearDown(() => lifecycle.currentDatabase.close());

      final failingFiles = _FailFirstCandidateMove(dbFile.path);
      await expectLater(
        DatabaseRestoreService(
          databasePath: dbFile.path,
          lifecycle: lifecycle,
          keyStore: keyStore,
          cipher: cipher,
          files: failingFiles,
          inspector: const SqliteBackupDatabaseInspector(),
          supportedSchemaVersion: 1,
          recoveryDirectoryPath: p.join(tempRoot.path, 'recovery'),
        ).restore(backupPath, 'correct horse'),
        throwsA(isA<RestoreFailedException>()),
      );

      expect(keyStore.keyHex, keyB);
      expect(await holdingIds(lifecycle.currentDatabase), ['h2']);
    });
  });
}

/// Fails the first atomic move of the staged candidate onto the live
/// database path; internal `<dest>.tmp` renames are left alone.
final class _FailFirstCandidateMove extends IoBackupFileSystem {
  _FailFirstCandidateMove(this.targetPath);

  final String targetPath;
  var _failed = false;

  @override
  Future<void> moveAtomically(String source, String destination) {
    if (!_failed &&
        destination == targetPath &&
        !source.endsWith('.tmp')) {
      _failed = true;
      throw const FileSystemException('injected move failure');
    }
    return super.moveAtomically(source, destination);
  }
}
