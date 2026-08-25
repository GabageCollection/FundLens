import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

/// FundLens 暖墨设计系统的唯一设计变量来源。
///
/// 所有页面与组件必须使用这里的语义变量,不得在组件中散落硬编码的
/// 颜色、字号、间距、圆角或按钮尺寸。金融语义遵循国内习惯——红涨绿跌,
/// 但任何盈亏状态都必须同时提供 `+`/`-`、图标或文字,不能只依赖颜色。
abstract final class FundLensTokens {
  /// 当前生效的调色板;默认为浅色。由根组件按主题模式设置,
  /// 之后所有语义色读取都指向该调色板(调用点无需感知明暗)。
  static FundLensPalette _palette = FundLensPalette.light;

  /// 切换全局调色板。必须在构建 MaterialApp 之前调用。
  static void applyPalette(FundLensPalette palette) {
    _palette = palette;
  }

  /// 当前调色板(测试与主题构建使用)。
  static FundLensPalette get palette => _palette;

  // ---- 颜色:画布与表面 ----
  /// 页面背景(羊皮纸画布)。
  static Color get canvas => _palette.canvas;

  /// 卡片和表格背景。
  static Color get surface => _palette.surface;

  /// 次级表面:表头、占比条轨道、分组底色。
  static Color get surfaceAlt => _palette.surfaceAlt;

  // ---- 颜色:文字 ----
  /// 主要文字(暖墨)。
  static Color get ink => _palette.ink;

  /// 次级正文(表内说明、次级标签)。
  static Color get inkSoft => _palette.inkSoft;

  /// 辅助文字;在 canvas/surface 上保持 ≥4.5:1 对比度。
  static Color get muted => _palette.muted;

  // ---- 颜色:边框 ----
  /// 常规边框与分隔线。
  static Color get border => _palette.border;

  /// 强调边框:输入框常态、卡片 hover。深度满足 WCAG 1.4.11 非文本 3:1。
  static Color get borderStrong => _palette.borderStrong;

  // ---- 颜色:主色(陶土橙) ----
  /// 图形强调(图表、资产光谱高亮)。
  static Color get accent => _palette.accent;

  /// 主按钮填充与文字级强调;在 surface 上对比度安全。
  static Color get accentStrong => _palette.accentStrong;

  /// 主色浅底:选中导航、chip 底色。
  static Color get accentSoft => _palette.accentSoft;

  /// 主色文字档:比 [accent] 更深,用于在 accentSoft/canvas 上作正文文字,
  /// 保证 WCAG AA(≥4.5:1)。[accent] 本身用于图标、焦点轮廓与图形强调。
  static Color get accentText => _palette.accentText;

  // ---- 颜色:金融语义(国内习惯:红盈利、绿亏损) ----
  /// 上涨与盈利。
  static Color get profit => _palette.profit;
  static Color get profitSoft => _palette.profitSoft;

  /// 盈利文字档:用于 profitSoft 上的小字,对比度 ≥4.5:1。
  static Color get profitText => _palette.profitText;

  /// 下跌与亏损。
  static Color get loss => _palette.loss;
  static Color get lossSoft => _palette.lossSoft;

  // ---- 颜色:数据异常警告 ----
  static Color get warn => _palette.warn;
  static Color get warnSoft => _palette.warnSoft;

  /// 警示文字档:用于 warnSoft/surface/canvas 上的小字,对比度 ≥4.5:1。
  static Color get warnText => _palette.warnText;

  // ---- 颜色:禁用状态 ----
  static Color get disabled => _palette.disabled;

  /// 交互悬停底色:极浅的主色底,用于表格行、列表项、侧栏项的 hover。
  /// 比 [surfaceAlt] 更暖,辨识度来自色相而非阴影。
  static Color get hoverBackground => _palette.hoverBackground;

  // ---- 颜色:侧边栏 ----
  static Color get sidebar => _palette.sidebar;

  /// 侧边栏未选中文字。
  static Color get sidebarInk => _palette.sidebarInk;

  /// 侧边栏弱提示文字(分组标签、页脚次行),在 sidebar 上 ≥4.5:1。
  static Color get sidebarMuted => _palette.sidebarMuted;

  /// 侧边栏品牌字标。
  static Color get sidebarTitle => _palette.sidebarTitle;

  /// 侧边栏选中态(与主色一致)。
  static Color get sidebarActive => _palette.sidebarActive;

  /// 各资产类别的装饰段色。颜色仅作装饰,类别名称、金额与占比
  /// 必须同时以文字呈现。
  static Map<AssetClass, Color> get categoryColors => _palette.categoryColors;

  /// 图表用品牌暖墨系可区分色(陶土主色 + 浅陶土 + 金棕 + 深琥珀,
  /// 均取自暖墨体系且不读作灰色):堆叠比例条按段序取用,超过档数
  /// 时回退 [muted];条形图统一用 [accent],聚合"其他"行用 [muted]。
  static List<Color> get chartBarShades => _palette.chartBarShades;
  // ---- 间距体系(只允许这些值) ----
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  // ---- 布局:侧边栏 ----
  /// 完整侧边栏宽度。
  static const double navWidth = 216;

  /// 折叠态图标栏宽度。
  static const double navRailWidth = 64;

  /// ≥该宽度完整显示侧栏(逻辑像素)。
  static const double navFullBreakpoint = 1280;

  /// <该宽度切换为抽屉导航(逻辑像素)。
  static const double navDrawerBreakpoint = 768;

  // ---- 布局:正文容器最大宽度 ----
  /// 普通页面(总览、分析)。
  static const double contentMaxStandard = 1440;

  /// 数据密集页面(全部持仓、历史快照)。
  static const double contentMaxDense = 1680;

  /// 表单页面(设置、导入与识别),取 1040–1200 中间值。
  static const double contentMaxForm = 1120;

  // ---- 布局:12 列栅格 ----
  /// 栅格列间距。
  static const double gridGutter = 16;

  /// 容器低于该宽度时栅格降为单列堆叠。
  static const double gridCollapseBelow = 960;

  /// 页面外边距。
  static const double pagePadding = 24;

  /// 页面标题与内容间距。
  static const double titleGap = 24;

  /// 卡片内边距(大卡片可用 [space6] = 24)。
  static const double cardPadding = 20;

  /// 卡片间距。
  static const double cardGap = 16;

  /// 表单项纵向间距。
  static const double formGap = 16;

  /// 表格行高(48–56)。
  static const double rowHeight = 56;

  /// 紧凑密度表格行高(数据密集用户可选)。
  static const double rowHeightCompact = 44;

  // ---- 圆角 ----
  /// 小控件:chip、tooltip。
  static const double radiusSmall = 6;

  /// 胶囊形状态 chip(设计系统中唯一允许的胶囊圆角)。
  static const double radiusPill = 999;

  /// 表单控件:按钮、输入框。
  static const double radiusControl = 8;

  /// 对话框。
  static const double radiusMedium = 10;

  /// 卡片统一圆角 12px。
  static const double radiusCard = 12;

  // ---- 组件尺寸 ----
  /// 主按钮高度。
  static const double buttonHeight = 40;

  /// 输入框高度。
  static const double inputHeight = 40;

  /// 最小点击区域(宽与高均不得小于该值)。
  static const double minTapTarget = 40;

  /// 键盘 Focus 轮廓宽度。
  static const double focusOutlineWidth = 2;

  /// 普通卡片:1px 浅色边框、无阴影。
  static BorderSide get cardBorder => BorderSide(color: border);
}

/// 一套完整的语义颜色。浅色/深色两个实例覆盖全部界面色;
/// 间距、字号、圆角与组件尺寸不随明暗变化,保持 [FundLensTokens] 常量。
@immutable
class FundLensPalette {
  const FundLensPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentStrong,
    required this.accentSoft,
    required this.accentText,
    required this.profit,
    required this.profitSoft,
    required this.profitText,
    required this.loss,
    required this.lossSoft,
    required this.warn,
    required this.warnSoft,
    required this.warnText,
    required this.disabled,
    required this.hoverBackground,
    required this.sidebar,
    required this.sidebarInk,
    required this.sidebarMuted,
    required this.sidebarTitle,
    required this.sidebarActive,
    required this.categoryColors,
    required this.chartBarShades,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color accentStrong;
  final Color accentSoft;
  final Color accentText;
  final Color profit;
  final Color profitSoft;
  final Color profitText;
  final Color loss;
  final Color lossSoft;
  final Color warn;
  final Color warnSoft;
  final Color warnText;
  final Color disabled;
  final Color hoverBackground;
  final Color sidebar;
  final Color sidebarInk;
  final Color sidebarMuted;
  final Color sidebarTitle;
  final Color sidebarActive;
  final Map<AssetClass, Color> categoryColors;
  final List<Color> chartBarShades;

  /// 浅色暖墨调色板(2026-07 全局设计变量,原始值)。
  static const light = FundLensPalette(
    canvas: Color(0xFFF6F3EC),
    surface: Color(0xFFFFFDF8),
    surfaceAlt: Color(0xFFFAF8F1),
    ink: Color(0xFF292722),
    inkSoft: Color(0xFF4C4639),
    muted: Color(0xFF736E64),
    border: Color(0xFFE4DED1),
    borderStrong: Color(0xFF948E7F),
    accent: Color(0xFFB65233),
    accentStrong: Color(0xFFB65233),
    accentSoft: Color(0xFFF6E4DA),
    accentText: Color(0xFFA84B2E),
    profit: Color(0xFFB84B34),
    profitSoft: Color(0xFFF8E7E1),
    profitText: Color(0xFFAF4530),
    loss: Color(0xFF19705D),
    lossSoft: Color(0xFFE2EFE8),
    warn: Color(0xFFA66A16),
    warnSoft: Color(0xFFF6ECD4),
    warnText: Color(0xFF8F5A10),
    disabled: Color(0xFFC9C5BC),
    hoverBackground: Color(0xFFF3EAE1),
    sidebar: Color(0xFF27231D),
    sidebarInk: Color(0xFFB6AD9C),
    sidebarMuted: Color(0xFF978C75),
    sidebarTitle: Color(0xFFF3EFE6),
    sidebarActive: Color(0xFFB65233),
    categoryColors: {
      AssetClass.cash: Color(0xFF8A8272),
      AssetClass.deposit: Color(0xFF3E7CB1),
      AssetClass.equity: Color(0xFFB65233),
      AssetClass.fixedIncome: Color(0xFF2E7D5B),
      AssetClass.mixed: Color(0xFFC58A40),
      AssetClass.gold: Color(0xFFBFA134),
      AssetClass.other: Color(0xFFA9A294),
    },
    chartBarShades: [
      Color(0xFFB65233),
      Color(0xFFD3896D),
      Color(0xFFC58A40),
      Color(0xFFA66A16),
    ],
  );

  /// 深色暖墨调色板:同一色相体系整体压暗,主色与金融语义色
  /// 在深色表面上保持 WCAG AA 对比度;红盈利/绿亏损语义不变。
  static const dark = FundLensPalette(
    canvas: Color(0xFF211E19),
    surface: Color(0xFF2B2620),
    surfaceAlt: Color(0xFF342F28),
    ink: Color(0xFFEDE8DD),
    inkSoft: Color(0xFFCAC3B5),
    muted: Color(0xFF9C9485),
    border: Color(0xFF474037),
    borderStrong: Color(0xFF7A7263),
    accent: Color(0xFFCB6C4D),
    accentStrong: Color(0xFFCB6C4D),
    accentSoft: Color(0xFF4B352B),
    accentText: Color(0xFFE0957A),
    profit: Color(0xFFD4694F),
    profitSoft: Color(0xFF452A20),
    profitText: Color(0xFFE0866F),
    loss: Color(0xFF44A088),
    lossSoft: Color(0xFF1F3A31),
    warn: Color(0xFFCC8C3D),
    warnSoft: Color(0xFF40321A),
    warnText: Color(0xFFDB9E50),
    disabled: Color(0xFF55504A),
    hoverBackground: Color(0xFF3A322B),
    sidebar: Color(0xFF1C1915),
    sidebarInk: Color(0xFFB6AD9C),
    sidebarMuted: Color(0xFF978C75),
    sidebarTitle: Color(0xFFF3EFE6),
    sidebarActive: Color(0xFFCB6C4D),
    categoryColors: {
      AssetClass.cash: Color(0xFF9A9284),
      AssetClass.deposit: Color(0xFF5C97C9),
      AssetClass.equity: Color(0xFFCB6C4D),
      AssetClass.fixedIncome: Color(0xFF46A380),
      AssetClass.mixed: Color(0xFFD29A50),
      AssetClass.gold: Color(0xFFCDB245),
      AssetClass.other: Color(0xFF8D8778),
    },
    chartBarShades: [
      Color(0xFFCB6C4D),
      Color(0xFFDE8A6E),
      Color(0xFFD29A50),
      Color(0xFFCC8C3D),
    ],
  );
}
