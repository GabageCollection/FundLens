import 'package:drift/drift.dart';

import 'app_database.dart';

/// Key/value persistence for application settings.
///
/// Values are stored as strings; callers own serialization (booleans as
/// '0'/'1', enum names, ISO-8601 UTC timestamps, Decimal canonical strings).
/// Backed by the encrypted `app_setting` table so settings stay on-device.
abstract interface class AppSettingsRepository {
  Future<String?> get(String key);
  Future<Map<String, String>> getAll();
  Future<void> set(String key, String value);
  Future<void> delete(String key);
}

final class DriftAppSettingsRepository implements AppSettingsRepository {
  DriftAppSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<String?> get(String key) async {
    final query = _db.select(_db.appSettingTable)
      ..where((row) => row.key.equals(key));
    final row = await query.getSingleOrNull();
    return row?.value;
  }

  @override
  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.appSettingTable).get();
    return {for (final row in rows) row.key: row.value};
  }

  @override
  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettingTable).insertOnConflictUpdate(
          AppSettingTableCompanion(
            key: Value(key),
            value: Value(value),
            updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          ),
        );
  }

  @override
  Future<void> delete(String key) async {
    await (_db.delete(_db.appSettingTable)..where((row) => row.key.equals(key)))
        .go();
  }
}
