import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Holding _alipayHolding(String id, String currentValue) => Holding(
      id: id,
      sourcePlatform: SourcePlatform.alipay,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.fixedIncome,
      productName: '支付宝脱敏基金$id',
      currency: 'CNY',
      currentValue: DecimalValue.parse(currentValue),
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: DataOrigin.manual,
      fieldProvenance: const {},
      createdAt: DateTime.utc(2026, 7, 19),
      updatedAt: DateTime.utc(2026, 7, 19),
    );

Holding _manualHolding(String id, String currentValue) => Holding(
      id: id,
      sourcePlatform: SourcePlatform.manual,
      instrumentType: InstrumentType.stock,
      assetClass: AssetClass.equity,
      productName: '手动持仓$id',
      currency: 'CNY',
      currentValue: DecimalValue.parse(currentValue),
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: DataOrigin.manual,
      fieldProvenance: const {},
      createdAt: DateTime.utc(2026, 7, 19),
      updatedAt: DateTime.utc(2026, 7, 19),
    );

/// A [QueryExecutor] wrapper that throws on the Nth insert into a table named
/// in [tableNames]. This lets us prove that [DriftHoldingRepository.replacePlatform]
/// rolls back the surrounding transaction. Transaction executors are wrapped as
/// well so that failures inside [db.transaction] are still injected.
class _FailingOnInsertExecutor extends QueryExecutor {
  _FailingOnInsertExecutor(this._inner, this._tableNames, this._failureInsert);

  final QueryExecutor _inner;
  final Set<String> _tableNames;
  final int _failureInsert;
  var _insertCount = 0;
  var _failed = false;

  static bool _isInsertInto(String statement, String table) {
    final normalized = statement.trim().toLowerCase();
    if (!normalized.startsWith('insert into ')) return false;
    final remainder = normalized.substring('insert into '.length).trim();
    // Match table name with optional double quotes.
    return remainder.startsWith(table) ||
        remainder.startsWith('"$table"');
  }

  bool _shouldFail(String statement) {
    if (_failed) return false;
    if (!_tableNames.any((t) => _isInsertInto(statement, t))) return false;
    _insertCount++;
    if (_insertCount == _failureInsert) {
      _failed = true;
      return true;
    }
    return false;
  }

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  TransactionExecutor beginTransaction() =>
      _FailingOnInsertTransactionExecutor(_inner.beginTransaction(), this);

  @override
  QueryExecutor beginExclusive() =>
      _FailingOnInsertExecutor(_inner.beginExclusive(), _tableNames, _failureInsert);

  @override
  Future<void> close() => _inner.close();

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _inner.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _inner.runDelete(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    if (_shouldFail(statement)) {
      throw Exception('injected insert failure on $statement');
    }
    return _inner.runInsert(statement, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) =>
      _inner.runSelect(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _inner.runUpdate(statement, args);
}

class _FailingOnInsertTransactionExecutor extends TransactionExecutor {
  _FailingOnInsertTransactionExecutor(this._innerTx, this._parent);

  final TransactionExecutor _innerTx;
  final _FailingOnInsertExecutor _parent;

  @override
  SqlDialect get dialect => _innerTx.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _innerTx.ensureOpen(user);

  @override
  TransactionExecutor beginTransaction() =>
      _FailingOnInsertTransactionExecutor(_innerTx.beginTransaction(), _parent);

  @override
  QueryExecutor beginExclusive() =>
      _FailingOnInsertExecutor(_innerTx.beginExclusive(), _parent._tableNames, _parent._failureInsert);

  @override
  Future<void> close() => _innerTx.close();

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _innerTx.runBatched(statements);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _innerTx.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _innerTx.runDelete(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    if (_parent._shouldFail(statement)) {
      throw Exception('injected insert failure on $statement');
    }
    return _innerTx.runInsert(statement, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) =>
      _innerTx.runSelect(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _innerTx.runUpdate(statement, args);

  @override
  bool get supportsNestedTransactions => _innerTx.supportsNestedTransactions;

  @override
  Future<void> send() => _innerTx.send();

  @override
  Future<void> rollback() => _innerTx.rollback();
}

void main() {
  group('DriftHoldingRepository', () {
    test('round-trips all holding fields', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = DriftHoldingRepository(db);
      addTearDown(db.close);

      final holding = Holding(
        id: 'full',
        sourcePlatform: SourcePlatform.ths,
        instrumentType: InstrumentType.etf,
        assetClass: AssetClass.equity,
        productName: 'Full Holding',
        productCode: '000001',
        currency: 'CNY',
        quantity: DecimalValue.parse('100'),
        availableQuantity: DecimalValue.parse('90'),
        currentPrice: DecimalValue.parse('15.50'),
        costPrice: DecimalValue.parse('10.00'),
        currentValue: DecimalValue.parse('1550'),
        costAmount: DecimalValue.parse('1000'),
        holdingProfit: DecimalValue.parse('550'),
        holdingReturn: DecimalValue.parse('0.55'),
        dailyProfit: DecimalValue.parse('10'),
        cumulativeProfit: DecimalValue.parse('100'),
        platformTags: const ['tag1', 'tag2'],
        valuationMethod: ValuationMethod.quantityTimesPrice,
        valuationDate: DateTime.utc(2026, 7, 19),
        dataOrigin: DataOrigin.csv,
        fieldProvenance: const {
          'currentPrice': FieldProvenance(
            kind: ProvenanceKind.market,
            source: 'quote',
          ),
        },
        note: 'note',
        createdAt: DateTime.utc(2026, 7, 19, 10),
        updatedAt: DateTime.utc(2026, 7, 19, 11),
      );

      await repo.upsert(holding);
      final loaded = (await repo.getAll()).single;

      expect(loaded.id, holding.id);
      expect(loaded.sourcePlatform, holding.sourcePlatform);
      expect(loaded.instrumentType, holding.instrumentType);
      expect(loaded.assetClass, holding.assetClass);
      expect(loaded.productName, holding.productName);
      expect(loaded.productCode, holding.productCode);
      expect(loaded.currency, holding.currency);
      expect(loaded.quantity?.canonical, holding.quantity?.canonical);
      expect(loaded.availableQuantity?.canonical, holding.availableQuantity?.canonical);
      expect(loaded.currentPrice?.canonical, holding.currentPrice?.canonical);
      expect(loaded.costPrice?.canonical, holding.costPrice?.canonical);
      expect(loaded.currentValue.canonical, holding.currentValue.canonical);
      expect(loaded.costAmount?.canonical, holding.costAmount?.canonical);
      expect(loaded.holdingProfit?.canonical, holding.holdingProfit?.canonical);
      expect(loaded.holdingReturn?.canonical, holding.holdingReturn?.canonical);
      expect(loaded.dailyProfit?.canonical, holding.dailyProfit?.canonical);
      expect(loaded.cumulativeProfit?.canonical, holding.cumulativeProfit?.canonical);
      expect(loaded.platformTags, holding.platformTags);
      expect(loaded.valuationMethod, holding.valuationMethod);
      expect(loaded.valuationDate, holding.valuationDate);
      expect(loaded.dataOrigin, holding.dataOrigin);
      expect(loaded.fieldProvenance.keys, holding.fieldProvenance.keys);
      expect(
        loaded.fieldProvenance['currentPrice']?.kind,
        ProvenanceKind.market,
      );
      expect(loaded.fieldProvenance['currentPrice']?.source, 'quote');
      expect(loaded.note, holding.note);
      expect(loaded.createdAt, holding.createdAt);
      expect(loaded.updatedAt, holding.updatedAt);
    });

    test('replacePlatform is atomic and does not touch manual holdings',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = DriftHoldingRepository(db);
      addTearDown(db.close);

      await repo.upsert(_manualHolding('manual-1', '10000'));
      await repo.upsert(_alipayHolding('old-a1', '5000'));

      await repo.replacePlatform(
        SourcePlatform.alipay,
        [_alipayHolding('a1', '12000')],
      );

      final all = await repo.getAll();
      final ids = all.map((h) => h.id).toSet();
      expect(ids, contains('manual-1'));
      expect(ids, contains('a1'));
      expect(ids, isNot(contains('old-a1')));
      expect(
        all.firstWhere((h) => h.id == 'a1').currentValue.canonical,
        '12000',
      );
    });

    test('replacePlatform rolls back when an insert fails', () async {
      final inner = NativeDatabase.memory();
      final executor = _FailingOnInsertExecutor(inner, {'holding'}, 2);
      final db = AppDatabase.forTesting(executor);
      final repo = DriftHoldingRepository(db);
      addTearDown(db.close);

      await repo.upsert(_alipayHolding('original-a1', '8000'));

      await expectLater(
        repo.replacePlatform(
          SourcePlatform.alipay,
          [
            _alipayHolding('new-a1', '9000'),
            _alipayHolding('new-a2', '10000'),
          ],
        ),
        throwsA(anything),
      );

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.single.id, 'original-a1');
      expect(all.single.currentValue.canonical, '8000');
    });
  });

  group('DriftSnapshotRepository', () {
    test('snapshot rows remain unchanged after current holding update',
        () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final holdings = DriftHoldingRepository(db);
      final snapshots = DriftSnapshotRepository(db);
      addTearDown(db.close);

      const originalValue = '15000';
      await holdings.upsert(
        Holding(
          id: 'h1',
          sourcePlatform: SourcePlatform.alipay,
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: AssetClass.fixedIncome,
          productName: 'frozen-holding',
          currency: 'CNY',
          currentValue: DecimalValue.parse(originalValue),
          valuationMethod: ValuationMethod.manualAmount,
          dataOrigin: DataOrigin.manual,
          fieldProvenance: const {},
          createdAt: DateTime.utc(2026, 7, 19),
          updatedAt: DateTime.utc(2026, 7, 19),
        ),
      );

      final snapshotId = await snapshots.createFromCurrent(label: '2026-07-19');

      await holdings.upsert(
        Holding(
          id: 'h1',
          sourcePlatform: SourcePlatform.alipay,
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: AssetClass.fixedIncome,
          productName: 'frozen-holding',
          currency: 'CNY',
          currentValue: DecimalValue.parse('25000'),
          valuationMethod: ValuationMethod.manualAmount,
          dataOrigin: DataOrigin.manual,
          fieldProvenance: const {},
          createdAt: DateTime.utc(2026, 7, 19),
          updatedAt: DateTime.utc(2026, 7, 19),
        ),
      );

      final saved = await snapshots.getById(snapshotId);
      expect(saved.holdings.single.currentValue.canonical, originalValue);
    });
  });
}
