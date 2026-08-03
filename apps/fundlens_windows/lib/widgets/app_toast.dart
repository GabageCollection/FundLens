import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 全局轻提示。成功与失败带图标区分,连续触发时替换上一条,不堆积。
///
/// 所有页面应通过本函数发提示,而不是直接调
/// `ScaffoldMessenger.of(context).showSnackBar`。
void showAppToast(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (isError) ...[
            const Icon(
              Icons.error_outline,
              size: 18,
              color: Color(0xFFFFFFFF),
            ),
            const SizedBox(width: FundLensTokens.space2),
          ],
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
