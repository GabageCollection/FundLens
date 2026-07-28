import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/app/app_shell.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/selection_state.dart';
import 'package:fundlens_windows/features/holdings/holding_editor_dialog.dart';
import 'package:fundlens_windows/features/overview/overview_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

import '../features/import_review/import_review_harness.dart';

Widget shellHarness() {
  return MaterialApp(
    theme: FundLensTheme.light,
    home: AppShell(
      pages: [
        for (final destination in AppDestination.values)
          Center(child: Text('page-${destination.name}')),
      ],
    ),
  );
}

Future<void> pumpAt(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1280, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Holding _holding(String id, AssetClass assetClass, String value) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.manual,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: '测试产品$id',
    currency: 'CNY',
    currentValue: DecimalValue.parse(value),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

double _contrastRatio(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  final l1 = luminance(a);
  final l2 = luminance(b);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  testWidgets('Ctrl+1..6 reaches all six destinations', (tester) async {
    await pumpAt(tester, shellHarness());
    for (var i = 0; i < AppDestination.values.length; i++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(
        LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.text('page-${AppDestination.values[i].name}'),
        findsOneWidget,
        reason: 'Ctrl+${i + 1} should show ${AppDestination.values[i].name}',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape closes the holding editor dialog', (tester) async {
    await pumpAt(
      tester,
      MaterialApp(
        theme: FundLensTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showHoldingEditorDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Escape clears the spectrum selection', (tester) async {
    late ProviderContainer container;
    await pumpAt(
      tester,
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(
            FakeHoldingRepository([
              _holding('e1', AssetClass.equity, '600'),
              _holding('f1', AssetClass.fixedIncome, '400'),
            ]),
          ),
          portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
          dataQualityCalculatorProvider
              .overrideWithValue(DataQualityCalculator()),
        ],
        child: MaterialApp(
          theme: FundLensTheme.light,
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const OverviewPage();
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('spectrum-equity')));
    await tester.pumpAndSettle();
    expect(container.read(selectedAssetClassProvider), AssetClass.equity);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(container.read(selectedAssetClassProvider), isNull);
  });

  testWidgets('arrow keys move spectrum focus and Enter selects',
      (tester) async {
    late ProviderContainer container;
    await pumpAt(
      tester,
      ProviderScope(
        overrides: [
          holdingRepositoryProvider.overrideWithValue(
            FakeHoldingRepository([
              _holding('e1', AssetClass.equity, '600'),
              _holding('f1', AssetClass.fixedIncome, '400'),
            ]),
          ),
          portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
          dataQualityCalculatorProvider
              .overrideWithValue(DataQualityCalculator()),
        ],
        child: MaterialApp(
          theme: FundLensTheme.light,
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const OverviewPage();
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('spectrum-equity')));
    await tester.pumpAndSettle();
    expect(container.read(selectedAssetClassProvider), AssetClass.equity);

    // Segments are ordered by AssetClass.values: equity precedes fixedIncome.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(container.read(selectedAssetClassProvider), AssetClass.fixedIncome);
  });

  test('focus indicator colors meet 3:1 contrast on their surfaces', () {
    // Sidebar focus ring: Surface on warm-black sidebar.
    expect(
      _contrastRatio(FundLensTokens.surface, FundLensTokens.sidebar),
      greaterThanOrEqualTo(3.0),
    );
    // Spectrum focus outline: Terracotta accent on card surface.
    expect(
      _contrastRatio(FundLensTokens.accent, FundLensTokens.surface),
      greaterThanOrEqualTo(3.0),
    );
  });
}
