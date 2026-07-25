import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/backup/backup_format.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/pointycastle_backup_cipher.dart';

import 'backup_test_harness.dart';

void main() {
  const databasePath = '/data/fundlens.db';
  const destination = '/backups/my backup$kFundLensBackupExtension';
  final currentKey = 'a' * 64;

  late InMemoryBackupFileSystem files;
  late FakeDatabaseLifecycle lifecycle;
  late InMemoryDatabaseKeyStore keyStore;
  late PointyCastleBackupCipher cipher;
  late BackupService service;

  setUp(() {
    files = InMemoryBackupFileSystem();
    lifecycle = FakeDatabaseLifecycle();
    keyStore = InMemoryDatabaseKeyStore(currentKey);
    cipher = PointyCastleBackupCipher();
    service = BackupService(
      databasePath: databasePath,
      lifecycle: lifecycle,
      keyStore: keyStore,
      cipher: cipher,
      files: files,
    );
    files.seed(databasePath, syntheticDatabase('current'));
  });

  group('BackupService.create', () {
    test('writes an encrypted backup of the checkpointed database', () async {
      await service.create(destination, 'backup password');

      final written = files.bytesAt(destination);
      expect(written, isNotNull);
      // The destination decrypts back to the current key and database bytes.
      final payload = FundLensBackupPayload.decode(
        await cipher.decrypt(written!, 'backup password'),
      );
      expect(payload.databaseKeyHex, currentKey);
      expect(payload.databaseBytes, syntheticDatabase('current'));

      // Lifecycle lock was held and the WAL checkpointed inside it.
      expect(lifecycle.lockCount, 1);
      expect(lifecycle.checkpointCount, 1);
      // No temporary material survives: neither the staging directory nor
      // the destination sidecar.
      expect(files.leftoverTempFiles(), isEmpty);
      expect(files.bytesAt('$destination.tmp'), isNull);
    });

    test('disk-full failure surfaces as BackupFailedException and leaves '
        'no destination or temp files', () async {
      files.failWrites = true;

      await expectLater(
        service.create(destination, 'backup password'),
        throwsA(isA<BackupFailedException>()),
      );
      expect(files.bytesAt(destination), isNull);
      expect(files.bytesAt('$destination.tmp'), isNull);
      expect(files.leftoverTempFiles(), isEmpty);
      // The live database was never closed for a backup.
      expect(lifecycle.closeCount, 0);
    });

    test('missing database file fails without writing the destination',
        () async {
      files.deleteFile(databasePath);

      await expectLater(
        service.create(destination, 'backup password'),
        throwsA(isA<BackupFailedException>()),
      );
      expect(files.bytesAt(destination), isNull);
    });
  });
}
