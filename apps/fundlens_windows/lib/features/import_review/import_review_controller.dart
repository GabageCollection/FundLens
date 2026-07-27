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

/// Review state machine for the import workspace.
sealed class ImportReviewState {
  const ImportReviewState();
}

final class ImportIdle extends ImportReviewState {
  const ImportIdle();
}

final class ImportParsing extends ImportReviewState {
  const ImportParsing(this.progress, {this.currentStep, this.totalSteps});
  final double? progress;

  /// 1-based step currently running, when parsing works through several
  /// inputs (one per screenshot); null for single-shot parsing.
  final int? currentStep;
  final int? totalSteps;
}

final class ImportEditing extends ImportReviewState {
  const ImportEditing(this.draft, this.plan);
  final ImportDraft draft;
  final ImportPlan plan;
}

final class ImportCommitting extends ImportReviewState {
  const ImportCommitting();
}

final class ImportCommitted extends ImportReviewState {
  const ImportCommitted(this.report);
  final ImportCommitReport report;
}

final class ImportFailed extends ImportReviewState {
  const ImportFailed(this.message, this.retryable);
  final String message;
  final bool retryable;
}

/// Factual summary of a committed import.
final class ImportCommitReport {
  const ImportCommitReport({
    required this.inserted,
    required this.updated,
    required this.removed,
  });

  final int inserted;
  final int updated;
  final int removed;
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
          for (final v in json['crop'] as List? ?? const [])
            (v as num).toInt(),
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
    this.ocrRows = const [],
    this.tempScreenshotPaths = const [],
  });

  final ImportMode mode;
  final String? template;
  final List<DraftHolding> holdings;
  final List<DataIssue> issues;
  final List<OcrRow> ocrRows;
  final List<String> tempScreenshotPaths;

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'template': template,
        'holdings': [for (final h in holdings) _holdingToJson(h)],
        'issues': [for (final i in issues) _issueToJson(i)],
        'ocr_rows': [for (final r in ocrRows) r.toJson()],
        'temp_screenshot_paths': tempScreenshotPaths,
      };

  factory PersistedImportDraft.fromJson(Map<String, Object?> json) {
    return PersistedImportDraft(
      mode: ImportMode.values.byName(json['mode'] as String? ?? 'partial'),
      template: json['template'] as String?,
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
        for (final path
            in json['temp_screenshot_paths'] as List? ?? const [])
          path.toString(),
      ],
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
    sourcePlatform:
        SourcePlatform.values.byName(json['source_platform'] as String),
    productName: json['product_name'] as String,
    productCode: json['product_code'] as String?,
    instrumentType:
        InstrumentType.values.byName(json['instrument_type'] as String),
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
          json['severity'] as String? ?? 'warning'),
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

final importReviewControllerProvider =
    ChangeNotifierProvider<ImportReviewController>((ref) {
  return ImportReviewController(
    engine: ref.watch(dataEngineClientProvider),
    repository: ref.watch(holdingRepositoryProvider),
    picker: ref.watch(importFilePickerProvider),
    tempStore: ref.watch(screenshotTempStoreProvider),
    draftStore: ref.watch(importDraftStoreProvider),
  );
});

/// Drives the import workspace: parsing, review, diff, commit and draft
/// recovery. Partial import is the default mode and never removes
/// holdings; full mode proposes removals that require an explicit second
/// confirmation. Temporary screenshot copies are cleared only after a
/// successful commit or an explicit discard; the user's original files
/// are never deleted.
final class ImportReviewController extends ChangeNotifier {
  ImportReviewController({
    required this._engine,
    required HoldingRepository repository,
    required this._picker,
    required this._tempStore,
    required this._draftStore,
    this._parser = const TabularImportParser(),
    ImportPlanner? planner,
    ImportCommitService? commitService,
  })  : _repository = repository,
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

  ImportReviewState _state = const ImportIdle();
  ImportReviewState get state => _state;

  ImportMode _mode = ImportMode.partial;
  ImportMode get mode => _mode;

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

  String? _focusedField;
  int? _focusedHoldingIndex;
  String? get focusedField => _focusedField;
  int? get focusedHoldingIndex => _focusedHoldingIndex;

  Set<int> _duplicateIndexes = const {};
  int get duplicateCount => _duplicateIndexes.length;

  Map<int, List<ProductCandidate>> _candidateGroups = const {};
  Map<int, List<ProductCandidate>> get candidateGroups => _candidateGroups;

  final Map<int, ProductCandidate> _candidateSelections = {};
  Map<int, ProductCandidate> get candidateSelections =>
      Map.unmodifiable(_candidateSelections);

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
    return _state is ImportEditing &&
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

  Future<void> importCsv() async {
    try {
      final file = await _picker.pickCsvFile();
      if (file == null) return;
      _setState(const ImportParsing(null));
      final bytes = file.bytes ?? await File(file.path).readAsBytes();
      final draft = _parser.parseCsv(utf8.decode(bytes));
      await _enterEditing(draft);
    } catch (e) {
      _setState(ImportFailed('CSV 解析失败: $e', true));
    }
  }

  Future<void> importExcel() async {
    try {
      final file = await _picker.pickExcelFile();
      if (file == null) return;
      _setState(const ImportParsing(null));
      final bytes = file.bytes ?? await File(file.path).readAsBytes();
      final draft = _parser.parseExcel(bytes);
      await _enterEditing(draft);
    } catch (e) {
      _setState(ImportFailed('Excel 解析失败: $e', true));
    }
  }

  Future<void> importScreenshots() async {
    try {
      final files = await _picker.pickScreenshotFiles();
      if (files.isEmpty) return;
      _setState(const ImportParsing(null));
      final tempPaths =
          await _tempStore.copyToTemp([for (final f in files) f.path]);
      final template = templateHint;
      final canonicalPaths =
          const SelectedPathGuard().canonicalizeAll(tempPaths);
      // Recognize one screenshot per engine call: a single slow page can no
      // longer stall the whole batch behind one timeout, and the UI can show
      // real progress. The engine keeps its OCR models loaded between calls,
      // so only the first call pays the model-loading cost — a generous
      // per-call timeout covers that cold start in the frozen bundle.
      final mergedRows = <Object?>[];
      final mergedIssues = <Object?>[];
      for (var i = 0; i < canonicalPaths.length; i++) {
        _setState(ImportParsing(
          i / canonicalPaths.length,
          currentStep: i + 1,
          totalSteps: canonicalPaths.length,
        ));
        final response = await _engine.call(
          'ocr.parse_screenshots',
          {'paths': [canonicalPaths[i]], 'template': template},
          timeout: const Duration(minutes: 3),
        );
        for (final rawRow in response['rows'] as List? ?? const []) {
          final row = _asMap(rawRow);
          row['page_index'] = i;
          mergedRows.add(row);
        }
        mergedIssues.addAll(response['issues'] as List? ?? const []);
      }
      _tempScreenshotPaths = tempPaths;
      final draft = _draftFromOcr(
        {'rows': mergedRows, 'issues': mergedIssues},
        template,
      );
      await _enterEditing(draft, template: template);
    } catch (e) {
      _setState(ImportFailed('截图识别失败: $e', true));
    }
  }

  Future<void> _enterEditing(
    ImportDraft draft, {
    String? template,
    ImportMode mode = ImportMode.partial,
  }) async {
    _draft = draft;
    _template = template;
    _mode = mode;
    _focusedField = null;
    _focusedHoldingIndex = null;
    await _replan();
    await _persist();
    _setState(ImportEditing(_draft!, _plan!));
  }

  Future<void> _replan() async {
    final draft = _draft!;
    final current = await _repository.getAll();
    final platform = draft.holdings.isEmpty
        ? SourcePlatform.manual
        : draft.holdings.first.sourcePlatform;
    _plan = _planner.plan(
      mode: _mode,
      platform: platform,
      current: current,
      incoming: draft.holdings,
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

  Future<void> _persist() async {
    final draft = _draft;
    if (draft == null) return;
    await _draftStore.save(
      PersistedImportDraft(
        mode: _mode,
        template: _template,
        holdings: draft.holdings,
        issues: draft.issues,
        ocrRows: _ocrRows,
        tempScreenshotPaths: _tempScreenshotPaths,
      ),
    );
  }

  /// Restores an uncommitted draft left over from a previous run.
  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    final saved = await _draftStore.load();
    if (saved == null) return;
    _ocrRows = saved.ocrRows;
    _tempScreenshotPaths = saved.tempScreenshotPaths;
    _setState(const ImportParsing(null));
    try {
      await _enterEditing(
        ImportDraft(holdings: saved.holdings, issues: saved.issues),
        template: saved.template,
        mode: saved.mode,
      );
    } catch (e) {
      _setState(ImportFailed('草稿恢复失败: $e', true));
    }
  }

  Future<void> setMode(ImportMode mode) async {
    if (_state is! ImportEditing || mode == _mode) return;
    _mode = mode;
    await _replan();
    await _persist();
    _setState(ImportEditing(_draft!, _plan!));
  }

  void focusField(String field, int? holdingIndex) {
    _focusedField = field;
    _focusedHoldingIndex = holdingIndex;
    notifyListeners();
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
      productName:
          field == 'product_name' || field == 'productName'
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
    _setState(ImportEditing(_draft!, _plan!));
  }

  void _replaceIssues(
    ImportDraft draft,
    int holdingIndex,
    String field,
    List<DataIssue> replacement,
  ) {
    draft.issues
      ..removeWhere(
        (i) => i.holdingIndex == holdingIndex && i.field == field,
      )
      ..addAll(replacement);
  }

  /// Commits the current plan. Full mode with proposed removals requires
  /// [confirmedFullRemovals] — the UI obtains it through a second
  /// confirmation that lists the removal count.
  Future<void> commit({bool confirmedFullRemovals = false}) async {
    final plan = _plan;
    if (_state is! ImportEditing || plan == null || !canCommit) return;
    if (_mode == ImportMode.full &&
        plan.removeIds.isNotEmpty &&
        !confirmedFullRemovals) {
      return;
    }
    _setState(const ImportCommitting());
    try {
      await _commitService.commit(plan);
      final tempPaths = _tempScreenshotPaths;
      _tempScreenshotPaths = const [];
      _ocrRows = const [];
      await _tempStore.clear(tempPaths);
      await _draftStore.clear();
      _setState(
        ImportCommitted(
          ImportCommitReport(
            inserted: plan.inserts.length,
            updated: plan.updates.length,
            removed: plan.removeIds.length,
          ),
        ),
      );
    } catch (e) {
      _setState(ImportFailed('写入失败: $e', true));
    }
  }

  /// Discards the session: clears temp screenshot copies and the persisted
  /// draft. The user's original files are left untouched.
  Future<void> discard() async {
    final tempPaths = _tempScreenshotPaths;
    _tempScreenshotPaths = const [];
    _ocrRows = const [];
    _draft = null;
    _plan = null;
    _template = null;
    _mode = ImportMode.partial;
    _focusedField = null;
    _focusedHoldingIndex = null;
    _duplicateIndexes = const {};
    _candidateGroups = const {};
    _candidateSelections.clear();
    await _tempStore.clear(tempPaths);
    await _draftStore.clear();
    _setState(const ImportIdle());
  }

  ImportDraft _draftFromOcr(Map<String, Object?> response, String template) {
    final platform =
        template == 'alipay' ? SourcePlatform.alipay : SourcePlatform.ths;
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
