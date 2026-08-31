import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/importing/import_models.dart';

import 'import_review_harness.dart';

ImportReviewController _controller({
  FakeDataEngineClient? engine,
  FakeHoldingRepository? repository,
  FakeImportFilePicker? picker,
  FakeScreenshotTempStore? tempStore,
  InMemoryImportDraftStore? draftStore,
  FakeSnapshotRepository? snapshots,
  InMemoryImportRecordStore? records,
}) {
  return ImportReviewController(
    engine: engine ?? FakeDataEngineClient(),
    repository: repository ?? FakeHoldingRepository(),
    picker: picker ?? FakeImportFilePicker(),
    tempStore: tempStore ?? FakeScreenshotTempStore(),
    draftStore: draftStore ?? InMemoryImportDraftStore(),
    snapshotRepository: snapshots ?? FakeSnapshotRepository(),
    recordStore: records ?? InMemoryImportRecordStore(),
  );
}

PickedImportFile _csvFile(String content) => PickedImportFile(
  name: 'holdings.csv',
  path: 'originals/holdings.csv',
  bytes: Uint8List.fromList(utf8.encode(content)),
);

void main() {
  test('初始状态为来源选择,source 为空', () {
    final controller = _controller();
    expect(controller.state, isA<ImportSourceSelect>());
    expect(controller.source, isNull);
  });

  test('selectSource 记录来源并回到来源步', () async {
    final controller = _controller();
    await controller.selectSource(ImportSource.csv);
    expect(controller.source, ImportSource.csv);
    expect(controller.state, isA<ImportSourceSelect>());
  });

  test('CSV 上传后进入字段映射步,携带原始表格与猜测映射', () async {
    final picker = FakeImportFilePicker()
      ..csvFile = _csvFile('产品名称,当前金额\n基金A,100\n');
    final controller = _controller(picker: picker);
    await controller.selectSource(ImportSource.csv);

    await controller.pickFile();

    expect(controller.state, isA<ImportFieldMapping>());
    final mapping = controller.state as ImportFieldMapping;
    expect(mapping.table.headings, ['产品名称', '当前金额']);
    expect(mapping.table.dataRows.single, ['基金A', '100']);
    expect(mapping.mapping['productName'], 0);
    expect(mapping.mapping['currentValue'], 1);
  });

  test('拖拽 CSV 同样进入字段映射步', () async {
    final controller = _controller();
    await controller.selectSource(ImportSource.csv);

    await controller.acceptDroppedFile(
      _csvFile('基金代码,产品名称,市值\n000001,基金A,100\n'),
    );

    final mapping = controller.state as ImportFieldMapping;
    expect(mapping.mapping['productCode'], 0);
    expect(mapping.mapping['productName'], 1);
    expect(mapping.mapping['currentValue'], 2);
  });

  test('用户修正映射后进入确认检查步', () async {
    final controller = _controller();
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(_csvFile('基金名,市值金额\n基金A,100\n'));
    // 自动识别缺必填列 → 阻断
    expect(controller.state, isA<ImportFieldMapping>());

    await controller.setMapping({'productName': 0, 'currentValue': 1});
    await controller.applyMapping();

    expect(controller.state, isA<ImportCheck>());
    final check = controller.state as ImportCheck;
    expect(check.draft.holdings.single.productName, '基金A');
    expect(check.draft.holdings.single.currentValue.canonical, '100');
  });

  test('确认检查摘要统计新增/更新/重复/异常/未分类/金额变化', () async {
    final repository = FakeHoldingRepository([
      existingHolding(
        id: 'update-1',
        name: '重合基金',
        platform: SourcePlatform.alipay,
      ),
    ]);
    final controller = _controller(repository: repository);
    await controller.selectSource(ImportSource.alipay);
    await controller.acceptDroppedFile(
      _csvFile('产品名称,当前金额\n重合基金,200\n新增基金,300\n'),
    );
    await controller.applyMapping();

    final check = controller.state as ImportCheck;
    final summary = check.summary;
    expect(summary.insertCount, 1);
    expect(summary.updateCount, 1);
    // 新增 300 + 更新差(200−500) = 0
    expect(summary.totalValueChange.canonical, '0');
  });

  test('确认检查摘要:仅新增时金额变化等于新增金额', () async {
    final controller = _controller();
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(
      _csvFile('产品名称,当前金额\n基金A,100\n基金B,250\n'),
    );
    await controller.applyMapping();

    final summary = (controller.state as ImportCheck).summary;
    expect(summary.insertCount, 2);
    expect(summary.updateCount, 0);
    expect(summary.totalValueChange.canonical, '350');
  });

  test('setResolution 用合并方式重算计划', () async {
    final repository = FakeHoldingRepository([
      existingHolding(id: 'existing', name: '脱敏基金A'),
    ]);
    final controller = _controller(repository: repository);
    await controller.selectSource(ImportSource.alipay);
    await controller.acceptDroppedFile(_csvFile('产品名称,当前金额\n脱敏基金A,200\n'));
    await controller.applyMapping();

    await controller.setResolution(0, DuplicateResolution.merge);

    final check = controller.state as ImportCheck;
    expect(check.plan.updates.single.currentValue.canonical, '700');
  });

  test('截图流程:上传→OCR复核→删行→确认检查→提交', () async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    final controller = _controller(engine: engine, picker: picker);

    await controller.selectSource(ImportSource.screenshot);
    await controller.pickScreenshots();

    expect(controller.state, isA<ImportOcrReview>());
    expect(controller.ocrRows, hasLength(1));

    await controller.removeOcrRow(0);
    expect(controller.ocrRows, isEmpty);

    await controller.confirmOcrReview();
    // 删空后无持仓 → 仍能进入确认检查(空计划)
    expect(controller.state, isA<ImportCheck>());
  });

  test('commit 写入、生成报告并保存最近导入记录', () async {
    final repository = FakeHoldingRepository();
    final records = InMemoryImportRecordStore();
    final controller = _controller(repository: repository, records: records);
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(_csvFile('产品名称,当前金额\n基金A,100\n'));
    await controller.applyMapping();

    await controller.commit();

    expect(controller.state, isA<ImportCommitted>());
    final committed = controller.state as ImportCommitted;
    expect(committed.report.inserted, 1);
    expect(repository.holdings.single.productName, '基金A');
    expect(records.saved?.inserted, 1);
  });

  test('提交结果页「继续导入」回到来源选择', () async {
    final controller = _controller();
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(_csvFile('产品名称,当前金额\n基金A,100\n'));
    await controller.applyMapping();
    await controller.commit();
    expect(controller.state, isA<ImportCommitted>());

    await controller.back();

    expect(controller.state, isA<ImportSourceSelect>());
  });

  test('commit 可创建快照', () async {
    final snapshots = FakeSnapshotRepository();
    final controller = _controller(snapshots: snapshots);
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(_csvFile('产品名称,当前金额\n基金A,100\n'));
    await controller.applyMapping();

    await controller.commit(createSnapshot: true);

    expect(snapshots.createCount, 1);
  });

  test('commit 不创建快照', () async {
    final snapshots = FakeSnapshotRepository();
    final controller = _controller(snapshots: snapshots);
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(_csvFile('产品名称,当前金额\n基金A,100\n'));
    await controller.applyMapping();

    await controller.commit();

    expect(snapshots.createCount, 0);
  });

  test('undo 撤销本次导入并回到来源步', () async {
    final repository = FakeHoldingRepository([
      existingHolding(id: 'update-1', name: '重合基金'),
    ]);
    final controller = _controller(repository: repository);
    await controller.selectSource(ImportSource.alipay);
    await controller.acceptDroppedFile(
      _csvFile('产品名称,当前金额\n重合基金,200\n新增基金,300\n'),
    );
    await controller.applyMapping();

    await controller.commit();
    expect(repository.holdings, hasLength(2));

    await controller.undo();

    expect(controller.state, isA<ImportSourceSelect>());
    expect(repository.holdings, hasLength(1));
    expect(repository.holdings.single.currentValue.canonical, '500');
  });

  test('back 从确认检查返回字段映射,再从映射返回来源', () async {
    final controller = _controller();
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(_csvFile('产品名称,当前金额\n基金A,100\n'));
    await controller.applyMapping();
    expect(controller.state, isA<ImportCheck>());

    await controller.back();
    expect(controller.state, isA<ImportFieldMapping>());

    await controller.back();
    expect(controller.state, isA<ImportSourceSelect>());
  });

  test('阻断问题禁用提交', () async {
    final controller = _controller();
    await controller.selectSource(ImportSource.csv);
    await controller.acceptDroppedFile(_csvFile('产品名称,当前金额\n基金A,abc\n'));
    await controller.applyMapping();

    expect(controller.state, isA<ImportCheck>());
    expect(controller.canCommit, isFalse);
  });

  test('取消清理临时截图与草稿', () async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    final tempStore = FakeScreenshotTempStore();
    final controller = _controller(
      engine: engine,
      picker: picker,
      tempStore: tempStore,
    );
    await controller.selectSource(ImportSource.screenshot);
    await controller.pickScreenshots();

    await controller.discard();

    expect(controller.state, isA<ImportSourceSelect>());
    expect(tempStore.cleared, contains('temp/originals/shot.png'));
  });
}
