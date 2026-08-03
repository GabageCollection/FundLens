import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 统一的页面级错误态:说明"发生了什么 + 哪些数据受影响",并提供重试出口。
///
/// 原始异常对象只进日志,不直接拼进用户可见文案(避免技术噪音与路径泄露)。
/// 替代各页面手写的 `Text('数据暂时不可用：$error')`。
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = '重试',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: FundLensTokens.warnText,
            ),
            const SizedBox(height: FundLensTokens.space3),
            Text(title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: FundLensTokens.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: FundLensTokens.space4),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
