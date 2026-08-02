import 'package:fundlens_core/fundlens_core.dart';

import '../storage/holding_repository.dart';
import 'import_models.dart';

/// Everything needed to undo one committed import: the rows that were
/// inserted, the pre-commit values of every updated holding, the holdings
/// that were removed, and the rows the user chose to skip.
final class ImportCommitRecord {
  ImportCommitRecord({
    required this.insertedHoldings,
    required this.previousUpdates,
    required this.removedHoldings,
    required this.skipped,
    required this.committedAt,
  }) : inserted = insertedHoldings.length,
       updated = previousUpdates.length,
       removed = removedHoldings.length,
       skippedCount = skipped.length;

  final List<Holding> insertedHoldings;

  /// Updated holding id -> the value it had before this commit.
  final Map<String, Holding> previousUpdates;
  final List<Holding> removedHoldings;
  final List<DraftHolding> skipped;
  final DateTime committedAt;

  final int inserted;
  final int updated;
  final int removed;
  final int skippedCount;
}

/// Applies an [ImportPlan] to the repository atomically.
///
/// A plan with blocking issues is rejected; otherwise all updates, inserts
/// and removals run inside a single repository transaction, so an injected
/// mid-commit failure leaves current holdings unchanged. The returned
/// [ImportCommitRecord] captures pre-commit values so [undo] can restore
/// the exact prior state — also atomically.
final class ImportCommitService {
  ImportCommitService(
    this._repository, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HoldingRepository _repository;
  final DateTime Function() _clock;

  Future<ImportCommitRecord> commit(ImportPlan plan) async {
    if (!plan.canCommit) {
      throw StateError(
        'ImportPlan contains blocking issues and cannot be committed',
      );
    }
    final insertedHoldings = <Holding>[];
    final previousUpdates = <String, Holding>{};
    final removedHoldings = <Holding>[];
    await _repository.inTransaction(() async {
      for (final holding in plan.updates) {
        final existing = (await _repository.getAll())
            .where((h) => h.id == holding.id)
            .toList();
        if (existing.isNotEmpty) previousUpdates[holding.id] = existing.single;
        await _repository.upsert(holding);
      }
      for (final holding in plan.inserts) {
        insertedHoldings.add(holding);
        await _repository.upsert(holding);
      }
      final current = await _repository.getAll();
      for (final id in plan.removeIds) {
        final existing = current.where((h) => h.id == id).toList();
        if (existing.isNotEmpty) removedHoldings.add(existing.single);
      }
      await _repository.deleteByIds(plan.removeIds);
    });
    return ImportCommitRecord(
      insertedHoldings: insertedHoldings,
      previousUpdates: previousUpdates,
      removedHoldings: removedHoldings,
      skipped: plan.skipped,
      committedAt: _clock(),
    );
  }

  /// Reverses a committed import: deletes the inserted rows, restores the
  /// pre-commit values of updated holdings and re-inserts removed holdings,
  /// all inside one transaction.
  Future<void> undo(ImportCommitRecord record) async {
    await _repository.inTransaction(() async {
      if (record.insertedHoldings.isNotEmpty) {
        await _repository.deleteByIds(
          [for (final h in record.insertedHoldings) h.id],
        );
      }
      for (final holding in record.previousUpdates.values) {
        await _repository.upsert(holding);
      }
      for (final holding in record.removedHoldings) {
        await _repository.upsert(holding);
      }
    });
  }
}
