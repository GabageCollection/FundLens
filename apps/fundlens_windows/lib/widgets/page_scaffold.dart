import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';
import 'page_header.dart';

/// 正文最大宽度档位。
enum PageWidthTier {
  /// 普通页面:资产总览、资产分析。
  standard(FundLensTokens.contentMaxStandard),

  /// 数据密集页面:全部持仓、历史快照。
  dense(FundLensTokens.contentMaxDense),

  /// 表单页面:设置与备份。
  form(FundLensTokens.contentMaxForm);

  const PageWidthTier(this.maxWidth);

  final double maxWidth;
}

/// 统一页面骨架:居中限宽容器 + PageHeader + 正文。
///
/// 页面标题、卡片和表格因此共享同一条左右边界;窗口窄于档位时
/// 跟随可用宽度,不产生水平溢出。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.tier,
    required this.crumb,
    required this.title,
    this.actions = const [],
    required this.body,
  });

  final PageWidthTier tier;
  final String crumb;
  final String title;
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tier.maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FundLensTokens.pagePadding,
              0,
              FundLensTokens.pagePadding,
              FundLensTokens.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: FundLensTokens.pagePadding),
                PageHeader(crumb: crumb, title: title, actions: actions),
                const SizedBox(height: FundLensTokens.titleGap),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
