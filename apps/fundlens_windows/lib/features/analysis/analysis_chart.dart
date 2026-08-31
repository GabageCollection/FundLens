import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../overview/overview_formatters.dart';
import 'analysis_labels.dart';

/// 分析页的三个构成维度,统一以环形图 + 图例展示(见 CompositionDonutChart)。
enum AnalysisDimension { assetClass, instrumentType, source }

const dimensionLabels = <AnalysisDimension, String>{
  AnalysisDimension.assetClass: '资产类别',
  AnalysisDimension.instrumentType: '产品类型',
  AnalysisDimension.source: '来源平台',
};

/// 图表中的一行:分组名称、金额、占总资产比例与是否"其他"聚合行。
final class ChartBarRow {
  const ChartBarRow({
    required this.label,
    required this.amount,
    required this.share,
    this.isAggregate = false,
    this.color,
  });

  final String label;

  /// 该分组当前金额(DecimalValue,不在此处转浮点)。
  final DecimalValue amount;

  /// 占总资产比例 0..1。
  final DecimalValue share;

  /// 超过 6 项时占比最小的类别合并为"其他"聚合行。
  final bool isAggregate;

  /// 环段装饰色;仅资产类别维度按类别段色着色,其余维度为 null
  /// (回退暖墨档位/聚合灰)。颜色仅作装饰,名称金额占比始终以文字呈现。
  final Color? color;
}

/// 按维度生成图表行:零金额过滤 → 金额降序 → ≤6 全显,>6 前 5 + 合并"其他"。
List<ChartBarRow> buildChartRows(
  PortfolioSummary summary,
  AnalysisDimension dimension,
) {
  final raw = <(String, DecimalValue, Color?)>[];
  switch (dimension) {
    case AnalysisDimension.assetClass:
      for (final entry in summary.byAssetClass.entries) {
        if (!entry.value.isZero) {
          raw.add((
            assetClassLabels[entry.key]!,
            entry.value,
            FundLensTokens.categoryColors[entry.key],
          ));
        }
      }
    case AnalysisDimension.instrumentType:
      for (final entry in summary.byInstrumentType.entries) {
        if (!entry.value.isZero) {
          raw.add((instrumentTypeLabels[entry.key]!, entry.value, null));
        }
      }
    case AnalysisDimension.source:
      for (final entry in summary.bySource.entries) {
        if (!entry.value.isZero) {
          raw.add((sourcePlatformLabels[entry.key]!, entry.value, null));
        }
      }
  }
  raw.sort((a, b) => b.$2.compareTo(a.$2));

  final total = summary.totalValue;
  DecimalValue shareOf(DecimalValue amount) =>
      total.isZero ? DecimalValue.zero : amount.divide(total);

  if (raw.length <= 6) {
    return [
      for (final (label, amount, color) in raw)
        ChartBarRow(
          label: label,
          amount: amount,
          share: shareOf(amount),
          color: color,
        ),
    ];
  }
  final kept = raw.take(5).toList();
  final mergedAmount = raw
      .skip(5)
      .fold(DecimalValue.zero, (sum, entry) => sum + entry.$2);
  return [
    for (final (label, amount, color) in kept)
      ChartBarRow(
        label: label,
        amount: amount,
        share: shareOf(amount),
        color: color,
      ),
    ChartBarRow(
      label: '其余 ${raw.length - 5} 项',
      amount: mergedAmount,
      share: shareOf(mergedAmount),
      isAggregate: true,
    ),
  ];
}

/// 图表空状态:无行时显示原因而不是灰色占位。
class ChartEmptyState extends StatelessWidget {
  const ChartEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '暂无有效资产数据,添加或更新持仓后展示结构分析。',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

String _rowSemantics(ChartBarRow row) =>
    '${row.label} 金额 ${formatCurrency(row.amount)} '
    '占比 ${formatShare(row.share)}';

/// 构成环形图:左侧甜甜圈环(中心默认显示总资产,悬停时切换为该分项)
/// + 右侧图例行(色点 + 名称 + 金额 + 占比),环段与图例行悬停联动高亮。
///
/// 构成(part-to-whole)数据用环段角度直接表达占比;颜色仅作装饰,
/// 名称金额占比始终以文字呈现。图表区高度由外层固定,切换维度布局稳定。
class CompositionDonutChart extends StatefulWidget {
  const CompositionDonutChart({super.key, required this.rows});

  final List<ChartBarRow> rows;

  @override
  State<CompositionDonutChart> createState() => _CompositionDonutChartState();
}

class _CompositionDonutChartState extends State<CompositionDonutChart> {
  int? _hoveredIndex;

  /// 环图边长;行区高度由外层固定,环图在垂直方向居中。
  static const double _donutSize = 168;

  void _setHovered(int? index) {
    if (index == _hoveredIndex) return;
    setState(() => _hoveredIndex = index);
  }

  /// 段色:资产类别维度用类别段色,其余维度按段序取暖墨档位,
  /// 聚合行与超档回退暖灰。
  Color _segmentColor(int index) {
    final row = widget.rows[index];
    final rowColor = row.color;
    if (rowColor != null) return rowColor;
    if (row.isAggregate) return FundLensTokens.muted;
    final shades = FundLensTokens.chartBarShades;
    return index < shades.length ? shades[index] : FundLensTokens.muted;
  }

  /// 归一化占比(聚合行的占比经 8 位截断,总和可能略小于 1,归一后正好闭环)。
  List<double> _fractions() {
    final shares = [for (final row in widget.rows) row.share.value.toDouble()];
    final sum = shares.fold<double>(0, (a, b) => a + b);
    if (sum <= 0) return List.filled(shares.length, 0);
    return [for (final share in shares) share / sum];
  }

  /// 指针命中环段:仅当落点在环带内时按角度定位段,否则清除高亮。
  void _handleDonutHover(Offset local, double size) {
    final center = Offset(size / 2, size / 2);
    final delta = local - center;
    final distance = delta.distance;
    final outer = size / 2 - 2;
    final inner = outer - _DonutPainter.thickness - _DonutPainter.hoverGrow;
    if (distance < inner || distance > outer) {
      _setHovered(null);
      return;
    }
    // 以 12 点方向为 0,顺时针累计角度定位段。
    final angle =
        (math.atan2(delta.dy, delta.dx) + math.pi / 2) % (2 * math.pi);
    final fractions = _fractions();
    var accumulated = 0.0;
    for (var i = 0; i < fractions.length; i++) {
      accumulated += fractions[i] * 2 * math.pi;
      if (angle <= accumulated) {
        _setHovered(i);
        return;
      }
    }
    _setHovered(null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const ChartEmptyState();
    final theme = Theme.of(context);
    final numberStyle = theme.extension<FundLensTextStyles>()!.financialNumber;
    final hovered = _hoveredIndex;
    // 聚合行已包含其余分项,行金额合计即总资产。
    final total = widget.rows.fold<DecimalValue>(
      DecimalValue.zero,
      (sum, row) => sum + row.amount,
    );

    // 宽档:环图居左、图例居右;窄档(如 200% 缩放)上下堆叠,环图居中。
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 520;
        final donut = _buildDonut(narrow ? 144 : _donutSize, hovered, total);
        final legend = Column(
          mainAxisAlignment: narrow
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.rows.length; i++)
              _legendRow(numberStyle, i),
          ],
        );
        if (narrow) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(child: donut),
              const SizedBox(height: FundLensTokens.space3),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            donut,
            const SizedBox(width: FundLensTokens.space6),
            Expanded(child: legend),
          ],
        );
      },
    );
  }

  Widget _buildDonut(double size, int? hovered, DecimalValue total) {
    return SizedBox(
      width: size,
      height: size,
      child: MouseRegion(
        onHover: (event) => _handleDonutHover(event.localPosition, size),
        onExit: (_) => _setHovered(null),
        child: Semantics(
          label: widget.rows
              .map((row) => '${row.label} ${formatShare(row.share)}')
              .join(' · '),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _DonutPainter(
                    colors: [
                      for (var i = 0; i < widget.rows.length; i++)
                        _segmentColor(i),
                    ],
                    fractions: _fractions(),
                    hoveredIndex: hovered,
                  ),
                ),
              ),
              IgnorePointer(
                child: _CenterLabel(
                  hovered: hovered,
                  rows: widget.rows,
                  total: total,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 图例行:色点 + 名称 + 金额 + 占比;悬停底色高亮并联动环段。
  /// 金额/占比定宽右对齐,行间数字按位对齐,便于扫读;
  /// 200% 缩放等窄约束下列可收缩而非横向溢出,完整值经 Tooltip 提供。
  Widget _legendRow(TextStyle numberStyle, int index) {
    final theme = Theme.of(context);
    final row = widget.rows[index];
    final hovered = index == _hoveredIndex;
    return Tooltip(
      message: _rowSemantics(row),
      child: Semantics(
        label: _rowSemantics(row),
        child: MouseRegion(
          onEnter: (_) => _setHovered(index),
          onExit: (_) => _setHovered(null),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(
              horizontal: FundLensTokens.space2,
            ),
            decoration: BoxDecoration(
              color: hovered
                  ? FundLensTokens.hoverBackground
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _segmentColor(index),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: FundLensTokens.space2),
                Expanded(
                  child: Text(
                    row.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: FundLensTokens.space3),
                SizedBox(
                  width: 104,
                  child: Text(
                    formatCurrency(row.amount),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: numberStyle,
                  ),
                ),
                const SizedBox(width: FundLensTokens.space4),
                SizedBox(
                  width: 56,
                  child: Text(
                    formatShare(row.share),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: numberStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 环心文字:默认"总资产 + 合计金额",悬停时切换为该分项的名称/占比/金额。
class _CenterLabel extends StatelessWidget {
  const _CenterLabel({
    required this.hovered,
    required this.rows,
    required this.total,
  });

  final int? hovered;
  final List<ChartBarRow> rows;
  final DecimalValue total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emphasisStyle = theme
        .extension<FundLensTextStyles>()!
        .financialEmphasisSmall;
    final captionStyle = theme.textTheme.bodySmall;
    // 环心可用宽约 112px,超长金额等比缩小而非溢出。
    return SizedBox(
      width: 112,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hovered == null) ...[
              Text('总资产', style: captionStyle),
              const SizedBox(height: FundLensTokens.space1),
              Text(formatCurrency(total), style: emphasisStyle),
            ] else ...[
              Text(rows[hovered!].label, style: captionStyle),
              const SizedBox(height: FundLensTokens.space1),
              Text(formatShare(rows[hovered!].share), style: emphasisStyle),
              Text(formatCurrency(rows[hovered!].amount), style: captionStyle),
            ],
          ],
        ),
      ),
    );
  }
}

/// 甜甜圈环绘制:段扫掠角 = 归一化占比 × 2π,自 12 点方向顺时针;
/// 段间留小气口,悬停段加粗外扩、其余段降透明度。
class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.colors,
    required this.fractions,
    this.hoveredIndex,
  });

  final List<Color> colors;
  final List<double> fractions;
  final int? hoveredIndex;

  /// 环带基准厚度。
  static const double thickness = 20;

  /// 悬停段单侧外扩量。
  static const double hoverGrow = 5;

  /// 段间气口弧度(多段时);极小分段按自身角度收敛,避免气口吞掉整段。
  static const double _gap = 0.025;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    // 预留悬停外扩量:悬停段外缘最多到 min/2 - 2,不会画出环图边界。
    final baseOuter =
        math.min(size.width, size.height) / 2 -
        2 -
        hoverGrow -
        (thickness + hoverGrow) / 2;
    final paint = Paint()..style = PaintingStyle.stroke;

    var start = -math.pi / 2;
    for (var i = 0; i < fractions.length; i++) {
      final sweep = fractions[i] * 2 * math.pi;
      if (sweep <= 0) continue;
      final hovered = i == hoveredIndex;
      final dimmed = hoveredIndex != null && !hovered;
      final gap = fractions.length > 1 ? math.min(_gap, sweep * 0.2) : 0.0;
      final segmentThickness = hovered ? thickness + hoverGrow : thickness;
      final outer = hovered ? baseOuter + hoverGrow : baseOuter;
      paint
        ..color = colors[i].withValues(alpha: dimmed ? 0.3 : 1)
        ..strokeWidth = segmentThickness;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outer - segmentThickness / 2),
        start + gap / 2,
        sweep - gap,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) => true;
}
