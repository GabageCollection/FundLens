import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    HoldingTable,
    SnapshotTable,
    SnapshotHoldingTable,
    ImportBatchTable,
    DraftHoldingTable,
    DataIssueTable,
    QuoteCacheTable,
    ClassificationRuleTable,
    AppSettingTable,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  /// Versioned migration entry point.
  ///
  /// `onCreate` runs on a brand-new database; `onUpgrade` runs
  /// `migrationSteps` one version at a time for existing files. Add new
  /// schema versions by bumping [schemaVersion] and appending one
  /// `MigrationStep` per version transition below — never edit shipped
  /// steps. Old backups stay readable because the restore path checks
  /// `PRAGMA user_version` before swapping files (see
  /// `DatabaseRestoreService`).
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          for (final step in migrationStepsFor(migrationSteps, from, to)) {
            await step.migrate(migrator);
          }
        },
      );
}

/// One schema transition, e.g. v1 -> v2. [from] is the version the step
/// upgrades *from*; [to] the version it upgrades *to*.
final class MigrationStep {
  const MigrationStep({
    required this.from,
    required this.to,
    required this.migrate,
  });

  final int from;
  final int to;
  final Future<void> Function(Migrator migrator) migrate;
}

/// Steps applicable when upgrading [from] -> [to], in version order.
///
/// A step applies when its whole [from, to] range fits inside the upgrade
/// window, so jumping several versions runs every intermediate step.
List<MigrationStep> migrationStepsFor(
  List<MigrationStep> steps,
  int from,
  int to,
) {
  final applicable =
      steps.where((s) => s.from >= from && s.to <= to).toList()
        ..sort((a, b) => a.from.compareTo(b.from));
  return List.unmodifiable(applicable);
}

/// Ordered schema transitions. Empty until schemaVersion advances past 1.
final List<MigrationStep> migrationSteps = <MigrationStep>[
  // Example for the first real transition:
  // MigrationStep(
  //   from: 1,
  //   to: 2,
  //   migrate: (m) async {
  //     await m.addColumn(holdingTable, holdingTable.newColumn);
  //   },
  // ),
];
