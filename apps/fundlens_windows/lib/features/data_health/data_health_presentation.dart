import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import 'data_health_models.dart';

/// 数据健康五态的统一展示投影:标签、图标与两种表面色。
///
/// - [label] / [icon]:状态文字与图标,颜色之外的双语义表达。
/// - [textColor]:小字用文字档色,在画布上满足 WCAG AA(≥4.5:1)。
/// - [iconColor]:浅色表面上的图标原色,对比度足够。
///
/// 按钮与面板共用此投影;新增状态只需在下方 switch 补一处,避免
/// 标签/文字色/图标色三处映射漂移。两个颜色字段有意分开:
/// 它们服从不同的对比度策略,调用方各自取用。
({String label, IconData icon, Color textColor, Color iconColor})
    dataHealthPresentation(DataHealthStatus status) =>
        switch (status) {
          DataHealthStatus.normal => (
              label: '正常',
              icon: Icons.check_circle_outline,
              textColor: FundLensTokens.accentText,
              iconColor: FundLensTokens.accent,
            ),
          DataHealthStatus.partialMissing => (
              label: '部分缺失',
              icon: Icons.error_outline,
              textColor: FundLensTokens.warnText,
              iconColor: FundLensTokens.warn,
            ),
          DataHealthStatus.needsUpdate => (
              label: '需要更新',
              icon: Icons.update,
              textColor: FundLensTokens.warnText,
              iconColor: FundLensTokens.warn,
            ),
          DataHealthStatus.refreshing => (
              label: '正在刷新',
              icon: Icons.sync,
              textColor: FundLensTokens.accentText,
              iconColor: FundLensTokens.accent,
            ),
          DataHealthStatus.refreshFailed => (
              label: '刷新失败',
              icon: Icons.error_outline,
              textColor: FundLensTokens.profitText,
              iconColor: FundLensTokens.profit,
            ),
        };
