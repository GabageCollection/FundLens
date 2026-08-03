import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 统一的高风险操作二次确认对话框。
///
/// 替换各页面手写的 `showDialog<bool> + AlertDialog`。要点:
/// - 取消按钮默认聚焦,避免键盘用户误按 Enter 确认破坏性操作;
/// - [destructive] 为 true 时确认按钮用盈利红实心样式,与其他操作区分;
/// - 影响说明由调用方提供,必须写清"会影响什么、可不可恢复"。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  String confirmLabel = '确认',
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: content,
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        if (destructive)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: FundLensTokens.profit,
              foregroundColor: const Color(0xFFFFFFFF),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
      ],
    ),
  );
  return confirmed ?? false;
}
