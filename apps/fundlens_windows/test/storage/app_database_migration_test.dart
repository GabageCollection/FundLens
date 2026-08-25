import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/storage/app_database.dart';

MigrationStep _step(int from, int to, List<int> calls) => MigrationStep(
      from: from,
      to: to,
      migrate: (_) async => calls.add(to),
    );

void main() {
  group('AppDatabase migration framework', () {
    test('fresh database is created at the current schema version', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customSelect('SELECT count(*) FROM holding').getSingle();
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, db.schemaVersion);
    });

    test('migrationStepsFor selects applicable steps in version order', () {
      final calls = <int>[];
      final steps = [
        _step(2, 3, calls),
        _step(1, 2, calls),
        _step(3, 4, calls),
      ];

      final applicable = migrationStepsFor(steps, 1, 4);
      expect(applicable.map((s) => s.to), [2, 3, 4]);
      expect(calls, isEmpty, reason: 'selection alone must not execute steps');
    });

    test('migrationStepsFor skips steps outside the upgrade window', () {
      final calls = <int>[];
      final steps = [
        _step(1, 2, calls),
        _step(2, 3, calls),
        _step(3, 4, calls),
      ];

      expect(migrationStepsFor(steps, 2, 4).map((s) => s.from), [2, 3]);
      expect(migrationStepsFor(steps, 1, 2).map((s) => s.from), [1]);
      expect(migrationStepsFor(steps, 3, 4).map((s) => s.from), [3]);
      expect(migrationStepsFor(steps, 4, 5), isEmpty);
    });

    test('no steps registered: schemaVersion stays at 1', () async {
      // Guards against shipping a version bump without registering the
      // matching migration steps.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 1);
      expect(migrationSteps, isEmpty);
    });
  });
}
