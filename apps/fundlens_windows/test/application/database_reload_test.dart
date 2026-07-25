import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/backup/pointycastle_backup_cipher.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/database_opener.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:path/path.dart' as p;

import '../backup/backup_test_harness.dart';

/// Proves the bootstrap provider wiring: after a real restore plus the
/// [databaseRevisionProvider] bump that [BackupSection] performs, the
/// repository providers serve the restored database instead of the closed
/// pre-restore one.
void main() {
  final keyA = 'a' * 64;
  final keyB = 'b' * 64;

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('fundlens-reload-');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  Holding holding(String id) => Holding(
        id: id,
        sourcePlatform: SourcePlatform.alipay,
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.fixedIncome,
        productName: '脱敏基金$id',
        currency: 'CNY',
        currentValue: DecimalValue.parse('1000'),
        valuationMethod: ValuationMethod.manualAmount,
        dataOrigin: DataOrigin.manual,
        fieldProvenance: const {},
        createdAt: DateTime.utc(2026, 7, 19),
        updatedAt: DateTime.utc(2026, 7, 19),
      );

  Future<AppDatabase> openDatabase(File file, String keyHex) async {
    final db = AppDatabase(openEncryptedDatabase(file, keyHex));
    await db.customSelect('SELECT count(*) FROM sqlite_master').get();
    return db;
  }

  Future<List<String>> holdingIds(HoldingRepository repository) async {
    final holdings = await repository.watchAll().first;
    return holdings.map((h) => h.id).toList();
  }

  test('repository providers serve restored data after restore and refresh',
      () async {
    final dbFile = File(p.join(tempRoot.path, 'fundlens.db'));
    final backupPath = p.join(tempRoot.path, 'copy.fundlens-backup');
    final cipher = PointyCastleBackupCipher();
    final keyStore = InMemoryDatabaseKeyStore(keyA);
    const files = IoBackupFileSystem();

    // Back up the key-A database holding h1.
    var db = await openDatabase(dbFile, keyA);
    await DriftHoldingRepository(db).upsert(holding('h1'));
    await BackupService(
      databasePath: dbFile.path,
      lifecycle: DriftDatabaseLifecycle(databaseFile: dbFile, database: db),
      keyStore: keyStore,
      cipher: cipher,
      files: files,
    ).create(backupPath, 'correct horse');
    await db.close();

    // Later state: key-B database holding h2, wired like the bootstrap.
    await dbFile.delete();
    db = await openDatabase(dbFile, keyB);
    await DriftHoldingRepository(db).upsert(holding('h2'));
    await keyStore.write(keyB);
    final lifecycle =
        DriftDatabaseLifecycle(databaseFile: dbFile, database: db);
    addTearDown(() => lifecycle.currentDatabase.close());

    final container = ProviderContainer(
      overrides: [databaseLifecycleProvider.overrideWithValue(lifecycle)],
    );
    addTearDown(container.dispose);

    expect(
      await holdingIds(container.read(holdingRepositoryProvider)),
      ['h2'],
    );

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

    // What BackupSection does after a successful restore.
    container.read(databaseRevisionProvider.notifier).state++;

    expect(
      await holdingIds(container.read(holdingRepositoryProvider)),
      ['h1'],
    );
  });
}
