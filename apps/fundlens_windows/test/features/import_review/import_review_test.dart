import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

import 'import_review_harness.dart';

/// Scrolls the button into view before tapping, because wizard bodies are
/// long `SingleChildScrollView`s and bottom actions can sit below the fold.
Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Taps a primary action button by label. Uses [FilledButton] so the step
/// indicator's "确认导入" label is never mistaken for the actual button.
Future<void> tapPrimary(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Walks the wizard: choose CSV source → drop a file → confirm mapping →
/// confirmation screen.
Future<ImportReviewController> pumpCsvSession(
  WidgetTester tester, {
  String csv = '产品名称,当前金额\n重合基金,1000.00\n',
  FakeHoldingRepository? repository,
  FakeDataEngineClient? engine,
}) async {
  final controller = await pumpImportHarness(
    tester,
    repository: repository,
    engine: engine,
    picker: FakeImportFilePicker()..csvFile = csvPickedFile(csv),
  );
  await tester.tap(find.text('通用 CSV'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('点击选择或拖拽文件到此处'));
  await tester.pumpAndSettle();
  await tapVisible(tester, '确认映射');
  return controller;
}

Future<ImportReviewController> pumpScreenshotSession(
  WidgetTester tester, {
  required FakeDataEngineClient engine,
  FakeHoldingRepository? repository,
  FakeScreenshotTempStore? tempStore,
  InMemoryImportDraftStore? draftStore,
}) async {
  final controller = await pumpImportHarness(
    tester,
    engine: engine,
    repository: repository,
    tempStore: tempStore,
    draftStore: draftStore,
    picker: FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ],
  );
  await tester.tap(find.text('截图识别'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('选择截图'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('导入页使用 form 档 PageScaffold', (tester) async {
    await pumpImportHarness(tester);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.form);
    expect(find.text('导入与识别'), findsOneWidget);
    expect(find.text('选择数据来源'), findsOneWidget);
  });

  testWidgets('screenshot import defaults to partial mode', (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final controller = await pumpScreenshotSession(tester, engine: engine);

    await tapVisible(tester, '确认识别结果');

    expect(find.text('部分持仓'), findsOneWidget);
    expect(controller.mode, ImportMode.partial);
  });

  testWidgets('blocking OCR issue disables confirmation', (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        currentValue: 'abc',
        rowIssues: [blockingIssueJson()],
        issues: [blockingIssueJson()],
      );
    await pumpScreenshotSession(tester, engine: engine);

    await tapVisible(tester, '确认识别结果');

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认导入'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('field selection shows its source crop', (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    await pumpScreenshotSession(tester, engine: engine);

    await tester.tap(find.text('78,347.87'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('ocr-crop-current_value')),
      findsOneWidget,
    );
  });

  testWidgets('窄屏(<960)编辑态走堆叠路径且无溢出', (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      picker: FakeImportFilePicker()
        ..screenshots = const [
          PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
        ],
      size: const Size(800, 900),
    );
    await tester.tap(find.text('截图识别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择截图'));
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportOcrReview>());
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CSV import parses rows and shows the diff', (tester) async {
    final controller = await pumpCsvSession(tester);

    expect(controller.state, isA<ImportCheck>());
    expect(find.text('即将新增'), findsOneWidget);
    expect(find.text('1 条'), findsWidgets);
    expect(find.text('部分持仓'), findsOneWidget);
  });

  testWidgets('cancelling the picker keeps the source step', (tester) async {
    final controller = await pumpImportHarness(tester);
    await tester.tap(find.text('通用 CSV'));
    await tester.pumpAndSettle();

    // picker 返回 null:停留在来源步,来源已选中。
    expect(controller.state, isA<ImportSourceSelect>());
    expect(controller.source, ImportSource.csv);
    expect(find.widgetWithText(FilledButton, '确认导入'), findsNothing);
  });

  testWidgets('uncommitted draft is restored after a restart', (tester) async {
    final store = InMemoryImportDraftStore();
    await pumpImportHarness(
      tester,
      draftStore: store,
      picker: FakeImportFilePicker()
        ..csvFile = csvPickedFile('产品名称,当前金额\n重合基金,1000.00\n'),
    );
    await tester.tap(find.text('通用 CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点击选择或拖拽文件到此处'));
    await tester.pumpAndSettle();
    await tapVisible(tester, '确认映射');
    expect(store.saved, isNotNull);

    final restarted = ImportReviewController(
      engine: FakeDataEngineClient(),
      repository: FakeHoldingRepository(),
      picker: FakeImportFilePicker(),
      tempStore: FakeScreenshotTempStore(),
      draftStore: store,
      snapshotRepository: FakeSnapshotRepository(),
      recordStore: InMemoryImportRecordStore(),
    );
    await restarted.restore();
    expect(restarted.state, isA<ImportCheck>());
    final check = restarted.state as ImportCheck;
    expect(check.draft.holdings.single.productName, '重合基金');

    await pumpImportHarness(tester, controller: restarted);
    await tester.pumpAndSettle();
    expect(find.text('即将新增'), findsOneWidget);
  });

  testWidgets(
    'partial commit keeps unmatched holdings and clears only temp copies',
    (tester) async {
      final repository = FakeHoldingRepository([existingHolding()]);
      final tempStore = FakeScreenshotTempStore();
      final store = InMemoryImportDraftStore();
      final engine = FakeDataEngineClient()
        ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
          productName: '新基金',
        );
      final controller = await pumpScreenshotSession(
        tester,
        engine: engine,
        repository: repository,
        tempStore: tempStore,
        draftStore: store,
      );
      await tapVisible(tester, '确认识别结果');
      await tapPrimary(tester, '确认导入');

      expect(controller.state, isA<ImportCommitted>());
      expect(repository.holdings.map((h) => h.id), contains('keep-1'));
      expect(repository.holdings.length, 2);
      expect(tempStore.cleared, contains('temp/originals/shot.png'));
      expect(tempStore.cleared, isNot(contains('originals/shot.png')));
      expect(store.saved, isNull);
    },
  );

  testWidgets('full mode warns and requires a second confirmation naming the '
      'removal count', (tester) async {
    final repository = FakeHoldingRepository([existingHolding()]);
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        productName: '新基金',
      );
    final controller = await pumpScreenshotSession(
      tester,
      engine: engine,
      repository: repository,
    );

    await tapVisible(tester, '确认识别结果');
    await tapVisible(tester, '全量持仓');

    expect(find.textContaining('全量导入将移除不再出现的 1 条同平台持仓'), findsOneWidget);

    await tapPrimary(tester, '确认导入');

    // Not committed yet: a second confirmation lists the removal count.
    expect(find.textContaining('将移除 1 条持仓'), findsOneWidget);
    expect(repository.holdings.map((h) => h.id), contains('keep-1'));

    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('确认')),
    );
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportCommitted>());
    expect(repository.holdings.map((h) => h.id), isNot(contains('keep-1')));
  });

  testWidgets('product candidates require an explicit radio selection', (
    tester,
  ) async {
    final repository = FakeHoldingRepository([
      existingHolding(id: 'ths-1', name: '重合基金', platform: SourcePlatform.ths),
    ]);
    final engine = FakeDataEngineClient()
      ..responses['product.match_candidates'] = <String, Object?>{
        'candidates': [
          <String, Object?>{
            'product_code': '000001',
            'name': '重合基金A',
            'product_type': 'off_exchange_fund',
            'confidence': 0.9,
            'reason': 'exact_name',
            'selected': false,
          },
          <String, Object?>{
            'product_code': '000002',
            'name': '重合基金B',
            'product_type': 'off_exchange_fund',
            'confidence': 0.6,
            'reason': 'token_similarity',
            'selected': false,
          },
        ],
      };
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      repository: repository,
      picker: FakeImportFilePicker()
        ..csvFile = csvPickedFile('产品名称,当前金额\n重合基金,1000.00\n'),
    );
    await tester.tap(find.text('通用 CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点击选择或拖拽文件到此处'));
    await tester.pumpAndSettle();
    await tapVisible(tester, '确认映射');

    expect(engine.calls, contains('product.match_candidates'));
    expect(controller.state, isA<ImportCheck>());
    expect(find.byType(RadioListTile<int>), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认导入'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认导入'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('discard clears temp copies but never the original files', (
    tester,
  ) async {
    final tempStore = FakeScreenshotTempStore();
    final store = InMemoryImportDraftStore();
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      tempStore: tempStore,
      draftStore: store,
      picker: FakeImportFilePicker()
        ..screenshots = const [
          PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
        ],
    );
    await tester.tap(find.text('截图识别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择截图'));
    await tester.pumpAndSettle();

    // 截图复核步点击“返回”回到上传区并清理临时副本,来源保留。
    await tapVisible(tester, '返回');

    expect(controller.state, isA<ImportSourceSelect>());
    expect(controller.source, ImportSource.screenshot);
    expect(tempStore.cleared, contains('temp/originals/shot.png'));
    expect(tempStore.cleared, isNot(contains('originals/shot.png')));
    expect(store.saved, isNull);

    // “重选来源”清空来源回到卡片选择。
    await tester.tap(find.text('重选来源'));
    await tester.pumpAndSettle();
    expect(controller.source, isNull);
  });
}
