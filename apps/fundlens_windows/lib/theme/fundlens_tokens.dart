import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

/// FundLens 暖墨设计系统的唯一设计变量来源。
///
/// 所有页面与组件必须使用这里的语义变量,不得在组件中散落硬编码的
/// 颜色、字号、间距、圆角或按钮尺寸。金融语义遵循国内习惯——红涨绿跌,
/// 但任何盈亏状态都必须同时提供 `+`/`-`、图标或文字,不能只依赖颜色。
abstract final class FundLensTokens {
  // ---- 颜色:画布与表面 ----
  /// 页面背景(羊皮纸画布)。
  static const canvas = Color(0xFFF6F3EC);

  /// 卡片和表格背景。
  static const surface = Color(0xFFFFFDF8);

  /// 次级表面:表头、占比条轨道、分组底色。
  static const surfaceAlt = Color(0xFFFAF8F1);

  // ---- 颜色:文字 ----
  /// 主要文字(暖墨)。
  static const ink = Color(0xFF292722);

  /// 次级正文(表内说明、次级标签)。
  static const inkSoft = Color(0xFF4C4639);

  /// 辅助文字;在 canvas/surface 上保持 ≥4.5:1 对比度。
  static const muted = Color(0xFF736E64);

  // ---- 颜色:边框 ----
  /// 常规边框与分隔线。
  static const border = Color(0xFFE4DED1);

  /// 强调边框:输入框常态、卡片 hover。
  static const borderStrong = Color(0xFFD5CFBC);

  // ---- 颜色:主色(陶土橙) ----
  /// 图形强调(图表、资产光谱高亮)。
  static const accent = Color(0xFFB65233);

  /// 主按钮填充与文字级强调;在 surface 上对比度安全。
  static const accentStrong = Color(0xFFB65233);

  /// 主色浅底:选中导航、chip 底色。
  static const accentSoft = Color(0xFFF6E4DA);

  // ---- 颜色:金融语义(国内习惯:红盈利、绿亏损) ----
  /// 上涨与盈利。
  static const profit = Color(0xFFB84B34);
  static const profitSoft = Color(0xFFF8E7E1);

  /// 下跌与亏损。
  static const loss = Color(0xFF19705D);
  static const lossSoft = Color(0xFFE2EFE8);

  // ---- 颜色:数据异常警告 ----
  static const warn = Color(0xFFA66A16);
  static const warnSoft = Color(0xFFF6ECD4);

  // ---- 颜色:禁用状态 ----
  static const disabled = Color(0xFFC9C5BC);

  // ---- 颜色:侧边栏 ----
  static const sidebar = Color(0xFF27231D);

  /// 侧边栏未选中文字。
  static const sidebarInk = Color(0xFFB6AD9C);

  /// 侧边栏弱提示文字(分组标签、页脚次行)。
  static const sidebarMuted = Color(0xFF6E6656);

  /// 侧边栏品牌字标。
  static const sidebarTitle = Color(0xFFF3EFE6);

  /// 侧边栏选中态(与主色一致)。
  static const sidebarActive = Color(0xFFB65233);

  /// 各资产类别的装饰段色。颜色仅作装饰,类别名称、金额与占比
  /// 必须同时以文字呈现。
  static const categoryColors = <AssetClass, Color>{
    AssetClass.cash: Color(0xFF8A8272),
    AssetClass.deposit: Color(0xFF3E7CB1),
    AssetClass.equity: Color(0xFFB65233),
    AssetClass.fixedIncome: Color(0xFF2E7D5B),
    AssetClass.mixed: Color(0xFFC58A40),
    AssetClass.gold: Color(0xFFBFA134),
    AssetClass.other: Color(0xFFA9A294),
  };

  /// 图表用品牌陶土同系深浅(经 dataviz validate_palette 校验,浅档
  /// 读作灰色故只保留两档):堆叠比例条第 1/2 段;条形图统一用
  /// [accent],聚合"其他"行用 [muted]。
  static const chartBarShades = <Color>[
    Color(0xFFB65233),
    Color(0xFFD3896D),
  ];

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
  static const cardBorder = BorderSide(color: border);
}
