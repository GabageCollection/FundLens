import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import 'holding_filters.dart';

/// 集合元素的切换(选中/取消)。
Set<T> toggled<T>(Set<T> set, T value) {
  final next = {...set};
  if (!next.remove(value)) next.add(value);
  return next;
}

/// 筛选下拉按钮的摘要文案:
/// 未选中显示完整标签;1 项显示"短标签:值";多项显示"短标签:首值+N"。
String filterButtonSummary({
  required String label,
  required String shortLabel,
  required List<String> selectedLabels,
}) {
  if (selectedLabels.isEmpty) return label;
  if (selectedLabels.length == 1) return '$shortLabel:${selectedLabels.first}';
  return '$shortLabel:${selectedLabels.first}+${selectedLabels.length - 1}';
}

/// 搜索框:受控文本与外部筛选状态同步(清除筛选时自动清空)。
class HoldingSearchField extends StatefulWidget {
  const HoldingSearchField({
    super.key,
    required this.query,
    required this.onChanged,
  });

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<HoldingSearchField> createState() => _HoldingSearchFieldState();
}

class _HoldingSearchFieldState extends State<HoldingSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(HoldingSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 40,
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '搜索产品名称或代码',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// 多选筛选下拉:按钮文本即选中状态;菜单条目点击后不自动关闭。
class HoldingFilterDropdown<T> extends StatelessWidget {
  const HoldingFilterDropdown({
    super.key,
    required this.label,
    required this.shortLabel,
    required this.options,
    required this.selected,
    required this.onToggled,
  });

  final String label;
  final String shortLabel;
  final List<(T, String)> options;
  final Set<T> selected;
  final void Function(T value) onToggled;

  @override
  Widget build(BuildContext context) {
    final selectedLabels = [
      for (final (value, text) in options)
        if (selected.contains(value)) text,
    ];
    final summary = filterButtonSummary(
      label: label,
      shortLabel: shortLabel,
      selectedLabels: selectedLabels,
    );
    return MenuAnchor(
      builder: (context, controller, child) {
        return SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        for (final (value, text) in options)
          _CheckMenuEntry(
            checked: selected.contains(value),
            label: text,
            onTap: () => onToggled(value),
          ),
      ],
    );
  }
}

/// 多选菜单条目:InkWell 直接触发(不走 MenuItemButton,避免自动关闭);
/// 最小高度 40 满足点击区域要求。
class _CheckMenuEntry extends StatelessWidget {
  const _CheckMenuEntry({
    required this.checked,
    required this.label,
    required this.onTap,
  });

  final bool checked;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40, minWidth: 160),
        padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: checked ? FundLensTokens.accent : FundLensTokens.muted,
            ),
            const SizedBox(width: FundLensTokens.space2),
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// 排序下拉:列出全部字段 × 方向,与表头排序共享同一状态。
class HoldingSortMenu extends StatelessWidget {
  const HoldingSortMenu({
    super.key,
    required this.sort,
    required this.onSelected,
  });

  final HoldingSort sort;
  final ValueChanged<HoldingSort> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      // 18 项菜单约 864px,超出 720 视口高度;限制面板高度为 480 使菜单
      // 内部滚动,避免面板超出屏高后需要整体滚动页面。
      style: const MenuStyle(
        maximumSize: WidgetStatePropertyAll(Size(double.infinity, 480)),
      ),
      builder: (context, controller, child) {
        return SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(sort.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        for (final field in HoldingSortField.values)
          for (final ascending in const [false, true])
            Builder(builder: (context) {
              final option = HoldingSort(field, ascending);
              final current = option == sort;
              return MenuItemButton(
                leadingIcon: current
                    ? const Icon(Icons.check, size: 18, color: FundLensTokens.accent)
                    : const SizedBox(width: 18),
                onPressed: () => onSelected(option),
                child: Text(option.label),
              );
            }),
      ],
    );
  }
}
