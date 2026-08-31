import 'package:flutter/material.dart';

import 'fundlens_tokens.dart';

/// 微交互动画时长:150ms(设计系统动效规范);系统开启"减少动画"时完全关闭。
Duration fundlensAnimationDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 150);

/// 设计系统唯一允许的字体族。组件一律使用这里的常量,
/// 不得散落 `'Noto Sans SC'` 之类的字符串字面量。
abstract final class FundLensFonts {
  /// 标题宋体(页面标题、区块标题)。
  static const String serif = 'Noto Serif SC';

  /// 正文黑体(正文、辅助、控件标签;全局默认字体)。
  static const String sans = 'Noto Sans SC';

  /// 数字等宽体(金额、比例、图表刻度;配 tabular-nums)。
  static const String mono = 'IBM Plex Mono';
}

/// [TextTheme] 之外的设计系统文字样式。全部字体的唯一来源:
/// 组件从这里(或 [TextTheme])取样式,只允许 copyWith 颜色等
/// 非排版属性,不得自行指定字体族、字号或字重。
@immutable
class FundLensTextStyles extends ThemeExtension<FundLensTextStyles> {
  const FundLensTextStyles({
    required this.sectionTitle,
    required this.subsectionTitle,
    required this.panelTitle,
    required this.sansEmphasis,
    required this.bodyStrong,
    required this.auxStrong,
    required this.chipLabel,
    required this.financialNumber,
    required this.financialNumberStrong,
    required this.financialEmphasis,
    required this.financialEmphasisSmall,
    required this.financialCaption,
    required this.kpiNumber,
  });

  /// 从上下文读取设计系统文字样式。
  static FundLensTextStyles of(BuildContext context) =>
      Theme.of(context).extension<FundLensTextStyles>()!;

  // ---- 标题(标题一律 w600) ----
  /// 区块标题:宋体 18px / 行高 26。
  final TextStyle sectionTitle;

  /// 子区块/卡片标题:宋体 16px / 行高 24。
  final TextStyle subsectionTitle;

  /// 弹层面板标题:黑体 16px / 行高 24。
  final TextStyle panelTitle;

  /// 黑体大强调 18px / 行高 24:[financialEmphasis] 的非数字回退。
  final TextStyle sansEmphasis;

  // ---- 正文与辅助(正文 regular,强调正文 w600,控件标签 w500) ----
  /// 强调正文:黑体 14px / 行高 22 / w600。
  final TextStyle bodyStrong;

  /// 强调辅助:黑体 12px / 行高 18 / w600(表头、步序号等)。
  final TextStyle auxStrong;

  /// 状态 chip 标签:黑体 12px / w500。
  final TextStyle chipLabel;

  // ---- 数字(等宽 + tabular-nums) ----
  /// 表格金额等金融数字:14px。
  final TextStyle financialNumber;

  /// 强调金融数字:14px / w600。
  final TextStyle financialNumberStrong;

  /// 汇总卡片大数值:18px / w600。
  final TextStyle financialEmphasis;

  /// 次大数值(图表环心等):16px / w600。
  final TextStyle financialEmphasisSmall;

  /// 图表刻度、图例与悬浮卡数值:12px(说明文字不得小于 12px)。
  final TextStyle financialCaption;

  /// KPI 大数字:22px / w600(KPI 允许 20–24px 区间)。
  final TextStyle kpiNumber;

  @override
  FundLensTextStyles copyWith({
    TextStyle? sectionTitle,
    TextStyle? subsectionTitle,
    TextStyle? panelTitle,
    TextStyle? sansEmphasis,
    TextStyle? bodyStrong,
    TextStyle? auxStrong,
    TextStyle? chipLabel,
    TextStyle? financialNumber,
    TextStyle? financialNumberStrong,
    TextStyle? financialEmphasis,
    TextStyle? financialEmphasisSmall,
    TextStyle? financialCaption,
    TextStyle? kpiNumber,
  }) {
    return FundLensTextStyles(
      sectionTitle: sectionTitle ?? this.sectionTitle,
      subsectionTitle: subsectionTitle ?? this.subsectionTitle,
      panelTitle: panelTitle ?? this.panelTitle,
      sansEmphasis: sansEmphasis ?? this.sansEmphasis,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      auxStrong: auxStrong ?? this.auxStrong,
      chipLabel: chipLabel ?? this.chipLabel,
      financialNumber: financialNumber ?? this.financialNumber,
      financialNumberStrong:
          financialNumberStrong ?? this.financialNumberStrong,
      financialEmphasis: financialEmphasis ?? this.financialEmphasis,
      financialEmphasisSmall:
          financialEmphasisSmall ?? this.financialEmphasisSmall,
      financialCaption: financialCaption ?? this.financialCaption,
      kpiNumber: kpiNumber ?? this.kpiNumber,
    );
  }

  @override
  FundLensTextStyles lerp(FundLensTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return FundLensTextStyles(
      sectionTitle: l(sectionTitle, other.sectionTitle),
      subsectionTitle: l(subsectionTitle, other.subsectionTitle),
      panelTitle: l(panelTitle, other.panelTitle),
      sansEmphasis: l(sansEmphasis, other.sansEmphasis),
      bodyStrong: l(bodyStrong, other.bodyStrong),
      auxStrong: l(auxStrong, other.auxStrong),
      chipLabel: l(chipLabel, other.chipLabel),
      financialNumber: l(financialNumber, other.financialNumber),
      financialNumberStrong: l(
        financialNumberStrong,
        other.financialNumberStrong,
      ),
      financialEmphasis: l(financialEmphasis, other.financialEmphasis),
      financialEmphasisSmall: l(
        financialEmphasisSmall,
        other.financialEmphasisSmall,
      ),
      financialCaption: l(financialCaption, other.financialCaption),
      kpiNumber: l(kpiNumber, other.kpiNumber),
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
        fontFamily: FundLensFonts.serif,
        fontWeight: FontWeight.w600,
        fontSize: 24,
        height: 32 / 24,
        color: FundLensTokens.ink,
      ),
      // 正文:14px / 行高 22,清晰的无衬线。
      bodyMedium: TextStyle(
        fontFamily: FundLensFonts.sans,
        fontSize: 14,
        height: 22 / 14,
        color: FundLensTokens.ink,
      ),
      // 辅助文字:12px / 行高 18,说明文字不得小于 12px。
      bodySmall: TextStyle(
        fontFamily: FundLensFonts.sans,
        fontSize: 12,
        height: 18 / 12,
        color: FundLensTokens.muted,
      ),
      // 控件标签(按钮等):14px。
      labelLarge: TextStyle(
        fontFamily: FundLensFonts.sans,
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
      // 全局默认字体:未显式指定样式的文字(含 TextTheme 其余槽位)
      // 一律回退到黑体,与正文保持一致。
      fontFamily: FundLensFonts.sans,
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
          fontFamily: FundLensFonts.sans,
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
        labelStyle: TextStyle(
          fontFamily: FundLensFonts.sans,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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
          fontFamily: FundLensFonts.sans,
          fontSize: 12,
          color: FundLensTokens.profit,
        ),
      ),
      extensions: [
        FundLensTextStyles(
          sectionTitle: TextStyle(
            fontFamily: FundLensFonts.serif,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            height: 26 / 18,
            color: FundLensTokens.ink,
          ),
          subsectionTitle: TextStyle(
            fontFamily: FundLensFonts.serif,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            height: 24 / 16,
            color: FundLensTokens.ink,
          ),
          panelTitle: TextStyle(
            fontFamily: FundLensFonts.sans,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            height: 24 / 16,
            color: FundLensTokens.ink,
          ),
          sansEmphasis: TextStyle(
            fontFamily: FundLensFonts.sans,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            height: 24 / 18,
            color: FundLensTokens.ink,
          ),
          bodyStrong: TextStyle(
            fontFamily: FundLensFonts.sans,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 22 / 14,
            color: FundLensTokens.ink,
          ),
          auxStrong: TextStyle(
            fontFamily: FundLensFonts.sans,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            height: 18 / 12,
            color: FundLensTokens.ink,
          ),
          chipLabel: TextStyle(
            fontFamily: FundLensFonts.sans,
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: FundLensTokens.ink,
          ),
          financialNumber: TextStyle(
            fontFamily: FundLensFonts.mono,
            fontSize: 14,
            color: FundLensTokens.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          financialNumberStrong: TextStyle(
            fontFamily: FundLensFonts.mono,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: FundLensTokens.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          financialEmphasis: TextStyle(
            fontFamily: FundLensFonts.mono,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: FundLensTokens.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          financialEmphasisSmall: TextStyle(
            fontFamily: FundLensFonts.mono,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: FundLensTokens.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          financialCaption: TextStyle(
            fontFamily: FundLensFonts.mono,
            fontSize: 12,
            color: FundLensTokens.ink,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          kpiNumber: TextStyle(
            fontFamily: FundLensFonts.mono,
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
