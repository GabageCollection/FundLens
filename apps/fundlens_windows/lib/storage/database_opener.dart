import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens an encrypted sqlite3mc database on a background isolate.
///
/// The [keyHex] string is used as the SQLCipher-compatible key. Before the
/// database is used, the opener verifies that an encrypted SQLite runtime is
/// active (either SQLCipher's `PRAGMA cipher` or sqlite3mc's
/// `PRAGMA sqlite3mc_version`), enables foreign keys, and enables WAL.
QueryExecutor openEncryptedDatabase(File file, String keyHex) {
  final escaped = keyHex.replaceAll("'", "''");
  return NativeDatabase.createInBackground(
    file,
    setup: (rawDb) {
      if (!_isEncryptedRuntimeActive(rawDb)) {
        throw StateError('Encrypted SQLite runtime is unavailable.');
      }
      rawDb.execute("PRAGMA key = '$escaped';");
      rawDb.execute('PRAGMA foreign_keys = ON;');
      rawDb.execute('PRAGMA journal_mode = WAL;');
      rawDb.select('SELECT count(*) FROM sqlite_master;');
    },
  );
}

bool _isEncryptedRuntimeActive(Database db) {
  if (_pragmaHasValue(db, 'cipher')) return true;
  if (_pragmaHasValue(db, 'sqlite3mc_version')) return true;
  return false;
}

bool _pragmaHasValue(Database db, String name) {
  try {
    final result = db.select('PRAGMA $name;');
    if (result.isEmpty) return false;
    for (final row in result) {
      for (final value in row.values) {
        if (value != null && value.toString().trim().isNotEmpty) {
          return true;
        }
      }
    }
    return false;
  } catch (_) {
    return false;
  }
}
