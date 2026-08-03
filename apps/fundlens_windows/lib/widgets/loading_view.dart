import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 统一的页面级加载占位。
///
/// 带 [Semantics] 标签,屏幕阅读器可获知"正在加载";默认附一句说明文字,
/// 避免整页只有一个裸转圈。
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = '正在加载…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      liveRegion: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: FundLensTokens.space3),
            Text(
              label,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
