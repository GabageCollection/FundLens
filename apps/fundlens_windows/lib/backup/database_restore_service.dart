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
final class RestoreFailedException implements Exception {
  const RestoreFailedException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'RestoreFailedException: $message';
}

/// Facts a staged backup candidate exposes for the pre-restore confirmation.
final class RestoreSummary {
  const RestoreSummary({
    required this.createdAtUtc,
    required this.holdingCount,
    required this.snapshotCount,
    required this.schemaVersion,
  });

  /// When the backup was created (from the cleartext container header).
  final DateTime createdAtUtc;

  /// Holdings stored in the backup.
  final int holdingCount;

  /// Snapshots stored in the backup.
  final int snapshotCount;

  /// Database schema version the backup was created with.
  final int schemaVersion;
}

/// The result of [DatabaseRestoreService.prepareRestore]: a validated,
/// authenticated candidate staged in a private temporary directory, ready for
/// [DatabaseRestoreService.confirmRestore] or
/// [DatabaseRestoreService.cancelRestore]. Single-use.
///
/// The constructor is public so UI tests can hand the summary straight to the
/// confirmation dialog without driving a real [prepareRestore].
final class RestoreSession {
  RestoreSession({
    required this.tempDir,
    required this.candidatePath,
    required this.databaseKeyHex,
    required this.summary,
  });

  final String tempDir;
  final String candidatePath;
  final String databaseKeyHex;
  final RestoreSummary summary;
}

/// Result of inspecting a staged candidate database.
typedef BackupDatabaseInspection = ({
  int schemaVersion,
  int holdingCount,
  int snapshotCount,
});

/// Opens a staged candidate database and verifies it before it may replace
/// the live database.
abstract interface class BackupDatabaseInspector {
  /// Opens the database at [candidatePath] with [keyHex], runs
  /// `PRAGMA integrity_check` and returns the schema (`user_version`) version
  /// plus row counts. Throws [RestoreFailedException] when the file is
  /// unreadable or corrupt.
  Future<BackupDatabaseInspection> inspect(String candidatePath, String keyHex);
}

/// [BackupDatabaseInspector] backed by the bundled sqlite3mc runtime.
final class SqliteBackupDatabaseInspector implements BackupDatabaseInspector {
  const SqliteBackupDatabaseInspector();

  @override
  Future<BackupDatabaseInspection> inspect(
    String candidatePath,
    String keyHex,
  ) async {
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
      return (
        schemaVersion:
            database.select('PRAGMA user_version;').first.columnAt(0) as int,
        holdingCount: _countRows(database, 'holding'),
        snapshotCount: _countRows(database, 'snapshot'),
      );
    } on RestoreFailedException {
      rethrow;
    } on SqliteException catch (error) {
      throw RestoreFailedException('candidate database is unreadable', error);
    } finally {
      database.close();
    }
  }

  static int _countRows(Database database, String table) {
    try {
      return database.select('SELECT count(*) FROM "$table";').first.columnAt(0)
          as int;
    } on SqliteException {
      // A backup created by an earlier schema may lack the table.
      return 0;
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
///
/// Restoration is split into a `prepare`/`confirm` pair so the UI can validate
/// the file and password, show the [RestoreSummary] and only then replace the
/// live database. [restore] keeps the original one-shot contract as a thin
/// wrapper over the two steps.
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
    final session = await prepareRestore(source, password);
    await confirmRestore(session);
  }

  /// Validates the backup and stages a candidate without touching the live
  /// database. On success returns a [RestoreSession] holding the staged
  /// candidate and the summary for the confirmation dialog; the caller must
  /// resolve it with either [confirmRestore] or [cancelRestore].
  Future<RestoreSession> prepareRestore(String source, String password) async {
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
      final tempDir = await _files.createPrivateTempDirectory();
      final candidatePath = p.join(tempDir, 'candidate.db');
      await _files.writeAtomically(candidatePath, payload.databaseBytes);
      final inspection = await _inspector.inspect(
        candidatePath,
        payload.databaseKeyHex,
      );
      if (inspection.schemaVersion > _supportedSchemaVersion) {
        throw RestoreFailedException(
          'backup schema version ${inspection.schemaVersion} is newer than '
          'the supported version $_supportedSchemaVersion',
        );
      }
      return RestoreSession(
        tempDir: tempDir,
        candidatePath: candidatePath,
        databaseKeyHex: payload.databaseKeyHex,
        summary: RestoreSummary(
          createdAtUtc: readBackupHeader(backupBytes).createdAtUtc,
          holdingCount: inspection.holdingCount,
          snapshotCount: inspection.snapshotCount,
          schemaVersion: inspection.schemaVersion,
        ),
      );
    } finally {
      for (final buffer in sensitiveBuffers) {
        buffer.fillRange(0, buffer.length, 0);
      }
    }
  }

  /// Swaps the staged candidate into place under the lifecycle lock. On any
  /// failure after the close the previous database and key are rolled back.
  /// The session is consumed and its temporary directory cleaned up.
  Future<void> confirmRestore(RestoreSession session) async {
    try {
      // Steps 4-8: swap the database under the lifecycle lock.
      await _lifecycle.locked(() => _replaceDatabase(
            candidatePath: session.candidatePath,
            restoredKeyHex: session.databaseKeyHex,
          ));
    } finally {
      await _files.deleteDirectory(session.tempDir);
    }
  }

  /// Abandons a prepared session: cleans up the staged candidate without
  /// touching the live database.
  Future<void> cancelRestore(RestoreSession session) async {
    await _files.deleteDirectory(session.tempDir);
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
