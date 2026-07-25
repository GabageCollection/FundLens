import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../storage/app_database.dart';
import '../storage/database_key_store.dart';
import '../storage/database_opener.dart';
import 'backup_cipher.dart';
import 'backup_format.dart';

/// Thrown when a backup cannot be created. The live database is never closed
/// or modified by a failed backup.
final class BackupFailedException implements Exception {
  const BackupFailedException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'BackupFailedException: $message';
}

/// Exclusive access to the live database for backup and restore.
///
/// Backup and restore both run inside [locked] so they can never interleave
/// with each other. Closing and reopening is only valid inside the lock.
abstract interface class DatabaseLifecycle {
  /// Runs [body] while holding the database lifecycle lock.
  Future<T> locked<T>(Future<T> Function() body);

  /// Checkpoints and truncates the WAL of the live database so the database
  /// file alone is a complete copy.
  Future<void> checkpointWal();

  /// Closes the current database. Only valid inside [locked].
  Future<void> closeCurrentDatabase();

  /// Reopens the database with [keyHex] and runs a read query to prove the
  /// file on disk is usable with that key.
  Future<void> reopenDatabase(String keyHex);
}

/// [DatabaseLifecycle] over the app's [AppDatabase].
///
/// The lifecycle owns the current database instance: after [reopenDatabase],
/// [currentDatabase] points at the freshly opened database and earlier
/// instances are closed.
final class DriftDatabaseLifecycle implements DatabaseLifecycle {
  DriftDatabaseLifecycle({
    required this.databaseFile,
    required AppDatabase database,
    AppDatabase Function(QueryExecutor executor)? createDatabase,
  })  : _current = database,
        _createDatabase = createDatabase ?? AppDatabase.new;

  /// The database file the lifecycle reopens after a restore.
  final File databaseFile;
  final AppDatabase Function(QueryExecutor executor) _createDatabase;

  AppDatabase _current;

  /// Simple async mutex: bodies chained through [_tail] run sequentially.
  Future<void> _tail = Future.value();

  /// The live database. Changes after [reopenDatabase].
  AppDatabase get currentDatabase => _current;

  @override
  Future<T> locked<T>(Future<T> Function() body) {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return previous.then((_) => body()).whenComplete(gate.complete);
  }

  @override
  Future<void> checkpointWal() =>
      _current.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

  @override
  Future<void> closeCurrentDatabase() => _current.close();

  @override
  Future<void> reopenDatabase(String keyHex) async {
    final reopened =
        _createDatabase(openEncryptedDatabase(databaseFile, keyHex));
    // Prove the restored file is readable with this key before swapping.
    await reopened.customSelect('SELECT count(*) FROM sqlite_master').get();
    _current = reopened;
  }
}

/// File-system adapter used by backup and restore so tests can inject
/// failures such as a full disk or a failed atomic move.
abstract interface class BackupFileSystem {
  /// Creates a fresh private temporary directory and returns its path.
  Future<String> createPrivateTempDirectory();

  /// Creates the directory at [path], including parents, if missing.
  Future<void> createDirectory(String path);

  Future<Uint8List> readBytes(String path);

  Future<int> fileSize(String path);

  Future<bool> exists(String path);

  Future<void> copyFile(String source, String destination);

  /// Writes [bytes] to `$destination.tmp`, flushes and closes it, then
  /// renames it over [destination] so a crash never leaves a torn file at
  /// the destination path.
  Future<void> writeAtomically(String destination, List<int> bytes);

  /// Moves [source] over [destination], replacing any existing file.
  Future<void> moveAtomically(String source, String destination);

  /// Deletes [path] if it exists.
  Future<void> deleteFile(String path);

  /// Deletes the directory tree at [path] if it exists.
  Future<void> deleteDirectory(String path);
}

/// [BackupFileSystem] over `dart:io`.
///
/// Note: `dart:io` exposes neither fsync nor an atomic replace rename on
/// Windows, so durability relies on close-before-rename and replacement is a
/// delete-then-rename pair; callers keep recovery copies so a failure here
/// is always recoverable.
class IoBackupFileSystem implements BackupFileSystem {
  const IoBackupFileSystem();

  @override
  Future<String> createPrivateTempDirectory() async =>
      (await Directory.systemTemp.createTemp('fundlens-backup-')).path;

  @override
  Future<void> createDirectory(String path) =>
      Directory(path).create(recursive: true);

  @override
  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<int> fileSize(String path) => File(path).length();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> copyFile(String source, String destination) =>
      File(source).copy(destination);

  @override
  Future<void> writeAtomically(String destination, List<int> bytes) async {
    final tempPath = '$destination.tmp';
    final handle = await File(tempPath).open(mode: FileMode.write);
    try {
      await handle.writeFrom(bytes);
      await handle.flush();
    } finally {
      await handle.close();
    }
    await moveAtomically(tempPath, destination);
  }

  @override
  Future<void> moveAtomically(String source, String destination) async {
    final target = File(destination);
    if (await target.exists()) {
      await target.delete();
    }
    await File(source).rename(destination);
  }

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> deleteDirectory(String path) async {
    final directory = Directory(path);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

/// Creates encrypted FundLens backups of the live database.
class BackupService {
  BackupService({
    required this._databasePath,
    required this._lifecycle,
    required this._keyStore,
    required this._cipher,
    required this._files,
  });

  final String _databasePath;
  final DatabaseLifecycle _lifecycle;
  final DatabaseKeyStore _keyStore;
  final BackupCipher _cipher;
  final BackupFileSystem _files;

  /// Writes an encrypted backup of the current database to [destination].
  ///
  /// Acquires the lifecycle lock, checkpoints the WAL, copies the encrypted
  /// database to a private temporary file, builds a
  /// [FundLensBackupPayload] with the current database key and encrypts it
  /// with [password]. The container is written to `$destination.tmp` and
  /// atomically renamed over [destination]. Temporary material is deleted
  /// and in-memory key/database buffers are zeroed in `finally`.
  Future<void> create(String destination, String password) {
    return _lifecycle.locked(() async {
      String? tempDir;
      final sensitiveBuffers = <Uint8List>[];
      try {
        await _lifecycle.checkpointWal();
        tempDir = await _files.createPrivateTempDirectory();
        final stagedPath = p.join(tempDir, 'staged.db');
        await _files.copyFile(_databasePath, stagedPath);
        final databaseBytes = await _files.readBytes(stagedPath);
        sensitiveBuffers.add(databaseBytes);

        final keyHex = await _keyStore.readOrCreate();
        final payload = FundLensBackupPayload(
          databaseKeyHex: keyHex,
          databaseBytes: databaseBytes,
        ).encode();
        sensitiveBuffers.add(payload);

        final encrypted = await _cipher.encrypt(payload, password);
        await _files.writeAtomically(destination, encrypted);
      } on BackupFailedException {
        rethrow;
      } on Exception catch (error) {
        throw BackupFailedException('backup creation failed', error);
      } finally {
        for (final buffer in sensitiveBuffers) {
          buffer.fillRange(0, buffer.length, 0);
        }
        // A failed atomic write may have left its sidecar behind.
        await _files.deleteFile('$destination.tmp');
        final dir = tempDir;
        if (dir != null) {
          await _files.deleteDirectory(dir);
        }
      }
    });
  }
}
