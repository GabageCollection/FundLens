import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../data_engine/data_engine_client.dart';
import '../../importing/import_commit_service.dart';
import '../../importing/import_models.dart';
import '../../importing/import_planner.dart';
import '../../importing/tabular_import_parser.dart';
import '../../security/selected_path_guard.dart';
import '../../storage/holding_repository.dart';
import '../../storage/snapshot_repository.dart';
import 'import_check_summary_builder.dart';
import 'import_draft_field_edit.dart';
import 'import_draft_persistence.dart';
import 'import_duplicate_detection.dart';
import 'import_file_picker.dart';
import 'import_ocr_draft_builder.dart';
import 'import_review_state.dart';

// 状态机、文件选择与草稿持久化已拆分为独立文件;此处 re-export,
// 既有引用方(页面、测试、app_dependencies)无需改动。
export 'import_draft_persistence.dart';
export 'import_file_picker.dart';
export 'import_review_state.dart';

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
    ImportDuplicateDetector? duplicateDetector,
  }) : _repository = repository,
       _planner = planner ?? ImportPlanner(),
       _commitService = commitService ?? ImportCommitService(repository),
       _duplicateDetector =
           duplicateDetector ?? ImportDuplicateDetector(_engine);

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
  final ImportDuplicateDetector _duplicateDetector;

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
    await _ocrScreenshotFiles(files);
  }

  /// 复制截图到临时区并识别,失败时提供重试入口。
  /// 临时副本只复制一次:重试仅重跑 OCR,避免每试一次就重复全量文件 I/O
  /// 并留下无人清理的孤儿 job 目录(提交/放弃只清最新一批副本)。
  /// 复制本身失败时副本尚未建立,重试仍会走完整「复制 + OCR」链路。
  Future<void> _ocrScreenshotFiles(List<PickedImportFile> files) async {
    var tempPaths = const <String>[];
    await _runOcrWithRetry(() async {
      if (tempPaths.isEmpty) {
        tempPaths = await _tempStore.copyToTemp([
          for (final f in files) f.path,
        ]);
      }
      await _runOcr(tempPaths);
    });
  }

  /// 统一执行 [body] 并处理失败:进入解析中态,失败时提供重试入口,
  /// 重试会重新执行 [body]。
  Future<void> _runOcrWithRetry(Future<void> Function() body) async {
    try {
      _setState(const ImportParsing(null));
      await body();
    } catch (e) {
      _setState(
        ImportFailed(
          '截图识别失败: $e',
          true,
          retry: () => _runOcrWithRetry(body),
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
  ///
  /// picker 打开本身也可能抛异常(系统文件选择器错误等),必须像旧版一样
  /// 落入 [ImportFailed] 并提供重试入口,不能上抛为未处理异步异常。
  Future<void> pickScreenshots() async {
    final List<PickedImportFile> files;
    try {
      files = await _picker.pickScreenshotFiles();
    } catch (e) {
      _setState(
        ImportFailed('截图识别失败: $e', true, retry: pickScreenshots),
      );
      return;
    }
    if (files.isEmpty) return;
    await _ocrScreenshotFiles(files);
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
        final row = importAsMap(rawRow);
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

  /// Duplicate flags and engine-proposed product candidates are computed
  /// by [ImportDuplicateDetector]; the engine proposes, the user selects.
  Future<void> _refreshDuplicates(
    ImportDraft draft,
    List<Holding> current,
  ) async {
    final result = await _duplicateDetector.detect(draft, current);
    _duplicateIndexes = result.duplicateIndexes;
    _candidateGroups = result.candidateGroups;
    _candidateSelections.removeWhere(
      (i, _) => !result.candidateGroups.containsKey(i),
    );
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
  ) => buildImportCheckSummary(
    plan: plan,
    current: current,
    draft: draft,
    duplicateCount: _duplicateIndexes.length,
  );

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

  /// Applies a user edit to a draft field. A valid value clears the
  /// issues recorded for that field; an invalid amount adds a blocking
  /// issue, which disables commit until corrected.
  Future<void> updateHoldingField(
    int holdingIndex,
    String field,
    String text,
  ) async {
    final draft = _draft;
    if (draft == null) return;

    final edit = applyDraftFieldEdit(draft, holdingIndex, field, text);
    final invalidIssue = edit.invalidAmountIssue;
    if (invalidIssue != null) {
      replaceDraftFieldIssues(draft, holdingIndex, field, [invalidIssue]);
      notifyListeners();
      return;
    }
    _draft = edit.draft!;
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
    final result = buildDraftFromOcr(response, template);
    _ocrRows = result.rows;
    return result.draft;
  }

}
