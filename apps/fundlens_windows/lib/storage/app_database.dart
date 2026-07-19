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
}
