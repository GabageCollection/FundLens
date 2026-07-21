import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/importing/import_commit_service.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';

Holding _holding(String id, SourcePlatform platform, String value) => Holding(
      id: id,
      sourcePlatform: platform,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.fixedIncome,
      productName: '脱敏基金$id',
      currency: 'CNY',
      currentValue: DecimalValue.parse(value),
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: DataOrigin.csv,
      fieldProvenance: const {},
      createdAt: DateTime.utc(2026, 7, 19),
      updatedAt: DateTime.utc(2026, 7, 21),
    );

/// Fails the [failureInsert]-th INSERT into the holding table so the commit
/// test can prove the surrounding transaction rolls back.
class _FailOnNthInsertExecutor extends QueryExecutor {
  _FailOnNthInsertExecutor(this._inner, this._failureInsert);

  final QueryExecutor _inner;
  final int _failureInsert;
  var _insertCount = 0;
  var _failed = false;

  bool _shouldFail(String statement) {
    if (_failed) return false;
    final normalized = statement.trim().toLowerCase();
    if (!normalized.startsWith('insert into')) return false;
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
      _FailOnNthInsertTransactionExecutor(_inner.beginTransaction(), this);
  @override
  QueryExecutor beginExclusive() =>
      _FailOnNthInsertExecutor(_inner.beginExclusive(), _failureInsert);
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
      throw Exception('injected insert failure');
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

class _FailOnNthInsertTransactionExecutor extends TransactionExecutor {
  _FailOnNthInsertTransactionExecutor(this._innerTx, this._parent);

  final TransactionExecutor _innerTx;
  final _FailOnNthInsertExecutor _parent;

  @override
  SqlDialect get dialect => _innerTx.dialect;
  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _innerTx.ensureOpen(user);
  @override
  TransactionExecutor beginTransaction() =>
      _FailOnNthInsertTransactionExecutor(_innerTx.beginTransaction(), _parent);
  @override
  QueryExecutor beginExclusive() => _FailOnNthInsertExecutor(
        _innerTx.beginExclusive(),
        _parent._failureInsert,
      );
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
      throw Exception('injected insert failure');
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
  group('ImportCommitService', () {
    test('rejects a plan with blocking issues', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHoldingRepository(db);
      final service = ImportCommitService(repo);

      const plan = ImportPlan(
        inserts: [],
        updates: [],
        removeIds: [],
        unchangedIds: [],
        issues: [
          DataIssue(
            code: 'import.ambiguous_name',
            field: 'productName',
            severity: IssueSeverity.blocking,
            message: 'ambiguous',
          ),
        ],
      );

      expect(plan.canCommit, isFalse);
      await expectLater(service.commit(plan), throwsStateError);
      expect(await repo.getAll(), isEmpty);
    });

    test('commits inserts, updates and removals in one transaction', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftHoldingRepository(db);
      final service = ImportCommitService(repo);

      await repo.upsert(_holding('keep-manual', SourcePlatform.manual, '100'));
      await repo.upsert(_holding('remove-me', SourcePlatform.alipay, '200'));
      await repo.upsert(_holding('update-me', SourcePlatform.alipay, '300'));

      final plan = ImportPlan(
        inserts: [_holding('new-1', SourcePlatform.alipay, '900')],
        updates: [_holding('update-me', SourcePlatform.alipay, '999')],
        removeIds: const ['remove-me'],
        unchangedIds: const ['keep-manual'],
        issues: const [],
      );

      await service.commit(plan);

      final all = {for (final h in await repo.getAll()) h.id: h};
      expect(all.keys, containsAll(['keep-manual', 'update-me', 'new-1']));
      expect(all.keys, isNot(contains('remove-me')));
      expect(all['update-me']!.currentValue.canonical, '999');
      expect(all['new-1']!.currentValue.canonical, '900');
    });

    test('injected mid-commit failure leaves holdings unchanged', () async {
      final executor = _FailOnNthInsertExecutor(NativeDatabase.memory(), 2);
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);
      final repo = DriftHoldingRepository(db);
      final service = ImportCommitService(repo);

      await repo.upsert(_holding('original', SourcePlatform.alipay, '8000'));

      final plan = ImportPlan(
        inserts: [
          _holding('new-1', SourcePlatform.alipay, '9000'),
          _holding('new-2', SourcePlatform.alipay, '10000'),
        ],
        updates: const [],
        removeIds: const ['original'],
        unchangedIds: const [],
        issues: const [],
      );

      await expectLater(service.commit(plan), throwsA(anything));

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.single.id, 'original');
      expect(all.single.currentValue.canonical, '8000');
    });
  });
}
