import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_shell.dart';
import '../../theme/fundlens_tokens.dart';
import 'data_health_popover.dart';
import 'data_health_providers.dart';

/// 全局数据健康入口按钮:由真实持仓数据派生五态,图标 + 文字双语义表达,
/// 不依赖颜色单通道。点击打开 [DataHealthPopover]。
class DataHealthButton extends ConsumerStatefulWidget {
  const DataHealthButton({super.key});

  @override
  ConsumerState<DataHealthButton> createState() => _DataHealthButtonState();
}

class _DataHealthButtonState extends ConsumerState<DataHealthButton> {
  /// 面板开关状态;由按钮与面板操作共同持有,导航后收起浮层。
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dataHealthStatusProvider);
    final (label, icon) = dataHealthPresentation(status);
    final color = dataHealthTextColor(status);
    return MenuAnchor(
      controller: _menuController,
      builder: (context, controller, child) {
        // minHeight 而非固定高:高 DPI / 200% 缩放下文字增大不截断。
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: FundLensTokens.buttonHeight),
          child: OutlinedButton.icon(
            key: const ValueKey('data-status-button'),
            onPressed: () => controller.isOpen
                ? controller.close()
                : controller.open(),
            icon: Icon(icon, size: 16, color: color),
            label: Text(label, style: TextStyle(color: color)),
          ),
        );
      },
      // 导航必须用按钮自身的 context(位于 AppShell 的 Actions 之下):面板
      // 本体挂在 Navigator 的 Overlay 上,其 context 找不到 AppShell 的
      // 意图处理器。
      menuChildren: [
        DataHealthPopover(
          onNavigate: (destination) {
            Actions.maybeInvoke(
              context,
              SelectDestinationIntent(destination),
            );
            _menuController.close();
          },
        ),
      ],
    );
  }
}
