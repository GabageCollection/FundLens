import 'package:drift/native.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriftAppSettingsRepository', () {
    late AppDatabase db;
    late AppSettingsRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = DriftAppSettingsRepository(db);
    });

    tearDown(() => db.close());

    test('get returns null for a missing key', () async {
      expect(await repo.get('missing.key'), isNull);
    });

    test('round-trips a value through set/get', () async {
      await repo.set('market.autoRefreshEnabled', '1');
      expect(await repo.get('market.autoRefreshEnabled'), '1');
    });

    test('set overwrites an existing value', () async {
      await repo.set('snapshot.keepCount', '10');
      await repo.set('snapshot.keepCount', '20');
      expect(await repo.get('snapshot.keepCount'), '20');
      expect(await repo.getAll(), hasLength(1));
    });

    test('getAll returns all stored key/value pairs', () async {
      await repo.set('a', '1');
      await repo.set('b', '2');
      await repo.set('c', '3');
      final all = await repo.getAll();
      expect(all, {'a': '1', 'b': '2', 'c': '3'});
    });

    test('getAll is empty when nothing is stored', () async {
      expect(await repo.getAll(), isEmpty);
    });

    test('delete removes a key', () async {
      await repo.set('backup.lastPath', r'C:\tmp\backup');
      await repo.delete('backup.lastPath');
      expect(await repo.get('backup.lastPath'), isNull);
      expect(await repo.getAll(), isEmpty);
    });

    test('delete of a missing key is a no-op', () async {
      await repo.delete('never.set');
      expect(await repo.getAll(), isEmpty);
    });

    test('values survive a repository recreation on the same database',
        () async {
      await repo.set('market.refreshFrequency', 'weekly');
      final reopened = DriftAppSettingsRepository(db);
      expect(await reopened.get('market.refreshFrequency'), 'weekly');
    });
  });
}
