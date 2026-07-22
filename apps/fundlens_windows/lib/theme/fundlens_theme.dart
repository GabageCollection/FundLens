import 'package:flutter/material.dart';

import 'fundlens_tokens.dart';

/// Extra text styles that have no slot in [TextTheme].
@immutable
class FundLensTextStyles extends ThemeExtension<FundLensTextStyles> {
  const FundLensTextStyles({required this.financialNumber});

  /// Monospace figures for amounts, shares and other financial values.
  final TextStyle financialNumber;

  @override
  FundLensTextStyles copyWith({TextStyle? financialNumber}) {
    return FundLensTextStyles(
      financialNumber: financialNumber ?? this.financialNumber,
    );
  }

  @override
  FundLensTextStyles lerp(FundLensTextStyles? other, double t) {
    if (other == null) return this;
    return FundLensTextStyles(
      financialNumber: TextStyle.lerp(financialNumber, other.financialNumber, t)!,
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
        color: FundLensTokens.graphite,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 14,
        color: FundLensTokens.graphite,
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
        color: FundLensTokens.graphite,
      ),
    );

    const colorScheme = ColorScheme.light(
      primary: FundLensTokens.lensIndigo,
      onPrimary: FundLensTokens.paper,
      surface: FundLensTokens.paper,
      onSurface: FundLensTokens.graphite,
      error: FundLensTokens.profit,
      outline: FundLensTokens.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FundLensTokens.frost,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
        color: FundLensTokens.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: FundLensTokens.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusMedium),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusMedium),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: FundLensTokens.graphite,
          borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
        ),
      ),
      focusColor: FundLensTokens.lensIndigo.withValues(alpha: 0.16),
      extensions: const [
        FundLensTextStyles(
          financialNumber: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 14,
            color: FundLensTokens.graphite,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
