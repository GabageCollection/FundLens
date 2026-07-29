import 'package:flutter/material.dart';

import 'fundlens_tokens.dart';

/// Extra text styles that have no slot in [TextTheme].
@immutable
class FundLensTextStyles extends ThemeExtension<FundLensTextStyles> {
  const FundLensTextStyles({
    required this.financialNumber,
    required this.sectionTitle,
  });

  /// Monospace figures for amounts, shares and other financial values.
  final TextStyle financialNumber;

  /// Serif section heading (`.h-section` in the design system), 17px w600.
  final TextStyle sectionTitle;

  @override
  FundLensTextStyles copyWith({
    TextStyle? financialNumber,
    TextStyle? sectionTitle,
  }) {
    return FundLensTextStyles(
      financialNumber: financialNumber ?? this.financialNumber,
      sectionTitle: sectionTitle ?? this.sectionTitle,
    );
  }

  @override
  FundLensTextStyles lerp(FundLensTextStyles? other, double t) {
    if (other == null) return this;
    return FundLensTextStyles(
      financialNumber:
          TextStyle.lerp(financialNumber, other.financialNumber, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
    );
  }
}

abstract final class FundLensTheme {
  static ThemeData get light {
    const textTheme = TextTheme(
      titleLarge: TextStyle(
        fontFamily: 'Noto Serif SC',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: FundLensTokens.ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 14,
        color: FundLensTokens.ink,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 12,
        color: FundLensTokens.muted,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Noto Sans SC',
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: FundLensTokens.ink,
      ),
    );

    const colorScheme = ColorScheme.light(
      primary: FundLensTokens.accentStrong,
      onPrimary: Color(0xFFFFFFFF),
      surface: FundLensTokens.surface,
      onSurface: FundLensTokens.ink,
      // Error semantics intentionally reuse the profit red family: blocking
      // data issues render as the design system's `chip.bad` styling.
      error: FundLensTokens.profit,
      onError: Color(0xFFFFFFFF),
      errorContainer: FundLensTokens.profitSoft,
      onErrorContainer: FundLensTokens.profit,
      outline: FundLensTokens.border,
      outlineVariant: FundLensTokens.borderStrong,
      surfaceContainerHighest: FundLensTokens.surfaceAlt,
    );

    final shapeSmall = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FundLensTokens.canvas,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: FundLensTokens.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: FundLensTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusLarge),
          side: const BorderSide(color: FundLensTokens.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusMedium),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: FundLensTokens.ink,
          borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
        ),
      ),
      focusColor: FundLensTokens.accent.withValues(alpha: 0.16),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FundLensTokens.accentStrong,
          foregroundColor: const Color(0xFFFFFFFF),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          shape: shapeSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FundLensTokens.ink,
          side: const BorderSide(color: FundLensTokens.borderStrong),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          shape: shapeSmall,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? FundLensTokens.ink
                : FundLensTokens.muted,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? FundLensTokens.surface
                : FundLensTokens.surfaceAlt,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: FundLensTokens.border),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide.none,
        labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FundLensTokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
          borderSide: const BorderSide(color: FundLensTokens.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
          borderSide: const BorderSide(color: FundLensTokens.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
          borderSide: const BorderSide(
            color: FundLensTokens.accent,
            width: 2,
          ),
        ),
      ),
      extensions: const [
        FundLensTextStyles(
          financialNumber: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 14,
            color: FundLensTokens.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          sectionTitle: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: FundLensTokens.ink,
          ),
        ),
      ],
    );
  }
}
