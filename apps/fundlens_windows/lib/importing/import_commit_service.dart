import '../storage/holding_repository.dart';
import 'import_models.dart';

/// Applies an [ImportPlan] to the repository atomically.
///
/// A plan with blocking issues is rejected; otherwise all updates, inserts
/// and removals run inside a single repository transaction, so an injected
/// mid-commit failure leaves current holdings unchanged.
final class ImportCommitService {
  ImportCommitService(this._repository);

  final HoldingRepository _repository;

  Future<void> commit(ImportPlan plan) async {
    if (!plan.canCommit) {
      throw StateError(
        'ImportPlan contains blocking issues and cannot be committed',
      );
    }
    await _repository.inTransaction(() async {
      for (final holding in plan.updates) {
        await _repository.upsert(holding);
      }
      for (final holding in plan.inserts) {
        await _repository.upsert(holding);
      }
      await _repository.deleteByIds(plan.removeIds);
    });
  }
}
