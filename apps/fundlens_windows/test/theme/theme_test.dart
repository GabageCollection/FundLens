import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

void main() {
  test('financial semantic colors follow the approved China convention', () {
    expect(FundLensTokens.profit, const Color(0xFFC54B40));
    expect(FundLensTokens.loss, const Color(0xFF2E8162));
  });

  test('base tokens match the fixed palette', () {
    expect(FundLensTokens.graphite, const Color(0xFF121817));
    expect(FundLensTokens.frost, const Color(0xFFF2F5F3));
    expect(FundLensTokens.paper, const Color(0xFFFFFFFF));
    expect(FundLensTokens.lensIndigo, const Color(0xFF625BD4));
    expect(FundLensTokens.navWidth, 224);
  });

  test('light theme uses Frost scaffold, Paper surfaces and Graphite text', () {
    final theme = FundLensTheme.light;
    expect(theme.scaffoldBackgroundColor, FundLensTokens.frost);
    expect(theme.colorScheme.surface, FundLensTokens.paper);
    expect(theme.textTheme.bodyMedium?.color, FundLensTokens.graphite);
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

  test('dividers are 1px and radii are 4/8px with no broad elevation shadows', () {
    final theme = FundLensTheme.light;
    expect(theme.dividerTheme.thickness, 1);
    expect(theme.cardTheme.elevation, 0);
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(8));
  });
}
