import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

void main() {
  test('financial semantic colors follow the approved China convention', () {
    expect(FundLensTokens.profit, const Color(0xFFB6452F));
    expect(FundLensTokens.loss, const Color(0xFF2C6E50));
  });

  test('base tokens match the warm-ink palette', () {
    expect(FundLensTokens.canvas, const Color(0xFFF5F3EC));
    expect(FundLensTokens.surface, const Color(0xFFFFFDF8));
    expect(FundLensTokens.surfaceAlt, const Color(0xFFFAF8F1));
    expect(FundLensTokens.ink, const Color(0xFF24211B));
    expect(FundLensTokens.inkSoft, const Color(0xFF4C4639));
    expect(FundLensTokens.muted, const Color(0xFF6E675A));
    expect(FundLensTokens.border, const Color(0xFFE5E0D1));
    expect(FundLensTokens.borderStrong, const Color(0xFFD5CFBC));
    expect(FundLensTokens.accent, const Color(0xFFC4603E));
    expect(FundLensTokens.accentStrong, const Color(0xFFA94E30));
    expect(FundLensTokens.accentSoft, const Color(0xFFF6E4DA));
    expect(FundLensTokens.sidebar, const Color(0xFF26221B));
    expect(FundLensTokens.sidebarInk, const Color(0xFFB6AD9C));
    expect(FundLensTokens.sidebarActive, const Color(0xFFA94E30));
    expect(FundLensTokens.navWidth, 232);
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
      const Color(0xFFC4603E),
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

  test('page titles use Noto Serif SC and financial numbers use IBM Plex Mono', () {
    final theme = FundLensTheme.light;
    expect(theme.textTheme.titleLarge?.fontFamily, 'Noto Serif SC');
    final styles = theme.extension<FundLensTextStyles>();
    expect(styles, isNotNull);
    expect(styles!.financialNumber.fontFamily, 'IBM Plex Mono');
    expect(styles.financialNumber.fontFeatures, isNotEmpty);
  });

  test('error color is defined separately from profit semantics', () {
    final theme = FundLensTheme.light;
    expect(theme.colorScheme.error, FundLensTokens.profit);
    expect(theme.colorScheme.errorContainer, FundLensTokens.profitSoft);
  });

  test('dividers are 1px and cards use 14px radius with 1px border', () {
    final theme = FundLensTheme.light;
    expect(theme.dividerTheme.thickness, 1);
    expect(theme.cardTheme.elevation, 0);
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(14));
    expect(shape.side.color, FundLensTokens.border);
    expect(shape.side.width, 1);
  });

  test('radii follow the 6/10/14 scale', () {
    expect(FundLensTokens.radiusSmall, 6);
    expect(FundLensTokens.radiusMedium, 10);
    expect(FundLensTokens.radiusLarge, 14);
  });
}
