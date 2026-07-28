import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

/// Fixed design tokens for the FundLens warm-ink desktop UI.
///
/// Values mirror the approved Open Design system (`assets/fundlens.css`):
/// parchment canvas, terracotta accent, serif display type. Financial
/// semantics follow the China convention — profit is red, loss is green —
/// and every signed figure must also carry an explicit `+`/`-` sign.
abstract final class FundLensTokens {
  // ---- Surfaces ----
  /// Parchment app canvas.
  static const canvas = Color(0xFFF5F3EC);

  /// Card surface.
  static const surface = Color(0xFFFFFDF8);

  /// Secondary surface: table headers, share-bar tracks.
  static const surfaceAlt = Color(0xFFFAF8F1);

  // ---- Text ----
  /// Primary text (warm ink).
  static const ink = Color(0xFF24211B);
  static const inkSoft = Color(0xFF4C4639);

  /// Auxiliary text; keeps ≥4.5:1 contrast on canvas/surface.
  static const muted = Color(0xFF6E675A);

  // ---- Borders ----
  static const border = Color(0xFFE5E0D1);
  static const borderStrong = Color(0xFFD5CFBC);

  // ---- Terracotta accent ----
  /// Graphics and large-area emphasis (charts, spectrum highlights).
  static const accent = Color(0xFFC4603E);

  /// Text-level accent and primary button fill; contrast-safe on surface.
  static const accentStrong = Color(0xFFA94E30);

  /// Accent-tinted fill for selected rails and chips.
  static const accentSoft = Color(0xFFF6E4DA);

  // ---- Financial semantics (China convention: red profit, green loss) ----
  static const profit = Color(0xFFB6452F);
  static const profitSoft = Color(0xFFF8E7E1);
  static const loss = Color(0xFF2C6E50);
  static const lossSoft = Color(0xFFE2EFE8);

  // ---- Warning ----
  static const warn = Color(0xFF8A6416);
  static const warnSoft = Color(0xFFF6ECD4);

  // ---- Sidebar ----
  static const sidebar = Color(0xFF26221B);
  static const sidebarInk = Color(0xFFB6AD9C);
  static const sidebarActive = Color(0xFFA94E30);

  /// Decorative segment color per asset class. Colors are decorative only;
  /// class name, amount and share are always also presented as text.
  static const categoryColors = <AssetClass, Color>{
    AssetClass.cash: Color(0xFF8A8272),
    AssetClass.deposit: Color(0xFF3E7CB1),
    AssetClass.equity: Color(0xFFC4603E),
    AssetClass.fixedIncome: Color(0xFF2E7D5B),
    AssetClass.mixed: Color(0xFFC58A40),
    AssetClass.gold: Color(0xFFBFA134),
    AssetClass.other: Color(0xFFA9A294),
  };

  // ---- Layout ----
  static const double navWidth = 232;
  static const double pagePadding = 28;
  static const double rowHeight = 56;

  static const double radiusSmall = 6;
  static const double radiusMedium = 10;
  static const double radiusLarge = 14;

  /// Soft card shadow: `0 1px 2px` + `0 4px 16px` in ink at ~5-6% alpha.
  static final cardShadow = <BoxShadow>[
    BoxShadow(
      color: ink.withValues(alpha: 0.05),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: ink.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
