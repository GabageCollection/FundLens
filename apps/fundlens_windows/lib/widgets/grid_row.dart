import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 12 列栅格中的一列。
class GridCol {
  const GridCol({required this.span, required this.child})
    : assert(span >= 1 && span <= 12, 'GridCol.span 必须在 1–12 之间');

  /// 占用列数(1–12),同一 GridRow 内各列 span 之和应为 12。
  final int span;

  final Widget child;
}

/// 轻量 12 列响应式栅格。
///
/// 宽度 ≥ [collapseBelow] 时按 12 列比例横向分布;低于该宽度时
/// 降为单列纵向堆叠,避免少量内容被压扁或独占超宽区域。
class GridRow extends StatelessWidget {
  const GridRow({
    super.key,
    required this.children,
    this.gutter = FundLensTokens.gridGutter,
    this.collapseBelow = FundLensTokens.gridCollapseBelow,
  });

  final List<GridCol> children;
  final double gutter;
  final double collapseBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < collapseBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gutter),
                children[i].child,
              ],
            ],
          );
        }
        final unit = (width - 11 * gutter) / 12;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gutter),
              SizedBox(
                width:
                    unit * children[i].span +
                    gutter * (children[i].span - 1),
                child: children[i].child,
              ),
            ],
          ],
        );
      },
    );
  }
}
