import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/features/import_review/screenshot_crop_view.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

import 'import_review_harness.dart';

void main() {
  testWidgets('导入页使用 form 档 PageScaffold', (tester) async {
    await pumpImportHarness(tester);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.form);
    expect(find.text('导入与识别'), findsOneWidget);
  });

  testWidgets('screenshot import defaults to partial mode', (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    final controller =
        await pumpImportHarness(tester, engine: engine, picker: picker);

    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();

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
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    await pumpImportHarness(tester, engine: engine, picker: picker);

    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认写入'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('field selection shows its source crop', (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    await pumpImportHarness(tester, engine: engine, picker: picker);

    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('78,347.87'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('ocr-crop-current_value')),
      findsOneWidget,
    );
  });

  testWidgets('窄屏(<960)编辑态走堆叠路径:裁剪区固定高 320 且无溢出',
      (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      picker: picker,
      size: const Size(800, 900),
    );

    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportEditing>());
    // 窄屏堆叠路径生效:裁剪区与编辑列在统一滚动容器内纵向排列。
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.getSize(find.byType(ScreenshotCropView)).height, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CSV import parses rows and shows the diff', (tester) async {
    final picker = FakeImportFilePicker()
      ..csvFile = csvPickedFile('产品名称,当前金额\n重合基金,1000.00\n');
    final controller = await pumpImportHarness(tester, picker: picker);

    await tester.tap(find.text('导入 CSV'));
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportEditing>());
    expect(find.textContaining('新增 1 条'), findsOneWidget);
    expect(find.text('部分持仓'), findsOneWidget);
  });

  testWidgets('cancelling the picker keeps the idle state', (tester) async {
    final controller = await pumpImportHarness(tester);

    await tester.tap(find.text('导入 CSV'));
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportIdle>());
    expect(find.text('导入 CSV'), findsOneWidget);
    expect(find.text('确认写入'), findsNothing);
  });

  testWidgets('uncommitted draft is restored after a restart', (tester) async {
    final store = InMemoryImportDraftStore();
    final picker = FakeImportFilePicker()
      ..csvFile = csvPickedFile('产品名称,当前金额\n重合基金,1000.00\n');
    await pumpImportHarness(tester, picker: picker, draftStore: store);

    await tester.tap(find.text('导入 CSV'));
    await tester.pumpAndSettle();
    expect(store.saved, isNotNull);

    final restarted = ImportReviewController(
      engine: FakeDataEngineClient(),
      repository: FakeHoldingRepository(),
      picker: FakeImportFilePicker(),
      tempStore: FakeScreenshotTempStore(),
      draftStore: store,
    );
    await restarted.restore();
    expect(restarted.state, isA<ImportEditing>());
    final editing = restarted.state as ImportEditing;
    expect(editing.draft.holdings.single.productName, '重合基金');

    await pumpImportHarness(tester, controller: restarted);
    await tester.pumpAndSettle();
    expect(find.textContaining('新增 1 条'), findsOneWidget);
  });

  testWidgets(
      'partial commit keeps unmatched holdings and clears only temp copies',
      (tester) async {
    final repository = FakeHoldingRepository([existingHolding()]);
    final tempStore = FakeScreenshotTempStore();
    final store = InMemoryImportDraftStore();
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] =
          alipayOcrResponse(productName: '新基金');
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      repository: repository,
      picker: picker,
      tempStore: tempStore,
      draftStore: store,
    );

    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportCommitted>());
    expect(repository.holdings.map((h) => h.id), contains('keep-1'));
    expect(repository.holdings.length, 2);
    expect(tempStore.cleared, ['temp/originals/shot.png']);
    expect(tempStore.cleared, isNot(contains('originals/shot.png')));
    expect(store.saved, isNull);
  });

  testWidgets('full mode warns and requires a second confirmation naming the '
      'removal count', (tester) async {
    final repository = FakeHoldingRepository([existingHolding()]);
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] =
          alipayOcrResponse(productName: '新基金');
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      repository: repository,
      picker: picker,
    );

    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全量持仓'));
    await tester.pumpAndSettle();

    expect(find.textContaining('可能移除 1 条'), findsOneWidget);
    expect(find.textContaining('全量导入将移除不再出现的持仓'), findsOneWidget);

    await tester.tap(find.text('确认写入'));
    await tester.pumpAndSettle();

    // Not committed yet: a second confirmation lists the removal count.
    expect(find.textContaining('将移除 1 条持仓'), findsOneWidget);
    expect(repository.holdings.map((h) => h.id), contains('keep-1'));

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('确认'),
    ));
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportCommitted>());
    expect(repository.holdings.map((h) => h.id), isNot(contains('keep-1')));
  });

  testWidgets('product candidates require an explicit radio selection',
      (tester) async {
    final repository = FakeHoldingRepository([
      existingHolding(
          id: 'ths-1', name: '重合基金', platform: SourcePlatform.ths),
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
    final picker = FakeImportFilePicker()
      ..csvFile = csvPickedFile('产品名称,当前金额\n重合基金,1000.00\n');
    await pumpImportHarness(
      tester,
      engine: engine,
      repository: repository,
      picker: picker,
    );

    await tester.tap(find.text('导入 CSV'));
    await tester.pumpAndSettle();

    expect(engine.calls, contains('product.match_candidates'));
    expect(find.byType(RadioListTile<int>), findsNWidgets(2));
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认写入'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(RadioListTile<int>).first);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认写入'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('discard clears temp copies but never the original files',
      (tester) async {
    final tempStore = FakeScreenshotTempStore();
    final store = InMemoryImportDraftStore();
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
      ];
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      picker: picker,
      tempStore: tempStore,
      draftStore: store,
    );

    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(controller.state, isA<ImportIdle>());
    expect(tempStore.cleared, ['temp/originals/shot.png']);
    expect(tempStore.cleared, isNot(contains('originals/shot.png')));
    expect(store.saved, isNull);
  });
}
