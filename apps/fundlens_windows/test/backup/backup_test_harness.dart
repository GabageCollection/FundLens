import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fundlens_windows/backup/backup_cipher.dart';
import 'package:fundlens_windows/backup/backup_format.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/storage/database_key_store.dart';

/// In-memory [BackupFileSystem] fake with failure injection. Paths are opaque
/// strings; sidecar files follow the SQLite `<path>-wal` / `<path>-shm`
/// naming used by the services under test.
final class InMemoryBackupFileSystem implements BackupFileSystem {
  final Map<String, Uint8List> files = {};
  final Set<String> directories = {};
  var _tempCounter = 0;

  /// When true, [writeAtomically] fails as if the disk were full.
  bool failWrites = false;

  /// When true, [moveAtomically] fails.
  bool failAtomicMove = false;

  void seed(String path, List<int> bytes) =>
      files[path] = Uint8List.fromList(bytes);

  Uint8List? bytesAt(String path) => files[path];

  static String _normalize(String path) => path.replaceAll('\\', '/');

  static bool _isInside(String path, String directory) =>
      _normalize(path).startsWith('${_normalize(directory)}/');

  /// Paths of all files that live under a created temporary directory.
  List<String> leftoverTempFiles() => files.keys
      .where((path) => directories.any((dir) => _isInside(path, dir)))
      .toList();

  @override
  Future<String> createPrivateTempDirectory() async {
    final path = '/temp/${_tempCounter++}';
    directories.add(path);
    return path;
  }

  @override
  Future<void> createDirectory(String path) async {}

  @override
  Future<Uint8List> readBytes(String path) async {
    final bytes = files[path];
    if (bytes == null) throw FileSystemException('file not found', path);
    return Uint8List.fromList(bytes);
  }

  @override
  Future<int> fileSize(String path) async {
    final bytes = files[path];
    if (bytes == null) throw FileSystemException('file not found', path);
    return bytes.length;
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<void> copyFile(String source, String destination) async {
    final bytes = files[source];
    if (bytes == null) throw FileSystemException('file not found', source);
    files[destination] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> writeAtomically(String destination, List<int> bytes) async {
    if (failWrites) {
      throw const FileSystemException('no space left on device');
    }
    final tempPath = '$destination.tmp';
    files[tempPath] = Uint8List.fromList(bytes);
    files[destination] = files.remove(tempPath)!;
  }

  @override
  Future<void> moveAtomically(String source, String destination) async {
    if (failAtomicMove) {
      throw const FileSystemException('atomic move failed');
    }
    final bytes = files[source];
    if (bytes == null) throw FileSystemException('file not found', source);
    files[destination] = bytes;
    files.remove(source);
  }

  @override
  Future<void> deleteFile(String path) async {
    files.remove(path);
  }

  @override
  Future<void> deleteDirectory(String path) async {
    files.removeWhere((key, _) => _isInside(key, path));
    directories.remove(path);
  }
}

/// Lifecycle fake that records lock/close/reopen activity.
final class FakeDatabaseLifecycle implements DatabaseLifecycle {
  int lockCount = 0;
  int closeCount = 0;
  int checkpointCount = 0;
  final List<String> reopenedWith = [];

  /// When set, [reopenDatabase] throws for this key.
  String? failReopenWithKey;

  var _locked = false;

  @override
  Future<T> locked<T>(Future<T> Function() body) async {
    if (_locked) throw StateError('lifecycle lock is not re-entrant');
    lockCount++;
    _locked = true;
    try {
      return await body();
    } finally {
      _locked = false;
    }
  }

  @override
  Future<void> checkpointWal() async {
    checkpointCount++;
  }

  @override
  Future<void> closeCurrentDatabase() async {
    closeCount++;
  }

  @override
  Future<void> reopenDatabase(String keyHex) async {
    if (keyHex == failReopenWithKey) {
      throw StateError('injected reopen failure');
    }
    reopenedWith.add(keyHex);
  }
}

/// Key-store fake backed by a mutable field.
final class InMemoryDatabaseKeyStore implements DatabaseKeyStore {
  InMemoryDatabaseKeyStore(this.keyHex);

  String keyHex;

  @override
  Future<String> readOrCreate() async => keyHex;

  @override
  Future<void> write(String keyHex) async {
    this.keyHex = keyHex;
  }
}

/// Inspector fake mapping staged database contents to a schema version and
/// row counts.
final class FakeBackupDatabaseInspector implements BackupDatabaseInspector {
  FakeBackupDatabaseInspector(this.files);

  final InMemoryBackupFileSystem files;

  /// Schema versions keyed by the latin-1 decoded candidate contents.
  final Map<String, int> versionsByContent = {};

  /// Holding counts keyed by candidate contents.
  final Map<String, int> holdingCountsByContent = {};

  /// Snapshot counts keyed by candidate contents.
  final Map<String, int> snapshotCountsByContent = {};

  /// When true, inspection fails as if the candidate were unreadable.
  bool failInspection = false;

  @override
  Future<BackupDatabaseInspection> inspect(
    String candidatePath,
    String keyHex,
  ) async {
    if (failInspection) {
      throw const RestoreFailedException('candidate database is unreadable');
    }
    final bytes = files.bytesAt(candidatePath);
    if (bytes == null) {
      throw StateError('candidate was not staged: $candidatePath');
    }
    final content = latin1.decode(bytes);
    return (
      schemaVersion: versionsByContent[content] ?? 1,
      holdingCount: holdingCountsByContent[content] ?? 0,
      snapshotCount: snapshotCountsByContent[content] ?? 0,
    );
  }
}

/// Builds an encrypted backup container with the real format helpers.
Future<Uint8List> buildBackup({
  required BackupCipher cipher,
  required String databaseKeyHex,
  required List<int> databaseBytes,
  required String password,
}) {
  final payload = FundLensBackupPayload(
    databaseKeyHex: databaseKeyHex,
    databaseBytes: Uint8List.fromList(databaseBytes),
  );
  return cipher.encrypt(payload.encode(), password);
}

/// Encodes synthetic database bytes for the in-memory fakes.
Uint8List syntheticDatabase(String marker) =>
    Uint8List.fromList(utf8.encode('synthetic-db:$marker'));
