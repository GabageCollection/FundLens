import 'package:fundlens_core/fundlens_core.dart';

import '../../importing/import_models.dart';
import 'import_review_state.dart';

/// Builds the factual confirmation-screen summary from the current plan.
///
/// [duplicateCount] is supplied by the caller because duplicate detection
/// lives outside the plan (see [ImportDuplicateDetector]).
ImportCheckSummary buildImportCheckSummary({
  required ImportPlan plan,
  required List<Holding> current,
  required ImportDraft draft,
  required int duplicateCount,
}) {
  final zero = DecimalValue.parse('0');
  final insertValue = plan.inserts.fold(
    zero,
    (sum, h) => sum + h.currentValue,
  );
  final currentById = {for (final h in current) h.id: h};
  var updateDelta = zero;
  for (final update in plan.updates) {
    final old = currentById[update.id];
    final oldValue = old?.currentValue ?? zero;
    updateDelta = updateDelta + update.currentValue - oldValue;
  }
  var removedValue = zero;
  for (final id in plan.removeIds) {
    final removed = currentById[id];
    if (removed != null) removedValue = removedValue + removed.currentValue;
  }
  final totalChange = insertValue + updateDelta - removedValue;
  const abnormalCodes = {
    'import.invalid_amount',
    'import.invalid_sign',
    'import.missing_current_value',
    'ocr.unparseable_number',
    'import.ambiguous_code',
    'import.ambiguous_name',
  };
  final abnormalCount = [
    ...draft.issues,
    ...plan.issues,
  ].where((i) => abnormalCodes.contains(i.code)).length;
  final unclassifiedCount = draft.holdings
      .where((h) => h.assetClass == AssetClass.other)
      .length;
  return ImportCheckSummary(
    insertCount: plan.inserts.length,
    updateCount: plan.updates.length,
    duplicateCount: duplicateCount,
    abnormalCount: abnormalCount,
    unclassifiedCount: unclassifiedCount,
    totalValueChange: totalChange,
  );
}
