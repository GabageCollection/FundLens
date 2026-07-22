import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_editor_dialog.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

Widget editorHarness({
  Holding? initial,
  void Function(Holding holding)? onSubmit,
}) {
  return MaterialApp(
    theme: FundLensTheme.light,
    home: HoldingEditorDialog(initial: initial, onSubmit: onSubmit),
  );
}

Holding fixtureHolding({String id = 'h-1', String name = '测试基金'}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.manual,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: name,
    currency: 'CNY',
    currentValue: DecimalValue.parse('1000.00'),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('manual editor requires name and current amount', (tester) async {
    await tester.pumpWidget(editorHarness());
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('请输入产品名称'), findsOneWidget);
    expect(find.text('请输入当前金额'), findsOneWidget);
  });

  testWidgets('invalid decimal input shows a field-level error', (tester) async {
    await tester.pumpWidget(editorHarness());
    await tester.enterText(
      find.widgetWithText(TextFormField, '产品名称'),
      '测试产品',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '当前金额'),
      'abc',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(find.text('金额格式不正确'), findsOneWidget);
  });

  testWidgets('submit emits a full manual holding with user-corrected provenance',
      (tester) async {
    Holding? submitted;
    await tester.pumpWidget(editorHarness(onSubmit: (h) => submitted = h));

    await tester.enterText(
      find.widgetWithText(TextFormField, '产品名称'),
      '招商银行活期',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '当前金额'),
      '5000.50',
    );
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(submitted, isNotNull);
    expect(submitted!.productName, '招商银行活期');
    expect(submitted!.currentValue, DecimalValue.parse('5000.50'));
    expect(submitted!.dataOrigin, DataOrigin.manual);
    expect(submitted!.sourcePlatform, SourcePlatform.manual);
    expect(
      submitted!.fieldProvenance['productName']?.kind,
      ProvenanceKind.userCorrected,
    );
    expect(
      submitted!.fieldProvenance['currentValue']?.kind,
      ProvenanceKind.userCorrected,
    );
    expect(submitted!.valuationMethod, ValuationMethod.manualAmount);
  });

  testWidgets('delete confirmation names the product', (tester) async {
    var confirmed = false;
    final holding = fixtureHolding(name: '易方达蓝筹精选');
    await tester.pumpWidget(MaterialApp(
      theme: FundLensTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              confirmed = await showHoldingDeleteConfirmation(context, holding);
            },
            child: const Text('触发删除'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('触发删除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('易方达蓝筹精选'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
