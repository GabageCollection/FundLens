import 'package:flutter/material.dart';

import 'fundlens_tokens.dart';

/// 微交互动画时长:150ms(设计系统动效规范);系统开启"减少动画"时完全关闭。
Duration fundlensAnimationDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);

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
  /// 浅色暖墨主题。
  static ThemeData get light => _build(FundLensPalette.light);

  /// 深色暖墨主题:同一色相体系整体压暗,组件规格完全一致。
  static ThemeData get dark => _build(FundLensPalette.dark);

  static ThemeData _build(FundLensPalette palette) {
    // 主题构建前切换全局调色板,使下方 FundLensTokens 语义色读取
    // 都指向当前明暗实例。
    FundLensTokens.applyPalette(palette);
    final textTheme = TextTheme(
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

    final isDark = identical(palette, FundLensPalette.dark);
    final colorScheme = (isDark ? ColorScheme.dark : ColorScheme.light)(
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
    final focusSide = WidgetStateBorderSide.fromMap({
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
      dividerTheme: DividerThemeData(
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
      // 全局轻提示:暖墨深底、圆角 8,风格与画布一致。
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FundLensTokens.ink,
        contentTextStyle: const TextStyle(
          fontFamily: 'Noto Sans SC',
          fontSize: 14,
          color: Color(0xFFFFFFFF),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      // 加载指示统一主色,与视觉体系一致。
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: FundLensTokens.accent,
      ),
      // Hover/按压反馈:暖墨体系的极浅主色底,替代 Material 默认灰调。
      // 覆盖全部 InkWell/InkResponse/ListTile/按钮的默认态;表格行等
      // 自定义控件可用 FundLensTokens.hoverBackground 保持一致。
      hoverColor: FundLensTokens.hoverBackground,
      splashColor: FundLensTokens.accent.withValues(alpha: 0.10),
      highlightColor: FundLensTokens.accent.withValues(alpha: 0.05),
      // 桌面端滚动条:常驻细轨道,悬停加粗,让用户总能感知滚动位置。
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: const WidgetStatePropertyAll(true),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? 10 : 7,
        ),
        radius: const Radius.circular(FundLensTokens.radiusControl),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? FundLensTokens.muted
              : FundLensTokens.disabled,
        ),
        trackColor: WidgetStatePropertyAll(FundLensTokens.surfaceAlt),
        trackBorderColor: WidgetStatePropertyAll(FundLensTokens.border),
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
          side: BorderSide(color: FundLensTokens.borderStrong),
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
        ).copyWith(side: focusSide),
      ),
      // 图标按钮:同样落实 2px 主色 Focus 轮廓,与其他按钮一致。
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            FundLensTokens.minTapTarget,
            FundLensTokens.minTapTarget,
          ),
        ).copyWith(side: focusSide),
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
          side: WidgetStatePropertyAll(
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
          borderSide: BorderSide(color: FundLensTokens.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
          borderSide: BorderSide(color: FundLensTokens.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
          borderSide: BorderSide(
            color: FundLensTokens.accent,
            width: FundLensTokens.focusOutlineWidth,
          ),
        ),
        // 校验错误态:与盈利红同族(项目有意设计),边框与错误文字统一呈现。
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: FundLensTokens.focusOutlineWidth,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: FundLensTokens.focusOutlineWidth,
          ),
        ),
        errorStyle: TextStyle(
          fontFamily: 'Noto Sans SC',
          fontSize: 12,
          color: FundLensTokens.profit,
        ),
      ),
      extensions: [
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
