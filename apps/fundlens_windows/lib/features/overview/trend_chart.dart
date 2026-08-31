import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../holdings/holding_status.dart';
import 'overview_formatters.dart';

/// 趋势图上的一个数据点:某时刻的总资产与覆盖成本。
///
/// 只来自真实快照与当前持仓,绝不生成虚假历史数据。
final class TrendPoint {
  const TrendPoint({
    required this.at,
    required this.totalValue,
    required this.coveredCost,
  });

  final DateTime at;
  final DecimalValue totalValue;
  final DecimalValue coveredCost;
}

/// 趋势图时间范围。
enum TrendRange {
  month1('近1月', Duration(days: 30)),
  month3('近3月', Duration(days: 91)),
  year1('近1年', Duration(days: 365)),
  all('全部', null);

  const TrendRange(this.label, this.window);

  final String label;
  final Duration? window;
}

/// 从一个冻结快照构造趋势点:总资产为持仓金额之和,覆盖成本为有成本
/// 持仓的成本之和(支付宝类快照按 金额 − 持有盈亏 反推成本)。
TrendPoint trendPointFromSnapshot(PortfolioSnapshot snapshot) {
  var total = DecimalValue.zero;
  var cost = DecimalValue.zero;
  for (final holding in snapshot.holdings) {
    total += holding.currentValue;
    final effectiveCost =
        holding.costAmount ??
        (holding.holdingProfit == null
            ? null
            : holding.currentValue - holding.holdingProfit!);
    if (effectiveCost != null) cost += effectiveCost;
  }
  return TrendPoint(
    at: snapshot.createdAt,
    totalValue: total,
    coveredCost: cost,
  );
}

/// 按范围过滤趋势点(按时间升序保留窗口内的点,`全部` 不过滤)。
///
/// 范围外没有点时不补点——没有历史就是没有历史。
List<TrendPoint> filterTrendPoints(
  List<TrendPoint> points,
  TrendRange range,
  DateTime now,
) {
  final window = range.window;
  if (window == null) return List.unmodifiable(points);
  final earliest = now.subtract(window);
  return List.unmodifiable(points.where((p) => !p.at.isBefore(earliest)));
}

/// 资产净值趋势卡:总资产与覆盖成本两条线,支持时间范围切换。
///
/// 数据只来自真实历史快照与当前持仓;快照不足 2 个时显示引导空状态,
/// 不生成任何虚假历史数据。
class PortfolioTrendChart extends ConsumerStatefulWidget {
  const PortfolioTrendChart({super.key});

  @override
  ConsumerState<PortfolioTrendChart> createState() =>
      _PortfolioTrendChartState();
}

class _PortfolioTrendChartState extends ConsumerState<PortfolioTrendChart> {
  TrendRange _range = TrendRange.month1;

  /// 当前悬停的数据点下标;null 表示无悬停。
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = ref.watch(trendPointsProvider);
    final filtered = filterTrendPoints(points, _range, DateTime.now());
    // 引导态按历史快照数量判断(趋势点含当前持仓实时点,不算"第二个快照")。
    final snapshotCount = ref.watch(snapshotsProvider).value?.length ?? 0;
    // 图下摘要延迟求值:仅在有数据分支使用,空态时避免白做格式化。
    late final trendSummary = _trendSummary(filtered, _range);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: FundLensTokens.space3,
              runSpacing: FundLensTokens.space2,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '资产净值趋势',
                  style: theme.extension<FundLensTextStyles>()!.sectionTitle,
                ),
                SegmentedButton<TrendRange>(
                  segments: [
                    for (final range in TrendRange.values)
                      ButtonSegment(value: range, label: Text(range.label)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (selection) =>
                      setState(() => _range = selection.single),
                  showSelectedIcon: false,
                ),
              ],
            ),
            const SizedBox(height: FundLensTokens.space4),
            if (snapshotCount < 2)
              // 历史快照不足 2 个:引导创建,而非范围过滤导致无点。
              SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    '创建第二个快照后可查看趋势',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else if (filtered.length < 2)
              // 快照足够但当前范围过滤后无点:切换范围查看。
              SizedBox(
                height: 180,
                child: Center(
                  child: Text(
                    '所选时间范围内暂无数据，请切换范围查看',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else ...[
              // 图表是纯绘制无文本:为读屏提供等价文字摘要,可见摘要置于图下。
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Semantics(
                  label: trendSummary,
                  image: true,
                  child: ExcludeSemantics(
                    child: _HoverableTrendChart(
                      points: filtered,
                      hoveredIndex: _hoveredIndex,
                      onHoverChanged: (index) =>
                          setState(() => _hoveredIndex = index),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FundLensTokens.space2),
              Row(
                children: [
                  _SeriesLegend(color: FundLensTokens.accent, label: '总资产'),
                  SizedBox(width: FundLensTokens.space4),
                  _SeriesLegend(color: FundLensTokens.muted, label: '覆盖成本'),
                ],
              ),
              const SizedBox(height: FundLensTokens.space2),
              // 可见摘要(读屏只朗读一次,经上方 Semantics 提供)。
              ExcludeSemantics(
                child: Text(trendSummary, style: theme.textTheme.bodySmall),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 图下文字摘要:范围 + 首末金额 + 差额与百分比,盈亏不靠颜色区分。
  String _trendSummary(List<TrendPoint> points, TrendRange range) {
    final first = points.first;
    final last = points.last;
    return '${range.label}：总资产 '
        '${formatCurrency(first.totalValue)} → ${formatCurrency(last.totalValue)}'
        '（${_deltaText(first.totalValue, last.totalValue)}）；'
        '覆盖成本 ${formatCurrency(first.coveredCost)} → '
        '${formatCurrency(last.coveredCost)}'
        '（${_deltaText(first.coveredCost, last.coveredCost)}）';
  }

  /// 首末差额:持平 / 带符号金额 + 百分比(起始为 0 时无百分比)。
  static String _deltaText(DecimalValue start, DecimalValue end) {
    final diff = end - start;
    if (diff.isZero) return '持平';
    final amountText = HoldingValueFormatter.signedAmount(diff);
    if (start.isZero) return amountText;
    return '$amountText，${HoldingValueFormatter.signedPercent(diff.divide(start))}';
  }
}

class _SeriesLegend extends StatelessWidget {
  const _SeriesLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: FundLensTokens.space1),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({required this.points, this.hoveredIndex});

  final List<TrendPoint> points;

  /// 悬停点下标:绘制竖直参考线与两条线的悬停圆点。
  final int? hoveredIndex;

  static const _leftPad = 56.0;
  static const _rightPad = 8.0;
  static const _topPad = 8.0;
  static const _bottomPad = 20.0;

  /// 轴刻度紧凑格式:万元以上显示为 `12.3万`,仅用于渲染。
  static String _axisLabel(double value) {
    if (value.abs() >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    }
    return value.toStringAsFixed(0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final values = points
        .expand(
          (p) => [
            p.totalValue.value.toDouble(),
            p.coveredCost.value.toDouble(),
          ],
        )
        .toList();
    var min = values.reduce((a, b) => a < b ? a : b);
    var max = values.reduce((a, b) => a > b ? a : b);
    if (min == max) {
      min -= 1;
      max += 1;
    }
    final pad = (max - min) * 0.08;
    min -= pad;
    max += pad;

    final chartRect = Rect.fromLTRB(
      _leftPad,
      _topPad,
      size.width - _rightPad,
      size.height - _bottomPad,
    );

    double xFor(int index) => xForIndex(points, chartRect, index);

    double yFor(double value) =>
        chartRect.bottom - (value - min) / (max - min) * chartRect.height;

    // 网格线与 Y 轴刻度(min / mid / max)。
    final gridPaint = Paint()
      ..color = FundLensTokens.border
      ..strokeWidth = 1;
    final labelStyle = TextStyle(
      fontFamily: FundLensFonts.mono,
      fontSize: 12,
      color: FundLensTokens.muted,
    );
    for (final fraction in [0.0, 0.5, 1.0]) {
      final value = min + (max - min) * fraction;
      final y = yFor(value);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
      final painter = TextPainter(
        text: TextSpan(text: _axisLabel(value), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _leftPad - 6);
      painter.paint(
        canvas,
        Offset(_leftPad - 6 - painter.width, y - painter.height / 2),
      );
    }

    // X 轴首末日期。
    String dateLabel(DateTime at) =>
        '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
    for (final (index, alignment) in [
      (0, Alignment.centerLeft),
      (points.length - 1, Alignment.centerRight),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: dateLabel(points[index].at), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = alignment == Alignment.centerLeft
          ? chartRect.left
          : chartRect.right - painter.width;
      painter.paint(canvas, Offset(dx, chartRect.bottom + 4));
    }

    void drawSeries(
      double Function(TrendPoint) valueOf,
      Color color,
      double width,
    ) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final offset = Offset(xFor(i), yFor(valueOf(points[i])));
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(path, paint);
      // 末点标记。
      canvas.drawCircle(
        Offset(xFor(points.length - 1), yFor(valueOf(points.last))),
        3,
        Paint()..color = color,
      );
    }

    drawSeries(
      (p) => p.coveredCost.value.toDouble(),
      FundLensTokens.muted,
      1.5,
    );
    drawSeries((p) => p.totalValue.value.toDouble(), FundLensTokens.accent, 2);

    final hovered = hoveredIndex;
    if (hovered != null && hovered >= 0 && hovered < points.length) {
      final x = xFor(hovered);
      // 竖直参考线:仅 1px 边框色,不喧宾夺主。
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        Paint()
          ..color = FundLensTokens.borderStrong
          ..strokeWidth = 1,
      );
      final point = points[hovered];
      for (final (valueOf, color) in [
        (
          (TrendPoint p) => p.coveredCost.value.toDouble(),
          FundLensTokens.muted,
        ),
        (
          (TrendPoint p) => p.totalValue.value.toDouble(),
          FundLensTokens.accent,
        ),
      ]) {
        final center = Offset(x, yFor(valueOf(point)));
        canvas.drawCircle(center, 4.5, Paint()..color = FundLensTokens.surface);
        canvas.drawCircle(center, 3.5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.hoveredIndex != hoveredIndex;
}

/// The painter's chart rect for a given canvas size.
Rect trendChartRect(Size size) => Rect.fromLTRB(
  _TrendPainter._leftPad,
  _TrendPainter._topPad,
  size.width - _TrendPainter._rightPad,
  size.height - _TrendPainter._bottomPad,
);

/// X position of points[index] inside [chartRect] (time-proportional).
double xForIndex(List<TrendPoint> points, Rect chartRect, int index) {
  final first = points.first.at.millisecondsSinceEpoch;
  final last = points.last.at.millisecondsSinceEpoch;
  if (last == first) return chartRect.center.dx;
  final at = points[index].at.millisecondsSinceEpoch;
  return chartRect.left + (at - first) / (last - first) * chartRect.width;
}

/// Trend chart with hover hit-testing: moving the pointer over the chart
/// highlights the nearest data point (crosshair + dots) and shows a small
/// value card with that point's date and both series values.
class _HoverableTrendChart extends StatefulWidget {
  const _HoverableTrendChart({
    required this.points,
    required this.hoveredIndex,
    required this.onHoverChanged,
  });

  final List<TrendPoint> points;
  final int? hoveredIndex;
  final ValueChanged<int?> onHoverChanged;

  @override
  State<_HoverableTrendChart> createState() => _HoverableTrendChartState();
}

class _HoverableTrendChartState extends State<_HoverableTrendChart> {
  Size _size = Size.zero;

  void _onHover(PointerEvent event, Size size) {
    if (widget.points.isEmpty || size.width <= 0) return;
    final rect = trendChartRect(size);
    // 命中最近的数据点(按 x 距离);指针在绘图区外时清除悬停。
    if (event.localPosition.dy < rect.top - 12 ||
        event.localPosition.dy > rect.bottom + 24) {
      if (widget.hoveredIndex != null) widget.onHoverChanged(null);
      return;
    }
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < widget.points.length; i++) {
      final distance =
          (xForIndex(widget.points, rect, i) - event.localPosition.dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    if (best != widget.hoveredIndex) widget.onHoverChanged(best);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = Size(constraints.maxWidth, constraints.maxHeight);
        final hovered = widget.hoveredIndex;
        final rect = trendChartRect(_size);
        return MouseRegion(
          onHover: (event) => _onHover(event, _size),
          onExit: (_) => widget.onHoverChanged(null),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                key: const ValueKey('trend-chart'),
                size: Size.infinite,
                painter: _TrendPainter(
                  points: widget.points,
                  hoveredIndex: hovered,
                ),
              ),
              if (hovered != null &&
                  hovered >= 0 &&
                  hovered < widget.points.length)
                Positioned(
                  // 浮层跟随悬停点,贴近右缘时翻转到左侧,避免溢出卡片。
                  left: _tooltipLeft(hovered, rect),
                  top: 0,
                  child: _TrendTooltip(point: widget.points[hovered]),
                ),
            ],
          ),
        );
      },
    );
  }

  double _tooltipLeft(int index, Rect rect) {
    const tooltipWidth = 190.0;
    final x = xForIndex(widget.points, rect, index);
    final preferred = x + 12;
    return preferred + tooltipWidth > rect.right
        ? (x - 12 - tooltipWidth).clamp(0.0, double.infinity)
        : preferred;
  }
}

/// 悬停数值卡:日期 + 总资产 + 覆盖成本,白底细边框、无阴影。
class _TrendTooltip extends StatelessWidget {
  const _TrendTooltip({required this.point});

  final TrendPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = point.at;
    final date =
        '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}';
    final valueStyle = FundLensTextStyles.of(
      context,
    ).financialCaption.copyWith(color: theme.textTheme.bodySmall?.color);
    return IgnorePointer(
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(FundLensTokens.space2),
        decoration: BoxDecoration(
          color: FundLensTokens.surface,
          borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
          border: Border.all(color: FundLensTokens.borderStrong),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: theme.textTheme.bodySmall),
            const SizedBox(height: FundLensTokens.space1),
            Text('总资产 ${formatCurrency(point.totalValue)}', style: valueStyle),
            Text(
              '覆盖成本 ${formatCurrency(point.coveredCost)}',
              style: valueStyle,
            ),
          ],
        ),
      ),
    );
  }
}
