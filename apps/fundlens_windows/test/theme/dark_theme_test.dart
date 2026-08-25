import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  tearDown(() => FundLensTokens.applyPalette(FundLensPalette.light));

  group('FundLensTheme.dark', () {
    test('dark theme applies the dark palette', () {
      final theme = FundLensTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(FundLensTokens.canvas, FundLensPalette.dark.canvas);
      expect(theme.scaffoldBackgroundColor, FundLensPalette.dark.canvas);
      expect(theme.cardTheme.color, FundLensPalette.dark.surface);
    });

    test('light theme restores the light palette', () {
      FundLensTheme.dark;
      final theme = FundLensTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(FundLensTokens.canvas, FundLensPalette.light.canvas);
    });

    test('dark palette keeps red-profit/green-loss semantics', () {
      expect(FundLensPalette.dark.profit, isNot(FundLensPalette.dark.loss));
      // 深色主色在RGB三通道上都不低于浅色主色,保证深底对比度。
      expect(
        FundLensPalette.dark.accent.r,
        greaterThanOrEqualTo(FundLensPalette.light.accent.r),
      );
    });

    test('dark palette contrast meets WCAG AA for key pairs', () {
      final cases = <(String, Color, Color, double)>[
        ('ink/canvas', FundLensPalette.dark.ink, FundLensPalette.dark.canvas, 4.5),
        ('ink/surface', FundLensPalette.dark.ink, FundLensPalette.dark.surface, 4.5),
        ('muted/canvas', FundLensPalette.dark.muted, FundLensPalette.dark.canvas, 4.5),
        ('warnText/warnSoft', FundLensPalette.dark.warnText, FundLensPalette.dark.warnSoft, 4.5),
        ('profitText/profitSoft', FundLensPalette.dark.profitText, FundLensPalette.dark.profitSoft, 4.5),
        ('accentText/accentSoft', FundLensPalette.dark.accentText, FundLensPalette.dark.accentSoft, 4.5),
        ('sidebarMuted/sidebar', FundLensPalette.dark.sidebarMuted, FundLensPalette.dark.sidebar, 4.5),
        ('borderStrong/surface', FundLensPalette.dark.borderStrong, FundLensPalette.dark.surface, 3.0),
      ];
      for (final (name, fg, bg, need) in cases) {
        final ratio = _contrast(fg, bg);
        expect(ratio, greaterThanOrEqualTo(need),
            reason: '$name 对比度 ${ratio.toStringAsFixed(2)} 低于 $need');
      }
    });
  });
}