import 'package:drift/drift.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'enum_mappers.dart';

abstract interface class SnapshotRepository {
  Future<String> createFromCurrent({required String label});
  Future<PortfolioSnapshot> getById(String id);
  Future<List<PortfolioSnapshot>> getAll();
}

final class DriftSnapshotRepository implements SnapshotRepository {
  DriftSnapshotRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  @override
  Future<String> createFromCurrent({required String label}) async {
    final snapshotId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _db.into(_db.snapshotTable).insert(
            SnapshotTableCompanion(
              id: Value(snapshotId),
              label: Value(label),
              createdAt: Value(dateTimeToEpochMillis(now)),
            ),
          );

      final currentRows = await _db.select(_db.holdingTable).get();
      for (final row in currentRows) {
        await _db.into(_db.snapshotHoldingTable).insert(
              _snapshotHoldingCompanion(snapshotId, row),
            );
      }
    });

    return snapshotId;
  }

  @override
  Future<PortfolioSnapshot> getById(String id) async {
    final snapshotQuery = _db.select(_db.snapshotTable)
      ..where((row) => row.id.equals(id));
    final snapshot = await snapshotQuery.getSingle();

    final holdingsQuery = _db.select(_db.snapshotHoldingTable)
      ..where((row) => row.snapshotId.equals(id));
    final holdings = await holdingsQuery.get();

    return PortfolioSnapshot(
      id: snapshot.id,
      label: snapshot.label,
      createdAt: dateTimeFromEpochMillis(snapshot.createdAt),
      holdings: holdings.map(_toSnapshotHolding).toList(),
    );
  }

  @override
  Future<List<PortfolioSnapshot>> getAll() async {
    final snapshots = await _db.select(_db.snapshotTable).get();
    final result = <PortfolioSnapshot>[];
    for (final snapshot in snapshots) {
      final holdingsQuery = _db.select(_db.snapshotHoldingTable)
        ..where((row) => row.snapshotId.equals(snapshot.id));
      final holdings = await holdingsQuery.get();
      result.add(
        PortfolioSnapshot(
          id: snapshot.id,
          label: snapshot.label,
          createdAt: dateTimeFromEpochMillis(snapshot.createdAt),
          holdings: holdings.map(_toSnapshotHolding).toList(),
        ),
      );
    }
    return result;
  }

  SnapshotHoldingTableCompanion _snapshotHoldingCompanion(
    String snapshotId,
    HoldingTableData holding,
  ) {
    return SnapshotHoldingTableCompanion(
      snapshotId: Value(snapshotId),
      holdingId: Value(holding.id),
      sourcePlatform: Value(holding.sourcePlatform),
      instrumentType: Value(holding.instrumentType),
      assetClass: Value(holding.assetClass),
      productName: Value(holding.productName),
      productCode: Value(holding.productCode),
      currency: Value(holding.currency),
      quantity: Value(holding.quantity),
      currentPrice: Value(holding.currentPrice),
      currentValue: Value(holding.currentValue),
      costAmount: Value(holding.costAmount),
      holdingProfit: Value(holding.holdingProfit),
      dailyProfit: Value(holding.dailyProfit),
      cumulativeProfit: Value(holding.cumulativeProfit),
      valuationDate: Value(holding.valuationDate),
      fieldProvenance: Value(holding.fieldProvenance),
    );
  }

  SnapshotHolding _toSnapshotHolding(SnapshotHoldingTableData row) {
    return SnapshotHolding(
      holdingId: row.holdingId,
      productName: row.productName,
      productCode: row.productCode,
      instrumentType: instrumentTypeFromWire(row.instrumentType),
      assetClass: assetClassFromWire(row.assetClass),
      sourcePlatform: sourcePlatformFromWire(row.sourcePlatform),
      quantity: decimalFromNullableString(row.quantity),
      currentPrice: decimalFromNullableString(row.currentPrice),
      currentValue: DecimalValue.parse(row.currentValue),
      costAmount: decimalFromNullableString(row.costAmount),
      holdingProfit: decimalFromNullableString(row.holdingProfit),
      dailyProfit: decimalFromNullableString(row.dailyProfit),
      cumulativeProfit: decimalFromNullableString(row.cumulativeProfit),
      valuationDate: row.valuationDate == null
          ? null
          : dateTimeFromEpochMillis(row.valuationDate!),
      fieldProvenance: fieldProvenanceFromJson(row.fieldProvenance),
    );
  }
}
