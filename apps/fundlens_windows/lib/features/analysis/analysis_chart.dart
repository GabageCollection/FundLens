import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../overview/overview_formatters.dart';
import 'analysis_labels.dart';

/// 分析页的三个构成维度,展示形态见 Task 3。
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

  /// 条形装饰色;仅资产类别维度按类别段色着色,其余维度为 null
  /// (回退主色/聚合灰)。颜色仅作装饰,名称金额占比始终以文字呈现。
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

/// 横向条形图:行 = 名称 + 条形(自 0 基线) + 条端金额 + 行尾占比,
/// 底部 0/50%/100% 弱化网格竖线与紧凑刻度。
///
/// [chartHeight] 为行区高度(不含底部刻度带);行槽在行区内均匀分布,
/// 保持图表区固定高度,切换维度时布局稳定。
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.rows,
    this.chartHeight = 240,
  });

  final List<ChartBarRow> rows;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const ChartEmptyState();
    final theme = Theme.of(context);
    final numberStyle = theme.extension<FundLensTextStyles>()!.financialNumber;
    final maxAmount = rows.first.amount; // 已按金额降序
    final midAmount = maxAmount.isZero
        ? DecimalValue.zero
        : DecimalValue.parse(
            (maxAmount.value.toDouble() / 2).toStringAsFixed(0),
          );
    final axisStyle = theme.textTheme.bodySmall;

    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              Column(
                children: [
                  for (final row in rows)
                    Expanded(
                      child: Tooltip(
                        message: _rowSemantics(row),
                        child: Semantics(
                          label: _rowSemantics(row),
                          child: Row(
                            children: [
                              // 200% 缩放等窄约束下金额/占比列可收缩而非横向溢出;
                              // 完整值经 Tooltip 提供(见 _rowSemantics)。
                              SizedBox(
                                width: 84,
                                child: Text(
                                  row.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: FundLensTokens.space3),
                              Expanded(
                                child: _Bar(row: row, maxAmount: maxAmount),
                              ),
                              const SizedBox(width: FundLensTokens.space3),
                              // 金额/占比定宽右对齐:行间数字按位对齐,便于扫读;
                              // 完整值经 Tooltip 提供(见 _rowSemantics)。
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
                                width: 52,
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
                ],
              ),
              // 0/50%/100% 弱化网格竖线(跨整个行区)。
              IgnorePointer(
                child: CustomPaint(
                  painter: _GridLinesPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 20,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  formatAxisAmount(DecimalValue.zero),
                  style: axisStyle,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(formatAxisAmount(midAmount), style: axisStyle),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(formatAxisAmount(maxAmount), style: axisStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 单条条形:轨道(surfaceAlt)+ 自 0 基线的主色/暖灰条形。
class _Bar extends StatelessWidget {
  const _Bar({required this.row, required this.maxAmount});

  final ChartBarRow row;
  final DecimalValue maxAmount;

  @override
  Widget build(BuildContext context) {
    final fraction = maxAmount.isZero
        ? 0.0
        : row.amount.divide(maxAmount).value.toDouble();
    final barColor =
        row.color ??
        (row.isAggregate ? FundLensTokens.muted : FundLensTokens.accent);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: FundLensTokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GridLinesPainter extends CustomPainter {
  const _GridLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FundLensTokens.border
      ..strokeWidth = 1;
    for (final fraction in [0.0, 0.5, 1.0]) {
      final x = size.width * fraction;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GridLinesPainter oldDelegate) => false;
}

/// 来源平台横向比例条:单条 100% 宽堆叠条(段间 2px surface 间隔) +
/// 图例行(色点 + 名称 + 金额 + 占比)。段色取品牌陶土同系三档。
class PlatformProportionBar extends StatelessWidget {
  const PlatformProportionBar({super.key, required this.rows});

  final List<ChartBarRow> rows;

  /// 堆叠段色按段序取暖墨档位,超档回退 muted;段名与占比始终以文字呈现。
  Color _colorFor(int index) => index < FundLensTokens.chartBarShades.length
      ? FundLensTokens.chartBarShades[index]
      : FundLensTokens.muted;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const ChartEmptyState();
    final theme = Theme.of(context);
    final numberStyle = theme.extension<FundLensTextStyles>()!.financialNumber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: rows
              .map((row) => '${row.label} ${formatShare(row.share)}')
              .join(' · '),
          child: Semantics(
            label: rows
                .map((row) => '${row.label} ${formatShare(row.share)}')
                .join(' · '),
            child: SizedBox(
              height: 14,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final flexes = rows
                      .map((r) => (r.share.value.toDouble() * 1000).round())
                      .toList();
                  if (flexes.every((f) => f == 0)) {
                    return Container(
                      decoration: BoxDecoration(
                        color: FundLensTokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }
                  return Row(
                    children: [
                      for (final (i, _) in rows.indexed)
                        Expanded(
                          flex: flexes[i].clamp(1, 1000),
                          child: Container(
                            height: 14,
                            margin: i > 0
                                ? const EdgeInsets.only(left: 2)
                                : null,
                            decoration: BoxDecoration(
                              color: _colorFor(i),
                              borderRadius: BorderRadius.horizontal(
                                right: i == rows.length - 1
                                    ? const Radius.circular(4)
                                    : Radius.zero,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: FundLensTokens.space3),
        for (final (i, row) in rows.indexed)
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _colorFor(i),
                    borderRadius: BorderRadius.circular(2),
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
                // 金额/占比定宽右对齐,与条形图行式一致,便于行间扫读。
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
                  width: 52,
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
      ],
    );
  }
}
