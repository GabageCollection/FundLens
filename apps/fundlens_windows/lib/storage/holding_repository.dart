import 'package:drift/drift.dart';
import 'package:fundlens_core/fundlens_core.dart';

import 'app_database.dart';
import 'enum_mappers.dart';

abstract interface class HoldingRepository {
  Future<void> upsert(Holding holding);
  Future<void> replacePlatform(SourcePlatform platform, List<Holding> holdings);
  Future<void> deleteByIds(List<String> ids);
  Future<T> inTransaction<T>(Future<T> Function() action);
  Stream<List<Holding>> watchAll();
  Future<List<Holding>> getAll();
}

final class DriftHoldingRepository implements HoldingRepository {
  DriftHoldingRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> upsert(Holding holding) async {
    await _db.into(_db.holdingTable).insertOnConflictUpdate(
          _toCompanion(holding),
        );
  }

  @override
  Future<void> replacePlatform(
    SourcePlatform platform,
    List<Holding> holdings,
  ) async {
    await _db.transaction(() async {
      final deleteStatement = _db.delete(_db.holdingTable);
      deleteStatement.where(
        (row) => row.sourcePlatform.equals(sourcePlatformToWire(platform)),
      );
      await deleteStatement.go();
      for (final holding in holdings) {
        await _db.into(_db.holdingTable).insert(_toCompanion(holding));
      }
    });
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final deleteStatement = _db.delete(_db.holdingTable);
    deleteStatement.where((row) => row.id.isIn(ids));
    await deleteStatement.go();
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }

  @override
  Stream<List<Holding>> watchAll() {
    final query = _db.select(_db.holdingTable)
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map((rows) => rows.map(_toHolding).toList());
  }

  @override
  Future<List<Holding>> getAll() async {
    final query = _db.select(_db.holdingTable)
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    final rows = await query.get();
    return rows.map(_toHolding).toList();
  }

  HoldingTableCompanion _toCompanion(Holding holding) {
    return HoldingTableCompanion(
      id: Value(holding.id),
      sourcePlatform: Value(sourcePlatformToWire(holding.sourcePlatform)),
      instrumentType: Value(instrumentTypeToWire(holding.instrumentType)),
      assetClass: Value(assetClassToWire(holding.assetClass)),
      productName: Value(holding.productName),
      productCode: Value(holding.productCode),
      currency: Value(holding.currency),
      quantity: Value(decimalToNullableString(holding.quantity)),
      availableQuantity: Value(decimalToNullableString(holding.availableQuantity)),
      currentPrice: Value(decimalToNullableString(holding.currentPrice)),
      costPrice: Value(decimalToNullableString(holding.costPrice)),
      currentValue: Value(holding.currentValue.canonical),
      costAmount: Value(decimalToNullableString(holding.costAmount)),
      holdingProfit: Value(decimalToNullableString(holding.holdingProfit)),
      holdingReturn: Value(decimalToNullableString(holding.holdingReturn)),
      dailyProfit: Value(decimalToNullableString(holding.dailyProfit)),
      cumulativeProfit: Value(decimalToNullableString(holding.cumulativeProfit)),
      platformTags: Value(platformTagsToJson(holding.platformTags)),
      valuationMethod: Value(valuationMethodToWire(holding.valuationMethod)),
      valuationDate: Value(
        holding.valuationDate == null
            ? null
            : dateTimeToEpochMillis(holding.valuationDate!),
      ),
      dataOrigin: Value(dataOriginToWire(holding.dataOrigin)),
      fieldProvenance: Value(fieldProvenanceToJson(holding.fieldProvenance)),
      note: Value(holding.note),
      createdAt: Value(dateTimeToEpochMillis(holding.createdAt)),
      updatedAt: Value(dateTimeToEpochMillis(holding.updatedAt)),
    );
  }

  Holding _toHolding(HoldingTableData row) {
    return Holding(
      id: row.id,
      sourcePlatform: sourcePlatformFromWire(row.sourcePlatform),
      instrumentType: instrumentTypeFromWire(row.instrumentType),
      assetClass: assetClassFromWire(row.assetClass),
      productName: row.productName,
      productCode: row.productCode,
      currency: row.currency,
      quantity: decimalFromNullableString(row.quantity),
      availableQuantity: decimalFromNullableString(row.availableQuantity),
      currentPrice: decimalFromNullableString(row.currentPrice),
      costPrice: decimalFromNullableString(row.costPrice),
      currentValue: DecimalValue.parse(row.currentValue),
      costAmount: decimalFromNullableString(row.costAmount),
      holdingProfit: decimalFromNullableString(row.holdingProfit),
      holdingReturn: decimalFromNullableString(row.holdingReturn),
      dailyProfit: decimalFromNullableString(row.dailyProfit),
      cumulativeProfit: decimalFromNullableString(row.cumulativeProfit),
      platformTags: platformTagsFromJson(row.platformTags),
      valuationMethod: valuationMethodFromWire(row.valuationMethod),
      valuationDate: row.valuationDate == null
          ? null
          : dateTimeFromEpochMillis(row.valuationDate!),
      dataOrigin: dataOriginFromWire(row.dataOrigin),
      fieldProvenance: fieldProvenanceFromJson(row.fieldProvenance),
      note: row.note,
      createdAt: dateTimeFromEpochMillis(row.createdAt),
      updatedAt: dateTimeFromEpochMillis(row.updatedAt),
    );
  }
}
