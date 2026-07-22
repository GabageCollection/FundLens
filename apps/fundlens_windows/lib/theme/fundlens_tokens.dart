import 'package:flutter/material.dart';

/// Fixed design tokens for the FundLens Asset Spectrum desktop UI.
abstract final class FundLensTokens {
  static const graphite = Color(0xFF121817);
  static const frost = Color(0xFFF2F5F3);
  static const paper = Color(0xFFFFFFFF);
  static const lensIndigo = Color(0xFF625BD4);

  /// China convention: profit is red, loss is green. Always pair with +/-.
  static const profit = Color(0xFFC54B40);
  static const loss = Color(0xFF2E8162);

  static const divider = Color(0xFFDDE3DF);
  static const muted = Color(0xFF65706C);

  static const double navWidth = 224;
  static const double pagePadding = 28;
  static const double rowHeight = 56;

  static const double radiusSmall = 4;
  static const double radiusMedium = 8;
}
