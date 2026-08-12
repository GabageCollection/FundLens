import 'package:fundlens_core/fundlens_core.dart';

import '../../importing/import_commit_service.dart';
import '../../importing/import_models.dart';
import '../../importing/tabular_import_parser.dart';

/// Review state machine for the four-step import wizard:
/// 1. choose a data source, 2. upload a file, 3. review the recognized rows
/// (field mapping for CSV/Excel, OCR review for screenshots),
/// 4. confirm the import.
sealed class ImportReviewState {
  const ImportReviewState();
}

/// Steps 1 & 2: the user is on the source-upload screen. [ImportReviewController.source]
/// distinguishes the chosen source; a null source means no choice yet.
final class ImportSourceSelect extends ImportReviewState {
  const ImportSourceSelect();
}

final class ImportParsing extends ImportReviewState {
  const ImportParsing(this.progress, {this.currentStep, this.totalSteps});
  final double? progress;

  /// 1-based step currently running, when parsing works through several
  /// inputs (one per screenshot); null for single-shot parsing.
  final int? currentStep;
  final int? totalSteps;
}

/// Step 3 (tabular): raw sheet + the guessed column mapping. The user may
/// correct the mapping and re-apply it before confirming.
final class ImportFieldMapping extends ImportReviewState {
  const ImportFieldMapping(this.table, this.mapping);
  final TabularTable table;
  final Map<String, int> mapping;
}

/// Step 3 (screenshots): OCR rows are shown with confidence and can be
/// edited, deleted and focused to their source crop.
final class ImportOcrReview extends ImportReviewState {
  const ImportOcrReview(this.draft, this.plan);
  final ImportDraft draft;
  final ImportPlan plan;
}

/// Step 4: confirm. Shows the check summary, requires resolutions for rows
/// flagged as possible duplicates, and offers snapshot creation.
final class ImportCheck extends ImportReviewState {
  const ImportCheck(this.draft, this.plan, this.summary);
  final ImportDraft draft;
  final ImportPlan plan;
  final ImportCheckSummary summary;
}

/// Factual counts shown on the confirmation screen before commit.
final class ImportCheckSummary {
  const ImportCheckSummary({
    required this.insertCount,
    required this.updateCount,
    required this.duplicateCount,
    required this.abnormalCount,
    required this.unclassifiedCount,
    required this.totalValueChange,
  });

  /// Rows that will be newly inserted.
  final int insertCount;

  /// Rows that will update an existing holding.
  final int updateCount;

  /// Rows flagged as possible duplicates awaiting an explicit resolution.
  final int duplicateCount;

  /// Rows carrying an amount/ambigity issue.
  final int abnormalCount;

  /// Rows whose asset class is not yet classified.
  final int unclassifiedCount;

  /// Expected total value change: inserts + update deltas − removals.
  final DecimalValue totalValueChange;
}

final class ImportCommitting extends ImportReviewState {
  const ImportCommitting();
}

final class ImportCommitted extends ImportReviewState {
  const ImportCommitted(this.report, this.record);
  final ImportCommitReport report;
  final ImportCommitRecord record;
}

final class ImportFailed extends ImportReviewState {
  const ImportFailed(this.message, this.retryable, {this.retry});
  final String message;
  final bool retryable;

  /// 失败后重新执行同一操作;为 null 时失败页只提供"返回来源"。
  final Future<void> Function()? retry;
}

/// Factual summary of a committed import.
final class ImportCommitReport {
  const ImportCommitReport({
    required this.inserted,
    required this.updated,
    required this.removed,
    required this.skipped,
    this.createdSnapshot = false,
    this.completenessBefore,
    this.completenessAfter,
  });

  final int inserted;
  final int updated;
  final int removed;
  final int skipped;

  /// Whether a portfolio snapshot was created right after this commit.
  final bool createdSnapshot;

  /// Data-completeness ratio before and after the commit, when a
  /// [DataQualityCalculator] was available; null means "not evaluated".
  final DecimalValue? completenessBefore;
  final DecimalValue? completenessAfter;

  /// Failed rows never reach the report: a blocking issue prevents commit and
  /// a mid-commit failure rolls back atomically, so failures are always zero
  /// here. Kept as a named field so the results screen can render a 0.
  int get failed => 0;
}
