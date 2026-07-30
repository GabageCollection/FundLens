import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 统一页面页头:面包屑(12px 辅助文字)在上、页面标题在下形成层级,
/// 操作按钮位于标题行右侧;窄屏时操作区经 Wrap 换行到标题下方,
/// 避免遮挡与溢出。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.crumb,
    required this.title,
    this.actions = const [],
  });

  /// 面包屑分组名(「组合」「数据」)。
  final String crumb;

  /// 页面标题。
  final String title;

  /// 标题行右侧的操作按钮/控件。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          crumb,
          style: theme.textTheme.bodySmall?.copyWith(
            color: FundLensTokens.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: FundLensTokens.space1),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: FundLensTokens.space4,
          runSpacing: FundLensTokens.space3,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (actions.isNotEmpty)
              Wrap(
                spacing: FundLensTokens.space3,
                runSpacing: FundLensTokens.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
          ],
        ),
      ],
    );
  }
}
