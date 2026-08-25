import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/overview/overview_formatters.dart';
import 'package:fundlens_windows/features/settings/appearance_section.dart';
import 'package:fundlens_windows/features/settings/persisted_settings.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/animated_amount_text.dart';
import 'package:fundlens_windows/widgets/skeleton_view.dart';

void main() {
  group('AnimatedAmountText', () {
    testWidgets('shows the final value immediately on first build', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FundLensTheme.light,
          home: Scaffold(
            body: AnimatedAmountText(
              value: DecimalValue.parse('123456.78'),
              format: formatCurrency,
              interpolateFormat: formatCurrencyDouble,
            ),
          ),
        ),
      );
      expect(find.text('¥123,456.78'), findsOneWidget);
    });

    testWidgets('animates to the new value when the value changes', (tester) async {
      var value = DecimalValue.parse('100.00');
      late StateSetter setter;
      await tester.pumpWidget(
        MaterialApp(
          theme: FundLensTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setter = setState;
                return AnimatedAmountText(
                  value: value,
                  format: formatCurrency,
                  interpolateFormat: formatCurrencyDouble,
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('¥100.00'), findsOneWidget);

      setter(() => value = DecimalValue.parse('200.00'));
      await tester.pump(); // animation starts
      await tester.pump(const Duration(milliseconds: 400)); // animation done
      expect(find.text('¥200.00'), findsOneWidget);
    });

    testWidgets('no animation when system reduce-motion is on', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() =>
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue());
      var value = DecimalValue.parse('100.00');
      late StateSetter setter;
      await tester.pumpWidget(
        MaterialApp(
          theme: FundLensTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setter = setState;
                return AnimatedAmountText(
                  value: value,
                  format: formatCurrency,
                  interpolateFormat: formatCurrencyDouble,
                );
              },
            ),
          ),
        ),
      );
      setter(() => value = DecimalValue.parse('200.00'));
      await tester.pump();
      // 立即显示终值,无中间帧。
      expect(find.text('¥200.00'), findsOneWidget);
    });
  });

  group('SkeletonView', () {
    testWidgets('exposes a live-region semantics label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FundLensTheme.light,
          home: const Scaffold(body: SkeletonView(label: '正在加载资产总览…')),
        ),
      );
      expect(
        tester.getSemantics(find.byType(SkeletonView)),
        matchesSemantics(label: '正在加载资产总览…', isLiveRegion: true),
      );
    });
  });

  group('AppearanceSection', () {
    testWidgets('switching theme mode and density updates providers',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: FundLensTheme.light,
            home: const Scaffold(body: AppearanceSection()),
          ),
        ),
      );

      expect(container.read(themeModeProvider), ThemeModePreference.system);
      await tester.tap(find.text('深色'));
      await tester.pump();
      expect(container.read(themeModeProvider), ThemeModePreference.dark);

      expect(container.read(tableDensityProvider), TableDensity.comfortable);
      await tester.tap(find.text('紧凑'));
      await tester.pump();
      expect(container.read(tableDensityProvider), TableDensity.compact);
    });
  });
}