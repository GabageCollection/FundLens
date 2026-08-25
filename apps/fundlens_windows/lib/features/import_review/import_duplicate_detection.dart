import 'package:fundlens_core/fundlens_core.dart';

import '../../data_engine/data_engine_client.dart';
import '../../importing/import_models.dart';
import '../../importing/import_planner.dart';
import 'import_draft_persistence.dart';

/// Result of scanning a draft for possible cross-platform duplicates.
final class DuplicateDetectionResult {
  const DuplicateDetectionResult({
    required this.duplicateIndexes,
    required this.candidateGroups,
  });

  /// Draft-row indexes flagged as possible cross-platform duplicates.
  final Set<int> duplicateIndexes;

  /// Product candidates per flagged row; the user must select explicitly.
  final Map<int, List<ProductCandidate>> candidateGroups;
}

/// Flags draft rows whose normalized name matches a holding on another
/// platform as possible duplicates, and asks the engine for product
/// candidates. The engine proposes; the user must select explicitly.
/// An unavailable engine degrades to the duplicate note without candidates.
final class ImportDuplicateDetector {
  const ImportDuplicateDetector(this._engine);

  final DataEngineClient _engine;

  Future<DuplicateDetectionResult> detect(
    ImportDraft draft,
    List<Holding> current,
  ) async {
    final duplicates = <int>{};
    final groups = <int, List<ProductCandidate>>{};
    for (var i = 0; i < draft.holdings.length; i++) {
      final holding = draft.holdings[i];
      final normalized = ImportPlanner.normalizeProductName(
        holding.productName,
      );
      final sameName = current
          .where(
            (c) =>
                ImportPlanner.normalizeProductName(c.productName) ==
                    normalized &&
                c.sourcePlatform != holding.sourcePlatform,
          )
          .toList();
      if (sameName.isEmpty) continue;
      duplicates.add(i);
      try {
        final result = await _engine.call('product.match_candidates', {
          'query': holding.productName,
          'catalog': [
            for (final c in sameName)
              {
                'product_code': c.productCode ?? '',
                'name': c.productName,
                'product_type': c.instrumentType.name,
              },
          ],
        });
        final candidates = [
          for (final item in result['candidates'] as List? ?? const [])
            ProductCandidate.fromJson(importAsMap(item)),
        ];
        if (candidates.length > 1) groups[i] = candidates;
      } catch (_) {
        // Engine unavailable: keep the duplicate note without candidates.
      }
    }
    return DuplicateDetectionResult(
      duplicateIndexes: duplicates,
      candidateGroups: groups,
    );
  }
}
