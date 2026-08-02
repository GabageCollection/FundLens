import 'package:fundlens_core/fundlens_core.dart';

/// Import mode. Partial import is the default: it never removes holdings.
/// Full import may propose removals, but only within the same platform.
enum ImportMode { partial, full }

/// Data source chosen on the wizard's first step.
enum ImportSource {
  /// 支付宝导出文件/截图。
  alipay,

  /// 同花顺导出文件/截图。
  ths,

  /// 通用 CSV 文件。
  csv,

  /// 通用 Excel 文件。
  excel,

  /// 截图 OCR 识别。
  screenshot,
}

extension ImportSourceLabels on ImportSource {
  String get label => switch (this) {
        ImportSource.alipay => '支付宝',
        ImportSource.ths => '同花顺',
        ImportSource.csv => '通用 CSV',
        ImportSource.excel => '通用 Excel',
        ImportSource.screenshot => '截图识别',
      };
}

/// How a draft row that matches an existing holding should be written.
///
/// The user must choose explicitly before commit; there is no silent default
/// for rows flagged as possible duplicates.
enum DuplicateResolution {
  /// Sum amounts, shares and profits into the existing holding.
  merge,

  /// Replace the existing holding's values with the incoming row.
  overwrite,

  /// Keep the existing holding untouched and insert the incoming row as a
  /// new, separate holding.
  keepBoth,

  /// Skip the row entirely: it is neither inserted, updated nor removed.
  skip,
}

enum IssueSeverity { info, warning, blocking }

final class DataIssue {
  const DataIssue({
    required this.code,
    required this.field,
    required this.severity,
    required this.message,
    this.holdingIndex,
  });

  final String code;
  final String field;
  final IssueSeverity severity;
  final String message;

  /// Index of the draft holding the issue belongs to, when applicable.
  final int? holdingIndex;
}

/// A holding parsed from a tabular file, not yet matched against the
/// repository. All monetary values are [DecimalValue]; no `double` is used.
final class DraftHolding {
  const DraftHolding({
    required this.sourcePlatform,
    required this.productName,
    required this.instrumentType,
    required this.assetClass,
    required this.currentValue,
    required this.dataOrigin,
    this.productCode,
    this.quantity,
    this.currentPrice,
    this.costPrice,
    this.costAmount,
    this.holdingProfit,
    this.cumulativeProfit,
    this.currency = 'CNY',
    this.platformTags = const [],
    this.note,
    this.metadata = const {},
  });

  final SourcePlatform sourcePlatform;
  final String productName;
  final String? productCode;
  final InstrumentType instrumentType;
  final AssetClass assetClass;
  final DecimalValue currentValue;
  final DecimalValue? quantity;
  final DecimalValue? currentPrice;
  final DecimalValue? costPrice;
  final DecimalValue? costAmount;
  final DecimalValue? holdingProfit;
  final DecimalValue? cumulativeProfit;
  final String currency;
  final List<String> platformTags;
  final String? note;
  final DataOrigin dataOrigin;

  /// Unknown columns preserved verbatim (column heading -> raw text) so no
  /// user data is silently dropped during import.
  final Map<String, String> metadata;
}

final class ImportDraft {
  const ImportDraft({required this.holdings, required this.issues});

  final List<DraftHolding> holdings;
  final List<DataIssue> issues;

  bool get hasBlockingIssues =>
      issues.any((i) => i.severity == IssueSeverity.blocking);
}

final class ImportPlan {
  const ImportPlan({
    required this.inserts,
    required this.updates,
    required this.removeIds,
    required this.unchangedIds,
    required this.issues,
    this.skipped = const [],
  });

  final List<Holding> inserts;
  final List<Holding> updates;
  final List<String> removeIds;
  final List<String> unchangedIds;
  final List<DataIssue> issues;

  /// Draft rows the user chose to skip; never written to the repository.
  final List<DraftHolding> skipped;

  bool get canCommit =>
      issues.every((i) => i.severity != IssueSeverity.blocking);
}
