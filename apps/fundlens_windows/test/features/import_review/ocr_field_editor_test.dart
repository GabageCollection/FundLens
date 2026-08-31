import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

import 'import_review_harness.dart';

/// Scrolls the button into view before tapping, because wizard bodies are
/// long `SingleChildScrollView`s and bottom actions can sit below the fold.
Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<ImportReviewController> pumpScreenshotSession(
  WidgetTester tester, {
  required FakeDataEngineClient engine,
}) async {
  final picker = FakeImportFilePicker()
    ..screenshots = const [
      PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
    ];
  final controller = await pumpImportHarness(
    tester,
    engine: engine,
    picker: picker,
  );
  await tester.tap(find.text('截图识别'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('选择截图'));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('OCR fields show confidence badges and provenance', (
    tester,
  ) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    final controller = await pumpScreenshotSession(tester, engine: engine);

    // 默认 0.87 置信度属于低置信 → 低置信徽标 + 来源 + 裁剪区。
    expect(find.textContaining('低置信 87%'), findsOneWidget);
    expect(find.textContaining('截图 OCR'), findsWidgets);
    expect(find.textContaining('来源截图'), findsOneWidget);
    expect(controller.state, isA<ImportOcrReview>());
  });

  testWidgets('editing a field clears its blocking issue and enables commit', (
    tester,
  ) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        currentValue: 'abc',
        rowIssues: [blockingIssueJson()],
        issues: [blockingIssueJson()],
      );
    final controller = await pumpScreenshotSession(tester, engine: engine);

    // 截图复核步直接编辑当前金额字段,阻断问题随之清除。
    await tester.enterText(
      find.byKey(const ValueKey('ocr-field-current_value-0')),
      '100.50',
    );
    await tester.pumpAndSettle();

    final review = controller.state as ImportOcrReview;
    expect(
      review.draft.holdings.single.currentValue,
      DecimalValue.parse('100.50'),
    );
    expect(review.draft.hasBlockingIssues, isFalse);

    await tapVisible(tester, '确认识别结果');

    expect(controller.state, isA<ImportCheck>());
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认导入'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('selecting a data issue focuses the matching field crop', (
    tester,
  ) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        rowIssues: const [
          <String, Object?>{
            'code': 'ocr.low_confidence',
            'field': 'current_value',
            'severity': 'warning',
            'message': '置信度较低，请核对',
            'holding_index': 0,
          },
        ],
      );
    await pumpScreenshotSession(tester, engine: engine);

    await tapVisible(tester, '确认识别结果');
    await tester.tap(find.text('置信度较低，请核对'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ocr-crop-current_value')),
      findsOneWidget,
    );
  });

  testWidgets('data issue entries name the holding and field location', (
    tester,
  ) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        rowIssues: const [
          <String, Object?>{
            'code': 'ocr.low_confidence',
            'field': 'current_value',
            'severity': 'warning',
            'message': '置信度较低，请核对',
            'holding_index': 0,
          },
        ],
      );
    await pumpScreenshotSession(tester, engine: engine);

    await tapVisible(tester, '确认识别结果');

    // 问题条目带定位:级别 · 持仓名称 · 字段中文名,点击即可跳转。
    expect(find.textContaining('警告 · 测试基金 · 当前金额'), findsOneWidget);
  });

  testWidgets('tapping a data issue jumps back and highlights the field', (
    tester,
  ) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        rowIssues: const [
          <String, Object?>{
            'code': 'ocr.low_confidence',
            'field': 'current_value',
            'severity': 'warning',
            'message': '置信度较低，请核对',
            'holding_index': 0,
          },
        ],
      );
    final controller = await pumpScreenshotSession(tester, engine: engine);

    await tapVisible(tester, '确认识别结果');
    await tester.tap(find.text('置信度较低，请核对'));
    await tester.pumpAndSettle();

    // 跳回截图复核步,出错字段用主色描边高亮。
    expect(controller.state, isA<ImportOcrReview>());
    // TextFormField 不外露 decoration,取其内部 TextField。
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('ocr-field-current_value-0')),
        matching: find.byType(TextField),
      ),
    );
    final border = field.decoration!.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide.width, FundLensTokens.focusOutlineWidth);
  });

  testWidgets('blocking issues are not duplicated across row/response levels', (
    tester,
  ) async {
    // 引擎把阻断问题在行级(无归属)与响应级(带归属)各发一份;
    // 复审界面只应显示一条。
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        currentValue: 'abc',
        rowIssues: [blockingIssueJson()],
        issues: [blockingIssueJson()],
      );
    await pumpScreenshotSession(tester, engine: engine);

    await tapVisible(tester, '确认识别结果');

    expect(find.text('字段无法解析为数字'), findsOneWidget);
  });

  testWidgets('response-level issues are offset per page when merging OCR pages', (
    tester,
  ) async {
    // 逐页调用引擎时,响应级 holding_index 是单页内的行号;第 2 页的
    // 阻断问题必须偏移到全局行号,否则错误地挂到前几页的持仓卡片上。
    final engine = FakeDataEngineClient()
      ..responseQueues['ocr.parse_screenshots'] = [
        alipayOcrResponse(productName: '基金一'),
        alipayOcrResponse(
          productName: '基金二',
          currentValue: 'abc',
          rowIssues: [blockingIssueJson()],
          issues: [blockingIssueJson()],
        ),
      ];
    final picker = FakeImportFilePicker()
      ..screenshots = const [
        PickedImportFile(name: 'p1.png', path: 'originals/p1.png'),
        PickedImportFile(name: 'p2.png', path: 'originals/p2.png'),
      ];
    final controller = await pumpImportHarness(
      tester,
      engine: engine,
      picker: picker,
    );
    await tester.tap(find.text('截图识别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择截图'));
    await tester.pumpAndSettle();

    final review = controller.state as ImportOcrReview;
    expect(review.draft.holdings.length, 2);
    // 第 2 页的阻断问题(OCR 阻断 + 金额不可解析补发)都必须归属全局行号 1。
    final blocking = review.draft.issues
        .where((i) => i.severity == IssueSeverity.blocking)
        .toList();
    expect(blocking, hasLength(2));
    expect(blocking.map((i) => i.holdingIndex), everyElement(1));

    // 错误归属时该提示会出现在第一张卡片(基金一)的字段下方。
    expect(find.text('字段无法解析为数字'), findsOneWidget);
  });

  testWidgets('deleting an OCR row keeps surviving cards on their own state', (
    tester,
  ) async {
    // 卡片 key 曾是位置号:删除一行后,下一行的卡片沿用被删行的
    // TextFormField 状态,名称显示串行(基金B 显示成 基金A)。
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = _twoRowOcrResponse();
    final controller = await pumpScreenshotSession(tester, engine: engine);

    expect(find.text('基金A'), findsOneWidget);
    expect(find.text('基金B'), findsOneWidget);

    await controller.removeOcrRow(0);
    await tester.pumpAndSettle();

    expect(find.text('基金A'), findsNothing);
    expect(find.text('基金B'), findsOneWidget);
    expect(find.text('2,000.00'), findsOneWidget);
    expect(find.text('1,000.00'), findsNothing);
  });
}

Map<String, Object?> _ocrRowJson(String name, String value) {
  return <String, Object?>{
    'index': 0,
    'page_index': 0,
    'fields': <String, Object?>{
      'product_name': ocrFieldJson('product_name', name, confidence: 0.98),
      'current_value': ocrFieldJson('current_value', value),
      'holding_profit': ocrFieldJson('holding_profit', '1.00', confidence: 0.95),
    },
    'normalized': <String, Object?>{
      'current_value': value.replaceAll(',', ''),
      'holding_profit': '1.00',
    },
    'issues': const <Object?>[],
  };
}

Map<String, Object?> _twoRowOcrResponse() {
  return <String, Object?>{
    'template': 'alipay',
    'rows': [_ocrRowJson('基金A', '1,000.00'), _ocrRowJson('基金B', '2,000.00')],
    'issues': const <Object?>[],
  };
}

