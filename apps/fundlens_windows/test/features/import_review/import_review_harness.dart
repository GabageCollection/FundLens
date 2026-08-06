import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/data_engine/data_engine_client.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/features/import_review/import_review_page.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final class FakeDataEngineClient implements DataEngineClient {
  final Map<String, Map<String, Object?>> responses = {};
  final List<String> calls = [];

  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    calls.add(method);
    final response = responses[method];
    if (response == null) {
      throw StateError('unexpected engine call: $method');
    }
    return Future.value(response);
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> close() async {}
}

final class FakeHoldingRepository implements HoldingRepository {
  FakeHoldingRepository([List<Holding>? initial])
    : holdings = List.of(initial ?? const <Holding>[]);

  final List<Holding> holdings;

  @override
  Future<void> upsert(Holding holding) async {
    holdings.removeWhere((h) => h.id == holding.id);
    holdings.add(holding);
  }

  @override
  Future<void> replacePlatform(
    SourcePlatform platform,
    List<Holding> next,
  ) async {
    holdings.removeWhere((h) => h.sourcePlatform == platform);
    holdings.addAll(next);
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    holdings.removeWhere((h) => ids.contains(h.id));
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();

  @override
  Stream<List<Holding>> watchAll() => Stream.value(List.of(holdings));

  @override
  Future<List<Holding>> getAll() async => List.of(holdings);
}

final class FakeImportFilePicker implements ImportFilePicker {
  PickedImportFile? csvFile;
  PickedImportFile? excelFile;
  PickedImportFile? tabularFile;
  List<PickedImportFile> screenshots = const [];
  /// 非空时 [pickScreenshotFiles] 抛出该错误,用于模拟文件选择器异常。
  Object? screenshotError;

  @override
  Future<PickedImportFile?> pickCsvFile() async => csvFile;

  @override
  Future<PickedImportFile?> pickExcelFile() async => excelFile;

  @override
  Future<PickedImportFile?> pickTabularFile() async => tabularFile ?? csvFile;

  @override
  Future<List<PickedImportFile>> pickScreenshotFiles() async {
    final error = screenshotError;
    if (error != null) throw error;
    return screenshots;
  }
}

final class FakeScreenshotTempStore implements ScreenshotTempStore {
  final List<String> copied = [];
  final List<String> cleared = [];

  @override
  Future<List<String>> copyToTemp(List<String> sourcePaths) async {
    copied.addAll(sourcePaths);
    return sourcePaths.map((path) => 'temp/$path').toList();
  }

  @override
  Future<void> clear(List<String> tempPaths) async {
    cleared.addAll(tempPaths);
  }
}

final class InMemoryImportDraftStore implements ImportDraftStore {
  PersistedImportDraft? saved;
  var clearCount = 0;

  @override
  Future<PersistedImportDraft?> load() async => saved;

  @override
  Future<void> save(PersistedImportDraft draft) async {
    saved = draft;
  }

  @override
  Future<void> clear() async {
    saved = null;
    clearCount++;
  }
}

final class FakeSnapshotRepository implements SnapshotRepository {
  FakeSnapshotRepository() : _created = [];

  final List<String> _created;
  int get createCount => _created.length;

  @override
  Future<String> createFromCurrent({required String label}) async {
    _created.add(label);
    return 'snapshot-${_created.length}';
  }

  @override
  Future<PortfolioSnapshot> getById(String id) => throw UnimplementedError();

  @override
  Future<List<PortfolioSnapshot>> getAll() async => const [];

  @override
  Future<void> deleteById(String id) async {}
}

final class InMemoryImportRecordStore implements ImportRecordStore {
  LastImportRecord? saved;
  var clearCount = 0;

  @override
  Future<LastImportRecord?> load() async => saved;

  @override
  Future<void> save(LastImportRecord record) async {
    saved = record;
  }

  @override
  Future<void> clear() async {
    saved = null;
    clearCount++;
  }
}

Map<String, Object?> ocrFieldJson(
  String name,
  String rawText, {
  double confidence = 0.87,
}) {
  return <String, Object?>{
    'name': name,
    'raw_text': rawText,
    'confidence': confidence,
    'page_index': 0,
    'crop': const [10, 20, 200, 40],
  };
}

Map<String, Object?> alipayOcrResponse({
  String productName = '测试基金',
  String currentValue = '78,347.87',
  double confidence = 0.87,
  List<Map<String, Object?>> rowIssues = const [],
  List<Map<String, Object?>> issues = const [],
}) {
  final normalized = <String, Object?>{'holding_profit': '1000.00'};
  final parsedValue = currentValue.replaceAll(',', '');
  if (double.tryParse(parsedValue) != null) {
    normalized['current_value'] = parsedValue;
  }
  return <String, Object?>{
    'template': 'alipay',
    'rows': [
      <String, Object?>{
        'index': 0,
        'page_index': 0,
        'fields': <String, Object?>{
          'product_name': ocrFieldJson(
            'product_name',
            productName,
            confidence: 0.98,
          ),
          'current_value': ocrFieldJson(
            'current_value',
            currentValue,
            confidence: confidence,
          ),
          'holding_profit': ocrFieldJson(
            'holding_profit',
            '1,000.00',
            confidence: 0.95,
          ),
        },
        'normalized': normalized,
        'issues': rowIssues,
      },
    ],
    'issues': issues,
  };
}

Map<String, Object?> blockingIssueJson({
  String field = 'current_value',
  int holdingIndex = 0,
}) {
  return <String, Object?>{
    'code': 'ocr.unparseable_number',
    'field': field,
    'severity': 'blocking',
    'message': '字段无法解析为数字',
    'holding_index': holdingIndex,
  };
}

Holding existingHolding({
  String id = 'keep-1',
  String name = '旧基金',
  SourcePlatform platform = SourcePlatform.alipay,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: platform,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: name,
    currency: 'CNY',
    currentValue: DecimalValue.parse('500.00'),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

PickedImportFile csvPickedFile(String content) {
  return PickedImportFile(
    name: 'holdings.csv',
    path: 'originals/holdings.csv',
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
}

Future<ImportReviewController> pumpImportHarness(
  WidgetTester tester, {
  FakeDataEngineClient? engine,
  FakeHoldingRepository? repository,
  FakeImportFilePicker? picker,
  FakeScreenshotTempStore? tempStore,
  InMemoryImportDraftStore? draftStore,
  FakeSnapshotRepository? snapshots,
  InMemoryImportRecordStore? records,
  ImportReviewController? controller,
  Size size = const Size(1440, 900),
}) async {
  final effectiveController =
      controller ??
      ImportReviewController(
        engine: engine ?? FakeDataEngineClient(),
        repository: repository ?? FakeHoldingRepository(),
        picker: picker ?? FakeImportFilePicker(),
        tempStore: tempStore ?? FakeScreenshotTempStore(),
        draftStore: draftStore ?? InMemoryImportDraftStore(),
        snapshotRepository: snapshots ?? FakeSnapshotRepository(),
        recordStore: records ?? InMemoryImportRecordStore(),
      );
  // 桌面画布尺寸默认 1440×900(>=960 走宽屏左右分栏),
  // 可通过 size 传入窄画布以覆盖 <960 的堆叠布局。
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        importReviewControllerProvider.overrideWith(
          (ref) => effectiveController,
        ),
      ],
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const ImportReviewPage(),
      ),
    ),
  );
  return effectiveController;
}
