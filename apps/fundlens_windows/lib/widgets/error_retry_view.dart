import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 统一的页面级错误态:说明"发生了什么 + 哪些数据受影响",并提供重试出口。
///
/// 原始异常对象只进日志,不直接拼进用户可见文案(避免技术噪音与路径泄露)。
/// 替代各页面手写的 `Text('数据暂时不可用：$error')`。
///
/// [onRetry] 可空:为 null 时隐藏重试按钮(错误无重试出口,如不可恢复的草稿
/// 损坏);[hint] 展示额外的安全提示行;[secondaryLabel]/[onSecondary] 提供
/// 主重试之外的次级出口(如"返回来源")。
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = '重试',
    this.hint,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? hint;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

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
            if (hint != null) ...[
              const SizedBox(height: FundLensTokens.space2),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: FundLensTokens.muted,
                ),
              ),
            ],
            // 至多两个出口按钮,直接条件排列,不需要通用列表机制。
            if (onRetry != null || onSecondary != null) ...[
              const SizedBox(height: FundLensTokens.space4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onRetry != null)
                    FilledButton.tonal(
                      onPressed: onRetry,
                      child: Text(retryLabel),
                    ),
                  if (onRetry != null && onSecondary != null)
                    const SizedBox(width: FundLensTokens.space3),
                  if (onSecondary != null)
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
