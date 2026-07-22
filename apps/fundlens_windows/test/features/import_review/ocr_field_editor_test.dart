import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';

import 'import_review_harness.dart';

Future<void> pumpScreenshotSession(
  WidgetTester tester, {
  required FakeDataEngineClient engine,
}) async {
  final picker = FakeImportFilePicker()
    ..screenshots = const [
      PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
    ];
  await pumpImportHarness(tester, engine: engine, picker: picker);
  await tester.tap(find.text('导入截图'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('OCR fields show confidence badges and provenance',
      (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse();
    await pumpScreenshotSession(tester, engine: engine);

    expect(find.textContaining('置信度 87%'), findsOneWidget);
    expect(find.textContaining('截图 OCR'), findsWidgets);
    expect(find.textContaining('来源截图'), findsOneWidget);
  });

  testWidgets('editing a field clears its blocking issue and enables commit',
      (tester) async {
    final engine = FakeDataEngineClient()
      ..responses['ocr.parse_screenshots'] = alipayOcrResponse(
        currentValue: 'abc',
        rowIssues: [blockingIssueJson()],
        issues: [blockingIssueJson()],
      );
    final controller = await pumpImportHarness(tester,
        engine: engine,
        picker: FakeImportFilePicker()
          ..screenshots = const [
            PickedImportFile(name: 'shot.png', path: 'originals/shot.png'),
          ]);
    await tester.tap(find.text('导入截图'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认写入'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('ocr-field-current_value-0')),
      '100.50',
    );
    await tester.pumpAndSettle();

    final editing = controller.state as ImportEditing;
    expect(
      editing.draft.holdings.single.currentValue,
      DecimalValue.parse('100.50'),
    );
    expect(editing.draft.hasBlockingIssues, isFalse);
    expect(
      tester
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认写入'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('selecting a data issue focuses the matching field crop',
      (tester) async {
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

    await tester.tap(find.text('置信度较低，请核对'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ocr-crop-current_value')),
      findsOneWidget,
    );
  });
}
