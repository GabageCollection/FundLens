import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:path/path.dart' as p;

import '../../application/app_dependencies.dart';
import '../../data_engine/data_engine_client.dart';
import '../../importing/import_commit_service.dart';
import '../../importing/import_models.dart';
import '../../importing/import_planner.dart';
import '../../importing/tabular_import_parser.dart';
import '../../security/selected_path_guard.dart';
import '../../storage/holding_repository.dart';
import '../../storage/snapshot_repository.dart';

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

/// A file picked by the user. The original at [path] is only ever read;
/// it is never modified or deleted.
final class PickedImportFile {
  const PickedImportFile({required this.name, required this.path, this.bytes});

  final String name;
  final String path;
  final Uint8List? bytes;
}

/// File picker abstraction so tests never touch the OS dialog.
abstract interface class ImportFilePicker {
  Future<PickedImportFile?> pickCsvFile();
  Future<PickedImportFile?> pickExcelFile();

  /// CSV or Excel — used by platform sources (支付宝/同花顺) whose exports
  /// may be either format.
  Future<PickedImportFile?> pickTabularFile();
  Future<List<PickedImportFile>> pickScreenshotFiles();
}

/// Stores temporary copies of selected screenshots. Copies — never the
/// originals — are deleted after a successful commit or explicit discard.
abstract interface class ScreenshotTempStore {
  Future<List<String>> copyToTemp(List<String> sourcePaths);
  Future<void> clear(List<String> tempPaths);
}

/// File-based temp store: copies screenshots into [_directory]; [clear]
/// deletes only the copies inside that directory.
final class FileScreenshotTempStore implements ScreenshotTempStore {
  FileScreenshotTempStore(this._directory);

  final Directory _directory;

  @override
  Future<List<String>> copyToTemp(List<String> sourcePaths) async {
    await _directory.create(recursive: true);
    final tempPaths = <String>[];
    for (var i = 0; i < sourcePaths.length; i++) {
      final source = File(sourcePaths[i]);
      final destination = p.join(
        _directory.path,
        'import_${DateTime.now().microsecondsSinceEpoch}_$i'
        '${p.extension(sourcePaths[i])}',
      );
      await source.copy(destination);
      tempPaths.add(destination);
    }
    return tempPaths;
  }

  @override
  Future<void> clear(List<String> tempPaths) async {
    for (final tempPath in tempPaths) {
      if (!p.isWithin(_directory.path, tempPath)) continue;
      final file = File(tempPath);
      if (await file.exists()) await file.delete();
    }
  }
}

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
      for (final entry in _asMap(json['fields']).entries)
        entry.key: OcrFieldValue.fromJson(_asMap(entry.value)),
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
    final tableRaw = _asMap(json['table']);
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
        for (final e in _asMap(json['mapping']).entries)
          e.key: (e.value as num).toInt(),
      },
      resolutions: {
        for (final e in _asMap(json['resolutions']).entries)
          int.parse(e.key): DuplicateResolution.values.byName(
            e.value as String,
          ),
      },
      holdings: [
        for (final h in json['holdings'] as List? ?? const [])
          _holdingFromJson(_asMap(h)),
      ],
      issues: [
        for (final i in json['issues'] as List? ?? const [])
          _issueFromJson(_asMap(i)),
      ],
      ocrRows: [
        for (final r in json['ocr_rows'] as List? ?? const [])
          OcrRow.fromJson(_asMap(r)),
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
    return PersistedImportDraft.fromJson(_asMap(decoded));
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
    return LastImportRecord.fromJson(_asMap(decoded));
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

Map<String, Object?> _asMap(Object? value) {
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
      for (final entry in _asMap(json['metadata']).entries)
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

DataIssue _issueFromJson(Map<String, Object?> json) => DataIssue(
  code: json['code'] as String? ?? '',
  field: json['field'] as String? ?? '',
  severity: IssueSeverity.values.byName(
    json['severity'] as String? ?? 'warning',
  ),
  message: json['message'] as String? ?? '',
  holdingIndex: (json['holding_index'] as num?)?.toInt(),
);

DecimalValue? _parseAmount(String raw) {
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

final dataEngineClientProvider = Provider<DataEngineClient>((ref) {
  throw UnimplementedError(
    'dataEngineClientProvider must be overridden by the bootstrap.',
  );
});

final importFilePickerProvider = Provider<ImportFilePicker>((ref) {
  throw UnimplementedError(
    'importFilePickerProvider must be overridden by the bootstrap.',
  );
});

final screenshotTempStoreProvider = Provider<ScreenshotTempStore>((ref) {
  throw UnimplementedError(
    'screenshotTempStoreProvider must be overridden by the bootstrap.',
  );
});

final importDraftStoreProvider = Provider<ImportDraftStore>((ref) {
  throw UnimplementedError(
    'importDraftStoreProvider must be overridden by the bootstrap.',
  );
});

final importRecordStoreProvider = Provider<ImportRecordStore>((ref) {
  throw UnimplementedError(
    'importRecordStoreProvider must be overridden by the bootstrap.',
  );
});

final importReviewControllerProvider =
    ChangeNotifierProvider<ImportReviewController>((ref) {
      return ImportReviewController(
        engine: ref.watch(dataEngineClientProvider),
        repository: ref.watch(holdingRepositoryProvider),
        picker: ref.watch(importFilePickerProvider),
        tempStore: ref.watch(screenshotTempStoreProvider),
        draftStore: ref.watch(importDraftStoreProvider),
        snapshotRepository: ref.watch(snapshotRepositoryProvider),
        recordStore: ref.watch(importRecordStoreProvider),
        dataQuality: ref.watch(dataQualityCalculatorProvider),
        freshQuoteIds: () => ref.read(freshQuoteHoldingIdsProvider),
      );
    });

/// Drives the four-step import wizard. Partial import is the default mode
/// and never removes holdings; full mode proposes removals that require an
/// explicit second confirmation. Temporary screenshot copies are cleared
/// only after a successful commit, an undo, or an explicit discard; the
/// user's original files are never deleted.
final class ImportReviewController extends ChangeNotifier {
  ImportReviewController({
    required this._engine,
    required HoldingRepository repository,
    required this._picker,
    required this._tempStore,
    required this._draftStore,
    required this._snapshotRepository,
    required this._recordStore,
    this._parser = const TabularImportParser(),
    this._dataQuality,
    this._freshQuoteIds,
    ImportPlanner? planner,
    ImportCommitService? commitService,
  }) : _repository = repository,
       _planner = planner ?? ImportPlanner(),
       _commitService = commitService ?? ImportCommitService(repository);

  final DataEngineClient _engine;
  final HoldingRepository _repository;
  final ImportFilePicker _picker;
  final ScreenshotTempStore _tempStore;
  final ImportDraftStore _draftStore;
  final TabularImportParser _parser;
  final ImportPlanner _planner;
  final ImportCommitService _commitService;
  final SnapshotRepository _snapshotRepository;
  final ImportRecordStore _recordStore;
  final DataQualityCalculator? _dataQuality;
  final Set<String> Function()? _freshQuoteIds;

  ImportReviewState _state = const ImportSourceSelect();
  ImportReviewState get state => _state;

  ImportMode _mode = ImportMode.partial;
  ImportMode get mode => _mode;

  ImportSource? _source;
  ImportSource? get source => _source;

  /// OCR template hint for screenshot imports (`alipay` or `ths`).
  String get templateHint => _templateHint;
  String _templateHint = 'alipay';

  set templateHint(String value) {
    if (value == _templateHint) return;
    _templateHint = value;
    notifyListeners();
  }

  String? _template;
  String? get template => _template;

  List<OcrRow> _ocrRows = const [];
  List<OcrRow> get ocrRows => _ocrRows;

  List<String> _tempScreenshotPaths = const [];
  List<String> get tempScreenshotPaths => _tempScreenshotPaths;

  ImportDraft? _draft;
  ImportPlan? _plan;

  TabularTable? _table;
  Map<String, int> _mapping = const {};

  String? _focusedField;
  int? _focusedHoldingIndex;
  String? get focusedField => _focusedField;
  int? get focusedHoldingIndex => _focusedHoldingIndex;

  Set<int> _duplicateIndexes = const {};
  int get duplicateCount => _duplicateIndexes.length;

  /// Draft-row indexes flagged as possible cross-platform duplicates.
  Set<int> get duplicateIndexes => Set.unmodifiable(_duplicateIndexes);

  Map<int, List<ProductCandidate>> _candidateGroups = const {};
  Map<int, List<ProductCandidate>> get candidateGroups => _candidateGroups;

  final Map<int, ProductCandidate> _candidateSelections = {};
  Map<int, ProductCandidate> get candidateSelections =>
      Map.unmodifiable(_candidateSelections);

  final Map<int, DuplicateResolution> _resolutions = {};
  Map<int, DuplicateResolution> get resolutions =>
      Map.unmodifiable(_resolutions);

  ImportCommitRecord? _commitRecord;
  LastImportRecord? _lastRecord;
  LastImportRecord? get lastRecord => _lastRecord;

  bool _restored = false;

  /// The OCR field currently focused, if any, used to show its source crop.
  OcrFieldValue? get focusedOcrField {
    final field = _focusedField;
    final index = _focusedHoldingIndex;
    if (field == null) return null;
    for (final row in _ocrRows) {
      if (index != null && row.index != index) continue;
      final value = row.fields[field];
      if (value != null) return value;
    }
    return null;
  }

  bool get _hasUnresolvedCandidates =>
      _candidateGroups.keys.any((i) => !_candidateSelections.containsKey(i));

  bool get canCommit {
    final draft = _draft;
    final plan = _plan;
    return _state is ImportCheck &&
        draft != null &&
        plan != null &&
        !draft.hasBlockingIssues &&
        plan.canCommit &&
        !_hasUnresolvedCandidates;
  }

  void _setState(ImportReviewState next) {
    _state = next;
    notifyListeners();
  }

  /// Wizard step index (1-based) for the step indicator, or null on the
  /// terminal result state.
  int? get wizardStep => switch (_state) {
    ImportSourceSelect() => source == null ? 1 : 2,
    ImportParsing() => 2,
    ImportFieldMapping() || ImportOcrReview() => 3,
    ImportCheck() => 4,
    ImportCommitting() || ImportCommitted() || ImportFailed() => null,
  };

  /// Step 1: the user picks a data source. Resets any in-progress review.
  Future<void> selectSource(ImportSource source) async {
    _source = source;
    _template = null;
    _templateHint = switch (source) {
      ImportSource.ths => 'ths',
      ImportSource.screenshot => 'alipay',
      _ => 'alipay',
    };
    await _resetReview();
    _setState(const ImportSourceSelect());
  }

  /// Step 2: opens the OS file picker for the chosen source.
  Future<void> pickFile() async {
    final source = _source;
    if (source == null) return;
    PickedImportFile? file;
    switch (source) {
      case ImportSource.csv:
        file = await _picker.pickCsvFile();
      case ImportSource.excel:
        file = await _picker.pickExcelFile();
      case ImportSource.alipay:
      case ImportSource.ths:
        file = await _picker.pickTabularFile();
      case ImportSource.screenshot:
        return;
    }
    if (file == null) return;
    await _acceptFile(file);
  }

  /// Step 2 (drop zone): accepts a file dropped onto the upload area.
  Future<void> acceptDroppedFile(PickedImportFile file) async {
    final source = _source ?? _sourceFromFileName(file.name);
    _source = source;
    await _acceptFile(file);
  }

  ImportSource? _sourceFromFileName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.csv')) return ImportSource.csv;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return ImportSource.excel;
    }
    return ImportSource.screenshot;
  }

  Future<void> _acceptFile(PickedImportFile file) async {
    final source = _source;
    if (source == null) return;
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.csv') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls')) {
      await _parseTabular(file);
      return;
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp')) {
      await acceptDroppedScreenshots([file]);
      return;
    }
    _setState(ImportFailed('不支持的文件类型: ${file.name}', true));
  }

  /// Step 2 (drop zone): runs OCR directly on screenshots dropped onto the
  /// upload area, without opening the OS picker.
  Future<void> acceptDroppedScreenshots(List<PickedImportFile> files) async {
    if (files.isEmpty) return;
    _source = _source ?? ImportSource.screenshot;
    var tempPaths = const <String>[];
    try {
      _setState(const ImportParsing(null));
      tempPaths = await _tempStore.copyToTemp([
        for (final f in files) f.path,
      ]);
      await _runOcr(tempPaths);
    } catch (e) {
      _setState(
        ImportFailed(
          '截图识别失败: $e',
          true,
          retry: () => _retryOcr(tempPaths),
        ),
      );
    }
  }

  /// 对同一批截图重新识别;失败再次提供重试入口。
  Future<void> _retryOcr(List<String> tempPaths) async {
    try {
      _setState(const ImportParsing(null));
      await _runOcr(tempPaths);
    } catch (e) {
      _setState(
        ImportFailed(
          '截图识别失败: $e',
          true,
          retry: () => _retryOcr(tempPaths),
        ),
      );
    }
  }

  Future<void> _parseTabular(PickedImportFile file) async {
    _setState(const ImportParsing(null));
    try {
      final bytes = file.bytes ?? await File(file.path).readAsBytes();
      final lower = file.name.toLowerCase();
      final isExcel = lower.endsWith('.xlsx') || lower.endsWith('.xls');
      final fallback = _fallbackPlatform(_source);
      final table = isExcel
          ? _parser.parseExcelTable(bytes)
          : _parser.parseCsvTable(
              _decodeUtf8(bytes),
              fallbackPlatform: fallback,
            );
      final mapping = _parser.guessColumnMapping(table.headings);
      _table = table;
      _mapping = mapping;
      await _persistTable(table, mapping);
      _setState(ImportFieldMapping(table, mapping));
    } catch (e) {
      _setState(
        ImportFailed(
          '文件解析失败: $e',
          true,
          retry: () => _parseTabular(file),
        ),
      );
    }
  }

  SourcePlatform _fallbackPlatform(ImportSource? source) => switch (source) {
    ImportSource.alipay => SourcePlatform.alipay,
    ImportSource.ths => SourcePlatform.ths,
    _ => SourcePlatform.manual,
  };

  static String _decodeUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return String.fromCharCodes(bytes);
    }
  }

  /// Step 2 (screenshots): opens the picker and runs OCR on each selected
  /// screenshot, showing real per-screenshot progress.
  Future<void> pickScreenshots() async {
    var tempPaths = const <String>[];
    try {
      final files = await _picker.pickScreenshotFiles();
      if (files.isEmpty) return;
      _setState(const ImportParsing(null));
      tempPaths = await _tempStore.copyToTemp([
        for (final f in files) f.path,
      ]);
      await _runOcr(tempPaths);
    } catch (e) {
      _setState(
        ImportFailed(
          '截图识别失败: $e',
          true,
          retry: () => _retryOcr(tempPaths),
        ),
      );
    }
  }

  Future<void> _runOcr(List<String> tempPaths) async {
    final template = _templateHint;
    final canonicalPaths = const SelectedPathGuard().canonicalizeAll(tempPaths);
    // Recognize one screenshot per engine call: a single slow page can no
    // longer stall the whole batch behind one timeout, and the UI can show
    // real progress. The engine keeps its OCR models loaded between calls,
    // so only the first call pays the model-loading cost — a generous
    // per-call timeout covers that cold start in the frozen bundle.
    final mergedRows = <Object?>[];
    final mergedIssues = <Object?>[];
    for (var i = 0; i < canonicalPaths.length; i++) {
      _setState(
        ImportParsing(
          i / canonicalPaths.length,
          currentStep: i + 1,
          totalSteps: canonicalPaths.length,
        ),
      );
      final response = await _engine.call('ocr.parse_screenshots', {
        'paths': [canonicalPaths[i]],
        'template': template,
      }, timeout: const Duration(minutes: 3));
      for (final rawRow in response['rows'] as List? ?? const []) {
        final row = _asMap(rawRow);
        row['page_index'] = i;
        mergedRows.add(row);
      }
      mergedIssues.addAll(response['issues'] as List? ?? const []);
    }
    _tempScreenshotPaths = tempPaths;
    final draft = _draftFromOcr({
      'rows': mergedRows,
      'issues': mergedIssues,
    }, template);
    await _enterReview(draft, template: template);
  }

  /// Step 3 (mapping): the user updates the column mapping.
  Future<void> setMapping(Map<String, int> mapping) async {
    final state = _state;
    if (state is! ImportFieldMapping) return;
    _mapping = mapping;
    await _persistTable(state.table, mapping);
    _setState(ImportFieldMapping(state.table, mapping));
  }

  /// Step 3 → 4 (mapping): builds the draft from the confirmed mapping and
  /// moves to the confirmation screen.
  Future<void> applyMapping() async {
    final state = _state;
    if (state is! ImportFieldMapping) return;
    final draft = _parser.parseTable(
      state.table,
      state.mapping,
      origin: _isExcel(state.table, _source)
          ? DataOrigin.excel
          : DataOrigin.csv,
      fallbackPlatform: _fallbackPlatform(_source),
    );
    await _enterCheck(draft);
  }

  bool _isExcel(TabularTable table, ImportSource? source) =>
      source == ImportSource.excel;

  /// Removes an OCR row; the draft is rebuilt without it.
  Future<void> removeOcrRow(int index) async {
    if (index < 0 || index >= _ocrRows.length) return;
    final rows = [..._ocrRows]..removeAt(index);
    _ocrRows = rows;
    final draft = _draft;
    if (draft != null && index < draft.holdings.length) {
      final holdings = [...draft.holdings]..removeAt(index);
      final issues = draft.issues
          .where((i) => i.holdingIndex != index)
          .map(
            (i) => DataIssue(
              code: i.code,
              field: i.field,
              severity: i.severity,
              message: i.message,
              holdingIndex: i.holdingIndex != null && i.holdingIndex! > index
                  ? i.holdingIndex! - 1
                  : i.holdingIndex,
            ),
          )
          .toList();
      await _enterReview(
        ImportDraft(holdings: holdings, issues: issues),
        template: _template,
      );
    }
  }

  /// Step 3 → 4 (screenshots): move from OCR review to confirmation.
  Future<void> confirmOcrReview() async {
    final draft = _draft;
    if (draft == null) return;
    await _enterCheck(draft);
  }

  Future<void> _enterReview(ImportDraft draft, {String? template}) async {
    _draft = draft;
    _template = template;
    _focusedField = null;
    _focusedHoldingIndex = null;
    await _replan();
    await _persist();
    _setState(ImportOcrReview(_draft!, _plan!));
  }

  Future<void> _enterCheck(ImportDraft draft) async {
    _draft = draft;
    _focusedField = null;
    _focusedHoldingIndex = null;
    await _replan();
    await _persist();
    final current = await _repository.getAll();
    final summary = _buildSummary(_plan!, current, draft);
    _setState(ImportCheck(draft, _plan!, summary));
  }

  Future<void> _resetReview() async {
    final tempPaths = _tempScreenshotPaths;
    _tempScreenshotPaths = const [];
    await _tempStore.clear(tempPaths);
    _draft = null;
    _plan = null;
    _table = null;
    _mapping = const {};
    _ocrRows = const [];
    _focusedField = null;
    _focusedHoldingIndex = null;
    _duplicateIndexes = const {};
    _candidateGroups = const {};
    _candidateSelections.clear();
    _resolutions.clear();
    _commitRecord = null;
  }

  Future<void> _replan() async {
    final draft = _draft;
    if (draft == null) return;
    final current = await _repository.getAll();
    final platform = draft.holdings.isEmpty
        ? (_source == ImportSource.ths
              ? SourcePlatform.ths
              : _source == ImportSource.alipay
              ? SourcePlatform.alipay
              : SourcePlatform.manual)
        : draft.holdings.first.sourcePlatform;
    _plan = _planner.plan(
      mode: _mode,
      platform: platform,
      current: current,
      incoming: draft.holdings,
      resolutions: _resolutions,
    );
    await _refreshDuplicates(draft, current);
  }

  /// Flags draft rows whose normalized name matches a holding on another
  /// platform as possible duplicates, and asks the engine for product
  /// candidates. The engine proposes; the user must select explicitly.
  Future<void> _refreshDuplicates(
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
            ProductCandidate.fromJson(_asMap(item)),
        ];
        if (candidates.length > 1) groups[i] = candidates;
      } catch (_) {
        // Engine unavailable: keep the duplicate note without candidates.
      }
    }
    _duplicateIndexes = duplicates;
    _candidateGroups = groups;
    _candidateSelections.removeWhere((i, _) => !groups.containsKey(i));
  }

  /// The user chooses how a possible-duplicate row should be written.
  Future<void> setResolution(
    int holdingIndex,
    DuplicateResolution resolution,
  ) async {
    if (holdingIndex < 0 || holdingIndex >= (_draft?.holdings.length ?? 0)) {
      return;
    }
    _resolutions[holdingIndex] = resolution;
    await _replan();
    await _persist();
    final draft = _draft!;
    final current = await _repository.getAll();
    _setState(
      ImportCheck(draft, _plan!, _buildSummary(_plan!, current, draft)),
    );
  }

  ImportCheckSummary _buildSummary(
    ImportPlan plan,
    List<Holding> current,
    ImportDraft draft,
  ) {
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
      duplicateCount: _duplicateIndexes.length,
      abnormalCount: abnormalCount,
      unclassifiedCount: unclassifiedCount,
      totalValueChange: totalChange,
    );
  }

  Future<void> _persistTable(
    TabularTable table,
    Map<String, int> mapping,
  ) async {
    await _draftStore.save(
      PersistedImportDraft(
        mode: _mode,
        template: _template,
        source: _source,
        table: table,
        mapping: mapping,
        holdings: _draft?.holdings ?? const [],
        issues: _draft?.issues ?? const [],
        ocrRows: _ocrRows,
        tempScreenshotPaths: _tempScreenshotPaths,
        mappingApplied: false,
      ),
    );
  }

  Future<void> _persist() async {
    final draft = _draft;
    if (draft == null) return;
    await _draftStore.save(
      PersistedImportDraft(
        mode: _mode,
        template: _template,
        source: _source,
        table: _table,
        mapping: _mapping,
        resolutions: _resolutions,
        holdings: draft.holdings,
        issues: draft.issues,
        ocrRows: _ocrRows,
        tempScreenshotPaths: _tempScreenshotPaths,
        // A persisted draft with a raw table only exists after the mapping
        // was confirmed; resume at the check step, not the mapping panel.
        mappingApplied: _table != null,
      ),
    );
  }

  /// Restores an uncommitted draft left over from a previous run.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    _lastRecord = await _recordStore.load();
    final saved = await _draftStore.load();
    if (saved == null) {
      notifyListeners();
      return;
    }
    _source = saved.source;
    _ocrRows = saved.ocrRows;
    _tempScreenshotPaths = saved.tempScreenshotPaths;
    _resolutions
      ..clear()
      ..addAll(saved.resolutions);
    _setState(const ImportParsing(null));
    try {
      if (saved.ocrRows.isNotEmpty) {
        await _enterReview(
          ImportDraft(holdings: saved.holdings, issues: saved.issues),
          template: saved.template,
        );
      } else if (saved.table != null && !saved.mappingApplied) {
        _setState(ImportFieldMapping(saved.table!, saved.mapping));
      } else {
        await _enterCheck(
          ImportDraft(holdings: saved.holdings, issues: saved.issues),
        );
      }
    } catch (e) {
      _setState(ImportFailed('草稿恢复失败: $e', true));
    }
  }

  Future<void> setMode(ImportMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    final draft = _draft;
    if (draft == null) return;
    await _replan();
    await _persist();
    if (_state is ImportCheck) {
      final current = await _repository.getAll();
      _setState(
        ImportCheck(draft, _plan!, _buildSummary(_plan!, current, draft)),
      );
    } else if (_state is ImportOcrReview) {
      _setState(ImportOcrReview(draft, _plan!));
    }
  }

  void focusField(String field, int? holdingIndex) {
    _focusedField = field;
    _focusedHoldingIndex = holdingIndex;
    final state = _state;
    // 从确认步点击数据问题 → 回到截图复核步并聚焦对应字段裁剪区。
    if (state is ImportCheck && _ocrRows.isNotEmpty && _draft != null) {
      _setState(ImportOcrReview(_draft!, _plan!));
    } else {
      notifyListeners();
    }
  }

  void focusIssue(DataIssue issue) {
    focusField(issue.field, issue.holdingIndex);
  }

  void selectCandidate(int holdingIndex, ProductCandidate candidate) {
    _candidateSelections[holdingIndex] = candidate;
    notifyListeners();
  }

  static const _amountFields = {
    'current_value',
    'holding_profit',
    'cumulative_profit',
    'cost_price',
    'quantity',
    'currentValue',
    'holdingProfit',
    'cumulativeProfit',
    'costPrice',
  };

  /// Applies a user edit to a draft field. A valid value clears the
  /// issues recorded for that field; an invalid amount adds a blocking
  /// issue, which disables commit until corrected.
  Future<void> updateHoldingField(
    int holdingIndex,
    String field,
    String text,
  ) async {
    final draft = _draft;
    if (draft == null || holdingIndex >= draft.holdings.length) return;
    final holding = draft.holdings[holdingIndex];

    DecimalValue? amount;
    if (_amountFields.contains(field)) {
      amount = _parseAmount(text);
      if (amount == null) {
        _replaceIssues(draft, holdingIndex, field, [
          DataIssue(
            code: 'import.invalid_amount',
            field: field,
            severity: IssueSeverity.blocking,
            message: '金额无法解析: $text',
            holdingIndex: holdingIndex,
          ),
        ]);
        notifyListeners();
        return;
      }
    }

    final updated = DraftHolding(
      sourcePlatform: holding.sourcePlatform,
      productName: field == 'product_name' || field == 'productName'
          ? text
          : holding.productName,
      productCode: holding.productCode,
      instrumentType: holding.instrumentType,
      assetClass: holding.assetClass,
      currentValue: field == 'current_value' || field == 'currentValue'
          ? amount!
          : holding.currentValue,
      quantity: field == 'quantity' ? amount : holding.quantity,
      currentPrice: holding.currentPrice,
      costPrice: field == 'cost_price' || field == 'costPrice'
          ? amount
          : holding.costPrice,
      costAmount: holding.costAmount,
      holdingProfit: field == 'holding_profit' || field == 'holdingProfit'
          ? amount
          : holding.holdingProfit,
      cumulativeProfit:
          field == 'cumulative_profit' || field == 'cumulativeProfit'
          ? amount
          : holding.cumulativeProfit,
      currency: holding.currency,
      platformTags: holding.platformTags,
      note: holding.note,
      dataOrigin: holding.dataOrigin,
      metadata: holding.metadata,
    );

    _replaceIssues(draft, holdingIndex, field, const []);
    _draft = ImportDraft(
      holdings: [
        for (var i = 0; i < draft.holdings.length; i++)
          i == holdingIndex ? updated : draft.holdings[i],
      ],
      issues: draft.issues,
    );
    await _replan();
    await _persist();
    if (_state is ImportCheck) {
      final current = await _repository.getAll();
      _setState(
        ImportCheck(_draft!, _plan!, _buildSummary(_plan!, current, _draft!)),
      );
    } else if (_state is ImportOcrReview) {
      _setState(ImportOcrReview(_draft!, _plan!));
    }
  }

  void _replaceIssues(
    ImportDraft draft,
    int holdingIndex,
    String field,
    List<DataIssue> replacement,
  ) {
    draft.issues
      ..removeWhere((i) => i.holdingIndex == holdingIndex && i.field == field)
      ..addAll(replacement);
  }

  /// Step 4: commits the current plan, optionally creating a snapshot.
  /// Full mode with proposed removals requires [confirmedFullRemovals] — the
  /// UI obtains it through a second confirmation that lists the removal count.
  Future<void> commit({
    bool confirmedFullRemovals = false,
    bool createSnapshot = false,
  }) async {
    final plan = _plan;
    if (_state is! ImportCheck || plan == null || !canCommit) return;
    if (_mode == ImportMode.full &&
        plan.removeIds.isNotEmpty &&
        !confirmedFullRemovals) {
      return;
    }
    _setState(const ImportCommitting());
    try {
      final quality = _dataQuality;
      final before = quality
          ?.calculate(
            await _repository.getAll(),
            freshQuoteHoldingIds: _freshQuoteIds?.call() ?? const {},
          )
          .dataCompleteness;
      final record = await _commitService.commit(plan);
      _commitRecord = record;
      if (createSnapshot) {
        await _snapshotRepository.createFromCurrent(label: '导入快照');
      }
      final tempPaths = _tempScreenshotPaths;
      _tempScreenshotPaths = const [];
      _ocrRows = const [];
      await _tempStore.clear(tempPaths);
      await _draftStore.clear();
      final after = quality
          ?.calculate(
            await _repository.getAll(),
            freshQuoteHoldingIds: _freshQuoteIds?.call() ?? const {},
          )
          .dataCompleteness;
      final report = ImportCommitReport(
        inserted: plan.inserts.length,
        updated: plan.updates.length,
        removed: plan.removeIds.length,
        skipped: plan.skipped.length,
        createdSnapshot: createSnapshot,
        completenessBefore: before,
        completenessAfter: after,
      );
      _lastRecord = LastImportRecord(
        committedAt: record.committedAt,
        inserted: report.inserted,
        updated: report.updated,
        removed: report.removed,
        skipped: report.skipped,
      );
      await _recordStore.save(_lastRecord!);
      _setState(ImportCommitted(report, record));
    } catch (e) {
      // 写入失败(数据库错误等):提供重试,恢复确认态后重新提交。
      _setState(ImportFailed('写入失败: $e', true, retry: _retryCommit));
    }
  }

  /// 写入失败后恢复到确认态并重新提交。仍失败时再次提供重试。
  Future<void> _retryCommit() async {
    final plan = _plan;
    final draft = _draft;
    if (plan == null || draft == null) return;
    try {
      final current = await _repository.getAll();
      _setState(ImportCheck(draft, plan, _buildSummary(plan, current, draft)));
      await commit();
    } catch (e) {
      _setState(ImportFailed('写入失败: $e', true, retry: _retryCommit));
    }
  }

  /// Reverses the committed import and returns to the source screen.
  Future<void> undo() async {
    final record = _commitRecord;
    if (record == null) return;
    try {
      await _commitService.undo(record);
    } catch (e) {
      _setState(ImportFailed('撤销失败: $e', true, retry: undo));
      return;
    }
    await _resetReview();
    _setState(const ImportSourceSelect());
  }

  /// Goes back one wizard step.
  Future<void> back() async {
    final state = _state;
    if (state is ImportSourceSelect && _source != null) {
      _source = null;
      _setState(const ImportSourceSelect());
    } else if (state is ImportCheck) {
      if (_ocrRows.isNotEmpty) {
        await _enterReview(_draft!, template: _template);
      } else if (_table != null) {
        // Return to field mapping when a raw table was the source of the draft.
        _setState(ImportFieldMapping(_table!, _mapping));
      } else {
        _setState(const ImportSourceSelect());
      }
    } else if (state is ImportFieldMapping) {
      await _resetReview();
      await _draftStore.clear();
      _setState(const ImportSourceSelect());
    } else if (state is ImportOcrReview) {
      // Leaving the OCR review discards the session: the user restarts from
      // the upload step, so temp copies and the persisted draft go away.
      await _resetReview();
      await _draftStore.clear();
      _setState(const ImportSourceSelect());
    }
  }

  /// Discards the session: clears temp screenshot copies and the persisted
  /// draft. The user's original files are left untouched.
  Future<void> discard() async {
    final tempPaths = _tempScreenshotPaths;
    await _resetReview();
    _source = null;
    _mode = ImportMode.partial;
    await _tempStore.clear(tempPaths);
    await _draftStore.clear();
    _setState(const ImportSourceSelect());
  }

  ImportDraft _draftFromOcr(Map<String, Object?> response, String template) {
    final platform = template == 'alipay'
        ? SourcePlatform.alipay
        : SourcePlatform.ths;
    final rows = <OcrRow>[];
    final holdings = <DraftHolding>[];
    final issues = <DataIssue>[];

    final rawRows = response['rows'] as List? ?? const [];
    for (var i = 0; i < rawRows.length; i++) {
      final rawRow = _asMap(rawRows[i]);
      final fields = <String, OcrFieldValue>{
        for (final entry in _asMap(rawRow['fields']).entries)
          entry.key: OcrFieldValue.fromJson(_asMap(entry.value)),
      };
      rows.add(
        OcrRow(
          index: i,
          pageIndex: (rawRow['page_index'] as num?)?.toInt() ?? 0,
          fields: fields,
        ),
      );

      for (final rawIssue in rawRow['issues'] as List? ?? const []) {
        issues.add(_issueFromJson(_asMap(rawIssue)));
      }

      final normalized = _asMap(rawRow['normalized']);
      DecimalValue? amountOf(String field) {
        final normalizedValue = normalized[field] as String?;
        if (normalizedValue != null) {
          final parsed = _parseAmount(normalizedValue);
          if (parsed != null) return parsed;
        }
        final rawText = fields[field]?.rawText;
        return rawText == null ? null : _parseAmount(rawText);
      }

      final currentValue = amountOf('current_value');
      holdings.add(
        DraftHolding(
          sourcePlatform: platform,
          productName: fields['product_name']?.rawText ?? '',
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: AssetClass.other,
          currentValue: currentValue ?? DecimalValue.parse('0'),
          quantity: amountOf('quantity'),
          costPrice: amountOf('cost_price'),
          holdingProfit: amountOf('holding_profit'),
          cumulativeProfit: amountOf('cumulative_profit'),
          dataOrigin: DataOrigin.ocr,
        ),
      );
    }

    for (final rawIssue in response['issues'] as List? ?? const []) {
      issues.add(_issueFromJson(_asMap(rawIssue)));
    }

    _ocrRows = rows;
    return ImportDraft(holdings: holdings, issues: issues);
  }
}
