import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../storage/database_key_store.dart';
import 'backup_cipher.dart';
import 'backup_format.dart';
import 'backup_service.dart';

/// Thrown when a restore cannot complete. Whenever the failure happened
/// after the live database was closed, the pre-restore database and key were
/// already rolled back before this exception surfaces.
class RestoreFailedException implements Exception {
  const RestoreFailedException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'RestoreFailedException: $message';
}

/// Opens a staged candidate database and verifies it before it may replace
/// the live database.
abstract interface class BackupDatabaseInspector {
  /// Opens the database at [candidatePath] with [keyHex], runs
  /// `PRAGMA integrity_check` and returns the schema (`user_version`)
  /// version. Throws [RestoreFailedException] when the file is unreadable or
  /// corrupt.
  Future<int> inspect(String candidatePath, String keyHex);
}

/// [BackupDatabaseInspector] backed by the bundled sqlite3mc runtime.
final class SqliteBackupDatabaseInspector implements BackupDatabaseInspector {
  const SqliteBackupDatabaseInspector();

  @override
  Future<int> inspect(String candidatePath, String keyHex) async {
    final Database database;
    try {
      database = sqlite3.open(candidatePath);
    } on SqliteException catch (error) {
      throw RestoreFailedException('candidate database cannot be opened', error);
    }
    try {
      database.execute("PRAGMA key = '${keyHex.replaceAll("'", "''")}';");
      // Touch the schema so a wrong key fails here.
      database.select('SELECT count(*) FROM sqlite_master;');
      final integrity = database.select('PRAGMA integrity_check;');
      if (integrity.length != 1 || integrity.first.columnAt(0) != 'ok') {
        throw const RestoreFailedException(
          'candidate database failed its integrity check',
        );
      }
      return database.select('PRAGMA user_version;').first.columnAt(0) as int;
    } on RestoreFailedException {
      rethrow;
    } on SqliteException catch (error) {
      throw RestoreFailedException('candidate database is unreadable', error);
    } finally {
      database.close();
    }
  }
}

/// Pre-restore state used for rollback. The previous database key is kept
/// only in memory here — it must never be written to the recovery directory,
/// only the Windows secure store may hold it.
final class _RecoveryRecord {
  _RecoveryRecord({
    required this.databaseBytes,
    required this.walBytes,
    required this.shmBytes,
    required this.previousKeyHex,
  });

  final Uint8List databaseBytes;
  final Uint8List? walBytes;
  final Uint8List? shmBytes;
  final String previousKeyHex;
}

/// Restores the live database from an encrypted FundLens backup.
class DatabaseRestoreService {
  DatabaseRestoreService({
    required this._databasePath,
    required this._lifecycle,
    required this._keyStore,
    required this._cipher,
    required this._files,
    required this._inspector,
    required this._supportedSchemaVersion,
    this._recoveryDirectoryPath = 'restore-recovery',
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String _databasePath;
  final DatabaseLifecycle _lifecycle;
  final DatabaseKeyStore _keyStore;
  final BackupCipher _cipher;
  final BackupFileSystem _files;
  final BackupDatabaseInspector _inspector;
  final int _supportedSchemaVersion;
  final String _recoveryDirectoryPath;
  final DateTime Function() _clock;

  /// Replaces the live database with the backup at [source].
  ///
  /// The backup is authenticated and validated before the live database is
  /// touched: size and container format, GCM authentication and payload
  /// digest (via [BackupCipher.decrypt]), payload structure, candidate
  /// integrity and schema version. Only then is the lifecycle lock taken,
  /// the current database closed, a recovery copy captured, the validated
  /// candidate moved into place and the database reopened with the payload
  /// key. Any failure after the close rolls the previous files and key back.
  Future<void> restore(String source, String password) async {
    String? tempDir;
    final sensitiveBuffers = <Uint8List>[];
    try {
      // Steps 1-2: read, size-check and authenticate the backup.
      final int size;
      try {
        size = await _files.fileSize(source);
      } on Exception catch (error) {
        throw RestoreFailedException('backup file cannot be read', error);
      }
      if (size > kMaxBackupBytes) {
        throw const BackupFormatException('backup container exceeds 100 MiB');
      }
      final backupBytes = await _files.readBytes(source);
      // Wrong passwords, tampering and digest mismatches all surface as
      // BackupAuthenticationException before anything else happens.
      final plaintext = await _cipher.decrypt(backupBytes, password);
      sensitiveBuffers.add(plaintext);

      // Step 3: parse the payload and validate the staged candidate.
      final payload = FundLensBackupPayload.decode(plaintext);
      sensitiveBuffers.add(payload.databaseBytes);
      tempDir = await _files.createPrivateTempDirectory();
      final candidatePath = p.join(tempDir, 'candidate.db');
      await _files.writeAtomically(candidatePath, payload.databaseBytes);
      final schemaVersion =
          await _inspector.inspect(candidatePath, payload.databaseKeyHex);
      if (schemaVersion > _supportedSchemaVersion) {
        throw RestoreFailedException(
          'backup schema version $schemaVersion is newer than the supported '
          'version $_supportedSchemaVersion',
        );
      }

      // Steps 4-8: swap the database under the lifecycle lock.
      await _lifecycle.locked(() => _replaceDatabase(
            candidatePath: candidatePath,
            restoredKeyHex: payload.databaseKeyHex,
          ));
    } finally {
      for (final buffer in sensitiveBuffers) {
        buffer.fillRange(0, buffer.length, 0);
      }
      final dir = tempDir;
      if (dir != null) {
        await _files.deleteDirectory(dir);
      }
    }
  }

  Future<void> _replaceDatabase({
    required String candidatePath,
    required String restoredKeyHex,
  }) async {
    var closed = false;
    _RecoveryRecord? recovery;
    final previousKeyHex = await _keyStore.readOrCreate();
    try {
      await _lifecycle.closeCurrentDatabase();
      closed = true;
      recovery = await _captureRecovery(previousKeyHex);
      await _files.moveAtomically(candidatePath, _databasePath);
      // Sidecars belong to the previous database; the staged candidate is a
      // complete checkpointed file.
      await _files.deleteFile('$_databasePath-wal');
      await _files.deleteFile('$_databasePath-shm');
      await _keyStore.write(restoredKeyHex);
      await _lifecycle.reopenDatabase(restoredKeyHex);
    } catch (error) {
      await _rollback(
        closed: closed,
        recovery: recovery,
        previousKeyHex: previousKeyHex,
      );
      throw RestoreFailedException(
        'restore failed; the previous database was recovered',
        error,
      );
    }
  }

  /// Copies the current database files into memory and into a timestamped
  /// recovery directory. The previous key stays in memory only.
  Future<_RecoveryRecord> _captureRecovery(String previousKeyHex) async {
    final walPath = '$_databasePath-wal';
    final shmPath = '$_databasePath-shm';
    final hasWal = await _files.exists(walPath);
    final hasShm = await _files.exists(shmPath);
    final record = _RecoveryRecord(
      databaseBytes: await _files.readBytes(_databasePath),
      walBytes: hasWal ? await _files.readBytes(walPath) : null,
      shmBytes: hasShm ? await _files.readBytes(shmPath) : null,
      previousKeyHex: previousKeyHex,
    );

    final stamp = _clock().toUtc().microsecondsSinceEpoch;
    final recoveryDir = p.join(_recoveryDirectoryPath, 'restore-$stamp');
    await _files.createDirectory(recoveryDir);
    await _files.copyFile(_databasePath, p.join(recoveryDir, 'fundlens.db'));
    if (hasWal) {
      await _files.copyFile(walPath, p.join(recoveryDir, 'fundlens.db-wal'));
    }
    if (hasShm) {
      await _files.copyFile(shmPath, p.join(recoveryDir, 'fundlens.db-shm'));
    }
    return record;
  }

  Future<void> _rollback({
    required bool closed,
    required _RecoveryRecord? recovery,
    required String previousKeyHex,
  }) async {
    if (!closed) return;
    final record = recovery;
    if (record != null) {
      await _files.writeAtomically(_databasePath, record.databaseBytes);
      final walBytes = record.walBytes;
      if (walBytes != null) {
        await _files.writeAtomically('$_databasePath-wal', walBytes);
      } else {
        await _files.deleteFile('$_databasePath-wal');
      }
      final shmBytes = record.shmBytes;
      if (shmBytes != null) {
        await _files.writeAtomically('$_databasePath-shm', shmBytes);
      } else {
        await _files.deleteFile('$_databasePath-shm');
      }
    }
    await _keyStore.write(previousKeyHex);
    await _lifecycle.reopenDatabase(previousKeyHex);
  }
}
