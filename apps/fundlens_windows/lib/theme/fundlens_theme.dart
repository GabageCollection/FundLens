import 'package:flutter/material.dart';

import 'fundlens_tokens.dart';

/// [TextTheme] 之外的设计系统文字样式。
@immutable
class FundLensTextStyles extends ThemeExtension<FundLensTextStyles> {
  const FundLensTextStyles({
    required this.financialNumber,
    required this.sectionTitle,
    required this.kpiNumber,
  });

  /// 表格金额等金融数字:14px、等宽、tabular-nums。
  final TextStyle financialNumber;

  /// 区块标题:宋体 18px / 行高 26 / w600。
  final TextStyle sectionTitle;

  /// KPI 大数字:等宽 22px(KPI 允许 20–24px 区间)。
  final TextStyle kpiNumber;

  @override
  FundLensTextStyles copyWith({
    TextStyle? financialNumber,
    TextStyle? sectionTitle,
    TextStyle? kpiNumber,
  }) {
    return FundLensTextStyles(
      financialNumber: financialNumber ?? this.financialNumber,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      kpiNumber: kpiNumber ?? this.kpiNumber,
    );
  }

  @override
  FundLensTextStyles lerp(FundLensTextStyles? other, double t) {
    if (other == null) return this;
    return FundLensTextStyles(
      financialNumber: TextStyle.lerp(
        financialNumber,
        other.financialNumber,
        t,
      )!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      kpiNumber: TextStyle.lerp(kpiNumber, other.kpiNumber, t)!,
    );
  }
}

/// FundLens 暖墨主题。字体层级与组件尺寸以设计系统规范为准:
/// 页面标题 24/32、区块标题 18/26、正文 14/22、辅助 12/18;
/// 按钮与输入框高 40,卡片圆角 12、1px 边框、无阴影。
abstract final class FundLensTheme {
  static ThemeData get light {
    const textTheme = TextTheme(
      // 页面标题:24px / 行高 32 / w600,中文保留克制的宋体气质。
      titleLarge: TextStyle(
        fontFamily: 'Noto Serif SC',
        fontWeight: FontWeight.w600,
        fontSize: 24,
        height: 32 / 24,
        color: FundLensTokens.ink,
      ),
      // 正文:14px / 行高 22,清晰的无衬线。
      bodyMedium: TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 14,
        height: 22 / 14,
        color: FundLensTokens.ink,
      ),
      // 辅助文字:12px / 行高 18,说明文字不得小于 12px。
      bodySmall: TextStyle(
        fontFamily: 'Noto Sans SC',
        fontSize: 12,
        height: 18 / 12,
        color: FundLensTokens.muted,
      ),
      // 控件标签(按钮等):14px。
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
      // 错误语义复用盈利红家族:阻塞性数据问题以 chip.bad 样式呈现。
      error: FundLensTokens.profit,
      onError: Color(0xFFFFFFFF),
      errorContainer: FundLensTokens.profitSoft,
      onErrorContainer: FundLensTokens.profit,
      outline: FundLensTokens.border,
      outlineVariant: FundLensTokens.borderStrong,
      surfaceContainerHighest: FundLensTokens.surfaceAlt,
    );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
    );

    /// 键盘 Focus:清晰的 2px 主色轮廓。
    const focusSide = WidgetStateBorderSide.fromMap({
      WidgetState.focused: BorderSide(
        color: FundLensTokens.accent,
        width: FundLensTokens.focusOutlineWidth,
      ),
    });

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
      // 普通卡片:1px 浅色边框、圆角 12、无阴影。
      cardTheme: CardThemeData(
        color: FundLensTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
          side: FundLensTokens.cardBorder,
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
      // 主按钮:高 40,圆角 8,禁用态使用 disabled 灰。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FundLensTokens.accentStrong,
          foregroundColor: const Color(0xFFFFFFFF),
          disabledBackgroundColor: FundLensTokens.disabled,
          disabledForegroundColor: const Color(0xFFFFFFFF),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          minimumSize: const Size(64, FundLensTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: FundLensTokens.space4,
          ),
          shape: controlShape,
        ).copyWith(side: focusSide),
      ),
      // 次按钮:高 40,1px 边框。
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FundLensTokens.ink,
          disabledForegroundColor: FundLensTokens.disabled,
          side: const BorderSide(color: FundLensTokens.borderStrong),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          minimumSize: const Size(64, FundLensTokens.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: FundLensTokens.space4,
          ),
          shape: controlShape,
        ).copyWith(side: focusSide),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FundLensTokens.accentStrong,
          disabledForegroundColor: FundLensTokens.disabled,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          minimumSize: const Size(64, FundLensTokens.buttonHeight),
          shape: controlShape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
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
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      // 输入框:高 40,常态 1px 边框,Focus 2px 主色轮廓。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FundLensTokens.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FundLensTokens.space3,
          vertical: 9,
        ),
        constraints: const BoxConstraints(
          minHeight: FundLensTokens.inputHeight,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
          borderSide: const BorderSide(color: FundLensTokens.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
          borderSide: const BorderSide(color: FundLensTokens.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
          borderSide: const BorderSide(
            color: FundLensTokens.accent,
            width: FundLensTokens.focusOutlineWidth,
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
            fontSize: 18,
            height: 26 / 18,
            color: FundLensTokens.ink,
          ),
          kpiNumber: TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: FundLensTokens.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
