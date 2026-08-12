import 'dart:convert';
import 'dart:io';

import 'package:fundlens_core/fundlens_core.dart';

import '../../importing/import_models.dart';
import '../../importing/tabular_import_parser.dart';

/// One OCR-recognized field of a draft row.
final class OcrFieldValue {
  const OcrFieldValue({
    required this.name,
    required this.rawText,
    required this.confidence,
    required this.pageIndex,
    required this.crop,
  });

  final String name;
  final String rawText;
  final double confidence;
  final int pageIndex;

  /// Crop rectangle `[x, y, width, height]` inside the source screenshot.
  final List<int> crop;

  Map<String, Object?> toJson() => {
    'name': name,
    'raw_text': rawText,
    'confidence': confidence,
    'page_index': pageIndex,
    'crop': crop,
  };

  factory OcrFieldValue.fromJson(Map<String, Object?> json) => OcrFieldValue(
    name: json['name'] as String? ?? '',
    rawText: json['raw_text'] as String? ?? '',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    pageIndex: (json['page_index'] as num?)?.toInt() ?? 0,
    crop: [
      for (final v in json['crop'] as List? ?? const []) (v as num).toInt(),
    ],
  );
}

/// One screenshot draft row as returned by `ocr.parse_screenshots`.
final class OcrRow {
  const OcrRow({
    required this.index,
    required this.pageIndex,
    required this.fields,
  });

  final int index;
  final int pageIndex;
  final Map<String, OcrFieldValue> fields;

  Map<String, Object?> toJson() => {
    'index': index,
    'page_index': pageIndex,
    'fields': {
      for (final entry in fields.entries) entry.key: entry.value.toJson(),
    },
  };

  factory OcrRow.fromJson(Map<String, Object?> json) => OcrRow(
    index: (json['index'] as num?)?.toInt() ?? 0,
    pageIndex: (json['page_index'] as num?)?.toInt() ?? 0,
    fields: {
      for (final entry in importAsMap(json['fields']).entries)
        entry.key: OcrFieldValue.fromJson(importAsMap(entry.value)),
    },
  );
}

/// Product candidate proposed by `product.match_candidates`. The engine
/// never selects; the user must pick one explicitly.
final class ProductCandidate {
  const ProductCandidate({
    required this.productCode,
    required this.name,
    required this.confidence,
    required this.reason,
  });

  final String productCode;
  final String name;
  final double confidence;
  final String reason;

  factory ProductCandidate.fromJson(Map<String, Object?> json) =>
      ProductCandidate(
        productCode: json['product_code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String? ?? '',
      );
}

/// Serializable form of an in-progress import, persisted so an
/// uncommitted draft survives an app restart.
final class PersistedImportDraft {
  const PersistedImportDraft({
    required this.mode,
    required this.holdings,
    required this.issues,
    this.template,
    this.source,
    this.table,
    this.mapping = const {},
    this.resolutions = const {},
    this.ocrRows = const [],
    this.tempScreenshotPaths = const [],
    this.mappingApplied = false,
  });

  final ImportMode mode;
  final String? template;
  final ImportSource? source;
  final TabularTable? table;
  final Map<String, int> mapping;

  /// True when the user already confirmed the column mapping and the draft
  /// reached the confirmation step. Restoring then resumes at the check step
  /// instead of re-showing the mapping panel.
  final bool mappingApplied;
  final Map<int, DuplicateResolution> resolutions;
  final List<DraftHolding> holdings;
  final List<DataIssue> issues;
  final List<OcrRow> ocrRows;
  final List<String> tempScreenshotPaths;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'template': template,
    'source': source?.name,
    'table': table == null
        ? null
        : {'headings': table!.headings, 'data_rows': table!.dataRows},
    'mapping': {for (final e in mapping.entries) e.key: e.value},
    'resolutions': {
      for (final e in resolutions.entries) '${e.key}': e.value.name,
    },
    'holdings': [for (final h in holdings) _holdingToJson(h)],
    'issues': [for (final i in issues) _issueToJson(i)],
    'ocr_rows': [for (final r in ocrRows) r.toJson()],
    'temp_screenshot_paths': tempScreenshotPaths,
    'mapping_applied': mappingApplied,
  };

  factory PersistedImportDraft.fromJson(Map<String, Object?> json) {
    final sourceRaw = json['source'] as String?;
    final tableRaw = importAsMap(json['table']);
    return PersistedImportDraft(
      mode: ImportMode.values.byName(json['mode'] as String? ?? 'partial'),
      template: json['template'] as String?,
      source: sourceRaw == null ? null : ImportSource.values.byName(sourceRaw),
      table: tableRaw.isEmpty
          ? null
          : TabularTable(
              headings: [
                for (final h in tableRaw['headings'] as List? ?? const [])
                  h.toString(),
              ],
              dataRows: [
                for (final row in tableRaw['data_rows'] as List? ?? const [])
                  [
                    for (final cell in row as List? ?? const [])
                      cell.toString(),
                  ],
              ],
            ),
      mapping: {
        for (final e in importAsMap(json['mapping']).entries)
          e.key: (e.value as num).toInt(),
      },
      resolutions: {
        for (final e in importAsMap(json['resolutions']).entries)
          int.parse(e.key): DuplicateResolution.values.byName(
            e.value as String,
          ),
      },
      holdings: [
        for (final h in json['holdings'] as List? ?? const [])
          _holdingFromJson(importAsMap(h)),
      ],
      issues: [
        for (final i in json['issues'] as List? ?? const [])
          importIssueFromJson(importAsMap(i)),
      ],
      ocrRows: [
        for (final r in json['ocr_rows'] as List? ?? const [])
          OcrRow.fromJson(importAsMap(r)),
      ],
      tempScreenshotPaths: [
        for (final path in json['temp_screenshot_paths'] as List? ?? const [])
          path.toString(),
      ],
      mappingApplied: json['mapping_applied'] as bool? ?? false,
    );
  }
}

/// Persistence for the in-progress import draft.
abstract interface class ImportDraftStore {
  Future<PersistedImportDraft?> load();
  Future<void> save(PersistedImportDraft draft);
  Future<void> clear();
}

/// JSON-file draft store. [clear] deletes only this draft file.
final class FileImportDraftStore implements ImportDraftStore {
  FileImportDraftStore(this._file);

  final File _file;

  @override
  Future<PersistedImportDraft?> load() async {
    if (!await _file.exists()) return null;
    final decoded = jsonDecode(await _file.readAsString());
    if (decoded is! Map) return null;
    return PersistedImportDraft.fromJson(importAsMap(decoded));
  }

  @override
  Future<void> save(PersistedImportDraft draft) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(draft.toJson()));
  }

  @override
  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}

/// Compact record of the most recent import, shown on the upload screen.
final class LastImportRecord {
  const LastImportRecord({
    required this.committedAt,
    required this.inserted,
    required this.updated,
    required this.removed,
    required this.skipped,
  });

  final DateTime committedAt;
  final int inserted;
  final int updated;
  final int removed;
  final int skipped;

  Map<String, Object?> toJson() => {
    'committed_at': committedAt.toIso8601String(),
    'inserted': inserted,
    'updated': updated,
    'removed': removed,
    'skipped': skipped,
  };

  factory LastImportRecord.fromJson(Map<String, Object?> json) =>
      LastImportRecord(
        committedAt: DateTime.parse(json['committed_at'] as String),
        inserted: (json['inserted'] as num?)?.toInt() ?? 0,
        updated: (json['updated'] as num?)?.toInt() ?? 0,
        removed: (json['removed'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
      );
}

/// Persistence for the most recent import record.
abstract interface class ImportRecordStore {
  Future<LastImportRecord?> load();
  Future<void> save(LastImportRecord record);
  Future<void> clear();
}

final class FileImportRecordStore implements ImportRecordStore {
  FileImportRecordStore(this._file);

  final File _file;

  @override
  Future<LastImportRecord?> load() async {
    if (!await _file.exists()) return null;
    final decoded = jsonDecode(await _file.readAsString());
    if (decoded is! Map) return null;
    return LastImportRecord.fromJson(importAsMap(decoded));
  }

  @override
  Future<void> save(LastImportRecord record) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() async {
    if (await _file.exists()) await _file.delete();
  }
}

/// 引擎 JSON 载荷/草稿持久化共用的宽容 Map 转换:非 Map 输入归一为空 Map。
Map<String, Object?> importAsMap(Object? value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v));
  }
  return <String, Object?>{};
}

Map<String, Object?> _holdingToJson(DraftHolding h) => {
  'source_platform': h.sourcePlatform.name,
  'product_name': h.productName,
  'product_code': h.productCode,
  'instrument_type': h.instrumentType.name,
  'asset_class': h.assetClass.name,
  'current_value': h.currentValue.canonical,
  'quantity': h.quantity?.canonical,
  'current_price': h.currentPrice?.canonical,
  'cost_price': h.costPrice?.canonical,
  'cost_amount': h.costAmount?.canonical,
  'holding_profit': h.holdingProfit?.canonical,
  'cumulative_profit': h.cumulativeProfit?.canonical,
  'currency': h.currency,
  'platform_tags': h.platformTags,
  'note': h.note,
  'data_origin': h.dataOrigin.name,
  'metadata': h.metadata,
};

DraftHolding _holdingFromJson(Map<String, Object?> json) {
  DecimalValue? decimal(String key) {
    final raw = json[key] as String?;
    return raw == null ? null : DecimalValue.parse(raw);
  }

  return DraftHolding(
    sourcePlatform: SourcePlatform.values.byName(
      json['source_platform'] as String,
    ),
    productName: json['product_name'] as String,
    productCode: json['product_code'] as String?,
    instrumentType: InstrumentType.values.byName(
      json['instrument_type'] as String,
    ),
    assetClass: AssetClass.values.byName(json['asset_class'] as String),
    currentValue: DecimalValue.parse(json['current_value'] as String),
    quantity: decimal('quantity'),
    currentPrice: decimal('current_price'),
    costPrice: decimal('cost_price'),
    costAmount: decimal('cost_amount'),
    holdingProfit: decimal('holding_profit'),
    cumulativeProfit: decimal('cumulative_profit'),
    currency: json['currency'] as String? ?? 'CNY',
    platformTags: [
      for (final tag in json['platform_tags'] as List? ?? const [])
        tag.toString(),
    ],
    note: json['note'] as String?,
    dataOrigin: DataOrigin.values.byName(json['data_origin'] as String),
    metadata: {
      for (final entry in importAsMap(json['metadata']).entries)
        entry.key: entry.value.toString(),
    },
  );
}

Map<String, Object?> _issueToJson(DataIssue issue) => {
  'code': issue.code,
  'field': issue.field,
  'severity': issue.severity.name,
  'message': issue.message,
  'holding_index': issue.holdingIndex,
};

DataIssue importIssueFromJson(Map<String, Object?> json) => DataIssue(
  code: json['code'] as String? ?? '',
  field: json['field'] as String? ?? '',
  severity: IssueSeverity.values.byName(
    json['severity'] as String? ?? 'warning',
  ),
  message: json['message'] as String? ?? '',
  holdingIndex: (json['holding_index'] as num?)?.toInt(),
);

/// 解析用户输入或 OCR 文本中的金额:容忍千分位、空格与 ¥/￥ 符号,
/// 无法解析时返回 null 而不是记 0。
DecimalValue? parseImportAmount(String raw) {
  var cleaned = raw
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .replaceAll('　', '')
      .replaceAll('¥', '')
      .replaceAll('￥', '')
      .trim();
  if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
  if (cleaned.isEmpty) return null;
  try {
    return DecimalValue.parse(cleaned);
  } on FormatException {
    return null;
  }
}
