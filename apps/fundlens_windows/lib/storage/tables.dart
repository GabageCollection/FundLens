import 'package:drift/drift.dart';

class HoldingTable extends Table {
  @override
  String get tableName => 'holding';

  TextColumn get id => text()();
  TextColumn get sourcePlatform => text()();
  TextColumn get instrumentType => text()();
  TextColumn get assetClass => text()();
  TextColumn get productName => text()();
  TextColumn get productCode => text().nullable()();
  TextColumn get currency => text()();
  TextColumn get quantity => text().nullable()();
  TextColumn get availableQuantity => text().nullable()();
  TextColumn get currentPrice => text().nullable()();
  TextColumn get costPrice => text().nullable()();
  TextColumn get currentValue => text()();
  TextColumn get costAmount => text().nullable()();
  TextColumn get holdingProfit => text().nullable()();
  TextColumn get holdingReturn => text().nullable()();
  TextColumn get dailyProfit => text().nullable()();
  TextColumn get cumulativeProfit => text().nullable()();
  TextColumn get platformTags => text().withDefault(const Constant('[]'))();
  TextColumn get valuationMethod => text()();
  IntColumn get valuationDate => integer().nullable()();
  TextColumn get dataOrigin => text()();
  TextColumn get fieldProvenance => text().withDefault(const Constant('{}'))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class SnapshotTable extends Table {
  @override
  String get tableName => 'snapshot';

  TextColumn get id => text()();
  TextColumn get label => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class SnapshotHoldingTable extends Table {
  @override
  String get tableName => 'snapshot_holding';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get snapshotId => text().references(
        SnapshotTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get holdingId => text()();
  TextColumn get sourcePlatform => text()();
  TextColumn get instrumentType => text()();
  TextColumn get assetClass => text()();
  TextColumn get productName => text()();
  TextColumn get productCode => text().nullable()();
  TextColumn get currency => text()();
  TextColumn get quantity => text().nullable()();
  TextColumn get currentPrice => text().nullable()();
  TextColumn get currentValue => text()();
  TextColumn get costAmount => text().nullable()();
  TextColumn get holdingProfit => text().nullable()();
  TextColumn get dailyProfit => text().nullable()();
  TextColumn get cumulativeProfit => text().nullable()();
  IntColumn get valuationDate => integer().nullable()();
  TextColumn get fieldProvenance => text().withDefault(const Constant('{}'))();
}

class ImportBatchTable extends Table {
  @override
  String get tableName => 'import_batch';

  TextColumn get id => text()();
  TextColumn get sourcePlatform => text()();
  IntColumn get importedAt => integer()();
  TextColumn get rawDataHash => text().nullable()();
  TextColumn get status => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class DraftHoldingTable extends Table {
  @override
  String get tableName => 'draft_holding';

  TextColumn get id => text()();
  TextColumn get importBatchId =>
      text().nullable().references(ImportBatchTable, #id)();
  TextColumn get rawJson => text()();
  TextColumn get status => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class DataIssueTable extends Table {
  @override
  String get tableName => 'data_issue';

  TextColumn get id => text()();
  TextColumn get holdingId =>
      text().nullable().references(HoldingTable, #id)();
  TextColumn get issueType => text()();
  TextColumn get description => text()();
  IntColumn get createdAt => integer()();
  IntColumn get resolvedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class QuoteCacheTable extends Table {
  @override
  String get tableName => 'quote_cache';

  TextColumn get productCode => text()();
  TextColumn get productName => text().nullable()();
  TextColumn get price => text().nullable()();
  IntColumn get fetchedAt => integer()();
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {productCode};
}

class ClassificationRuleTable extends Table {
  @override
  String get tableName => 'classification_rule';

  TextColumn get id => text()();
  TextColumn get pattern => text()();
  TextColumn get instrumentType => text().nullable()();
  TextColumn get assetClass => text().nullable()();
  IntColumn get priority => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettingTable extends Table {
  @override
  String get tableName => 'app_setting';

  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
