import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';

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
}
