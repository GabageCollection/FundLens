import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

void main() {
  test('financial semantic colors follow the approved China convention', () {
    expect(FundLensTokens.profit, const Color(0xFFB84B34));
    expect(FundLensTokens.loss, const Color(0xFF19705D));
  });

  test('base tokens match the warm-ink palette', () {
    expect(FundLensTokens.canvas, const Color(0xFFF6F3EC));
    expect(FundLensTokens.surface, const Color(0xFFFFFDF8));
    expect(FundLensTokens.surfaceAlt, const Color(0xFFFAF8F1));
    expect(FundLensTokens.ink, const Color(0xFF292722));
    expect(FundLensTokens.inkSoft, const Color(0xFF4C4639));
    expect(FundLensTokens.muted, const Color(0xFF736E64));
    expect(FundLensTokens.border, const Color(0xFFE4DED1));
    expect(FundLensTokens.borderStrong, const Color(0xFF948E7F));
    expect(FundLensTokens.accent, const Color(0xFFB65233));
    expect(FundLensTokens.accentStrong, const Color(0xFFB65233));
    expect(FundLensTokens.accentSoft, const Color(0xFFF6E4DA));
    expect(FundLensTokens.warn, const Color(0xFFA66A16));
    expect(FundLensTokens.disabled, const Color(0xFFC9C5BC));
    expect(FundLensTokens.sidebar, const Color(0xFF27231D));
    expect(FundLensTokens.sidebarInk, const Color(0xFFB6AD9C));
    expect(FundLensTokens.sidebarActive, const Color(0xFFB65233));
    expect(FundLensTokens.navWidth, 216);
    expect(FundLensTokens.navRailWidth, 64);
    expect(FundLensTokens.navFullBreakpoint, 1280);
    expect(FundLensTokens.navDrawerBreakpoint, 768);
    expect(FundLensTokens.contentMaxStandard, 1440);
    expect(FundLensTokens.contentMaxDense, 1680);
    expect(FundLensTokens.contentMaxForm, 1120);
    expect(FundLensTokens.gridGutter, 16);
    expect(FundLensTokens.gridCollapseBelow, 960);
  });

  test('category colors cover all seven asset classes', () {
    expect(FundLensTokens.categoryColors.length, AssetClass.values.length);
    expect(
      FundLensTokens.categoryColors[AssetClass.cash],
      const Color(0xFF8A8272),
    );
    expect(
      FundLensTokens.categoryColors[AssetClass.deposit],
      const Color(0xFF3E7CB1),
    );
    expect(
      FundLensTokens.categoryColors[AssetClass.equity],
      const Color(0xFFB65233),
    );
    expect(
      FundLensTokens.categoryColors[AssetClass.fixedIncome],
      const Color(0xFF2E7D5B),
    );
    expect(
      FundLensTokens.categoryColors[AssetClass.mixed],
      const Color(0xFFC58A40),
    );
    expect(
      FundLensTokens.categoryColors[AssetClass.gold],
      const Color(0xFFBFA134),
    );
    expect(
      FundLensTokens.categoryColors[AssetClass.other],
      const Color(0xFFA9A294),
    );
  });

  test('light theme uses canvas scaffold, surface cards and ink text', () {
    final theme = FundLensTheme.light;
    expect(theme.scaffoldBackgroundColor, FundLensTokens.canvas);
    expect(theme.colorScheme.surface, FundLensTokens.surface);
    expect(theme.colorScheme.primary, FundLensTokens.accentStrong);
    expect(theme.textTheme.bodyMedium?.color, FundLensTokens.ink);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Noto Sans SC');
  });

  test('type scale follows the 24/18/14/12 hierarchy', () {
    final theme = FundLensTheme.light;
    expect(theme.textTheme.titleLarge?.fontFamily, 'Noto Serif SC');
    expect(theme.textTheme.titleLarge?.fontSize, 24);
    expect(theme.textTheme.titleLarge?.height, closeTo(32 / 24, 1e-9));
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
    expect(theme.textTheme.bodyMedium?.height, closeTo(22 / 14, 1e-9));
    expect(theme.textTheme.bodySmall?.fontSize, 12);
    expect(theme.textTheme.bodySmall?.height, closeTo(18 / 12, 1e-9));

    final styles = theme.extension<FundLensTextStyles>();
    expect(styles, isNotNull);
    expect(styles!.sectionTitle.fontSize, 18);
    expect(styles.sectionTitle.height, closeTo(26 / 18, 1e-9));
    expect(styles.financialNumber.fontFamily, 'IBM Plex Mono');
    expect(styles.financialNumber.fontSize, 14);
    expect(styles.financialNumber.fontFeatures, isNotEmpty);
    expect(styles.kpiNumber.fontSize, 22);
    expect(styles.kpiNumber.fontFeatures, isNotEmpty);
  });

  test('error color is defined separately from profit semantics', () {
    final theme = FundLensTheme.light;
    expect(theme.colorScheme.error, FundLensTokens.profit);
    expect(theme.colorScheme.errorContainer, FundLensTokens.profitSoft);
  });

  test(
    'dividers are 1px and cards use 12px radius with 1px border, no shadow',
    () {
      final theme = FundLensTheme.light;
      expect(theme.dividerTheme.thickness, 1);
      expect(theme.cardTheme.elevation, 0);
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      expect(shape.side.color, FundLensTokens.border);
      expect(shape.side.width, 1);
    },
  );

  test('radii follow the 6/8/10/12 scale', () {
    expect(FundLensTokens.radiusSmall, 6);
    expect(FundLensTokens.radiusControl, 8);
    expect(FundLensTokens.radiusMedium, 10);
    expect(FundLensTokens.radiusCard, 12);
  });

  test('buttons and inputs are 40px high with 2px focus outline', () {
    final theme = FundLensTheme.light;

    final filled = theme.filledButtonTheme.style!;
    expect(
      filled.minimumSize!.resolve({}),
      const Size(64, FundLensTokens.buttonHeight),
    );
    expect(FundLensTokens.buttonHeight, 40);
    final focusedSide = filled.side!.resolve({WidgetState.focused});
    expect(focusedSide?.width, FundLensTokens.focusOutlineWidth);
    expect(focusedSide?.color, FundLensTokens.accent);
    expect(
      filled.backgroundColor!.resolve({WidgetState.disabled}),
      FundLensTokens.disabled,
    );

    final outlined = theme.outlinedButtonTheme.style!;
    expect(
      outlined.minimumSize!.resolve({}),
      const Size(64, FundLensTokens.buttonHeight),
    );

    final input = theme.inputDecorationTheme;
    expect(input.constraints?.minHeight, FundLensTokens.inputHeight);
    expect(FundLensTokens.inputHeight, 40);
    final focused = input.focusedBorder! as OutlineInputBorder;
    expect(focused.borderSide.width, FundLensTokens.focusOutlineWidth);
    expect(focused.borderSide.color, FundLensTokens.accent);
  });

  test('semantic colors on their soft/canvas backgrounds meet WCAG AA', () {
    // 文字档颜色在小字/软底场景必须 ≥4.5:1;UI 组件边界 ≥3:1。
    double luminance(Color c) {
      // Flutter Color 的 r/g/b 通道已是 0.0–1.0。
      double f(double v) {
        return v <= 0.04045
            ? v / 12.92
            : pow((v + 0.055) / 1.055, 2.4).toDouble();
      }
      return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    double contrast(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      final lighter = la > lb ? la : lb;
      final darker = la > lb ? lb : la;
      return (lighter + 0.05) / (darker + 0.05);
    }

    final cases = <(String, Color, Color, double)>[
      ('warnText/warnSoft', FundLensTokens.warnText, FundLensTokens.warnSoft, 4.5),
      ('warnText/surface', FundLensTokens.warnText, FundLensTokens.surface, 4.5),
      ('warnText/canvas', FundLensTokens.warnText, FundLensTokens.canvas, 4.5),
      ('profitText/profitSoft', FundLensTokens.profitText, FundLensTokens.profitSoft, 4.5),
      ('accentText/accentSoft', FundLensTokens.accentText, FundLensTokens.accentSoft, 4.5),
      ('accentText/canvas', FundLensTokens.accentText, FundLensTokens.canvas, 4.5),
      ('sidebarMuted/sidebar', FundLensTokens.sidebarMuted, FundLensTokens.sidebar, 4.5),
      ('borderStrong/surface(UI 3:1)', FundLensTokens.borderStrong, FundLensTokens.surface, 3.0),
    ];
    for (final (name, fg, bg, need) in cases) {
      final ratio = contrast(fg, bg);
      expect(
        ratio,
        greaterThanOrEqualTo(need),
        reason: '$name 对比度 $ratio 低于 $need',
      );
    }
  });

  test('no text style in the scale is smaller than 12px', () {
    final theme = FundLensTheme.light;
    final styles = [
      theme.textTheme.displayLarge,
      theme.textTheme.displayMedium,
      theme.textTheme.displaySmall,
      theme.textTheme.headlineLarge,
      theme.textTheme.headlineMedium,
      theme.textTheme.headlineSmall,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.titleSmall,
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
      theme.chipTheme.labelStyle,
    ];
    for (final style in styles) {
      if (style?.fontSize != null) {
        expect(style!.fontSize, greaterThanOrEqualTo(12));
      }
    }
  });
}
