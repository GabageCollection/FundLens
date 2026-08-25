import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/animated_amount_text.dart';
import '../overview/overview_formatters.dart';
import 'analysis_labels.dart';

/// 各 KPI 指标的一句话口径说明,以 Tooltip 呈现。
const _kpiTooltips = <String, String>{
  '总资产': '当前全部持仓金额之和',
  '持仓项数': '当前持仓的产品数量',
  '资产类别': '有非零金额的资产类别数量(共七类)',
  '最大持仓占比': '金额最大的单项持仓占总资产的比例',
  '收益覆盖率': '有成本数据资产的当前金额占总资产的比例',
};

/// 分析页顶部 KPI 区:总资产、持仓项数、资产类别数、最大持仓占比、
/// 收益覆盖率。视觉与总览页 SummaryStrip 一致(分隔线 + 等宽单元格),
/// 指标口径服务于结构分析而非盈亏总览。
class AnalysisSummaryStrip extends ConsumerWidget {
  const AnalysisSummaryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final holdings = ref.watch(holdingsProvider).value ?? const <Holding>[];
    final classCount = summary.byAssetClass.values
        .where((amount) => !amount.isZero)
        .length;
    final cells = <Widget>[
      _KpiCell(
        label: '总资产',
        value: summary.totalValue,
        format: formatCurrency,
        interpolateFormat: formatCurrencyDouble,
      ),
      _KpiCell(label: '持仓项数', staticValue: '${holdings.length} 项'),
      _KpiCell(label: '资产类别', staticValue: '$classCount 类'),
      _KpiCell(
        label: '最大持仓占比',
        value: summary.largestHoldingShare,
        format: formatShare,
        interpolateFormat: formatShareDouble,
      ),
      _KpiCell(
        label: '收益覆盖率',
        value: summary.returnCoverage,
        format: formatShare,
        interpolateFormat: formatShareDouble,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FundLensTokens.cardPadding,
          vertical: FundLensTokens.space4,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 宽屏:分隔线 + 等宽单元格;窄于 760 时两列堆叠,去掉分隔线。
            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) const _CellDivider(),
                    Expanded(child: cells[i]),
                  ],
                ],
              );
            }
            final cellWidth =
                (constraints.maxWidth - FundLensTokens.space4) / 2;
            return Wrap(
              spacing: FundLensTokens.space4,
              runSpacing: FundLensTokens.space4,
              children: [
                for (final cell in cells)
                  SizedBox(width: cellWidth, child: cell),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 1px vertical rule between KPI cells(与总览页 SummaryStrip 同式)。
class _CellDivider extends StatelessWidget {
  const _CellDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.only(right: FundLensTokens.cardPadding),
      color: FundLensTokens.border,
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    this.value,
    this.format,
    this.interpolateFormat,
    this.staticValue,
  }) : assert(
          (value != null && format != null && interpolateFormat != null) ||
              staticValue != null,
          'provide either an animated DecimalValue or a staticValue',
        );

  final String label;

  /// 动画数值(与 [format]/[interpolateFormat] 成对提供)。
  final DecimalValue? value;
  final String Function(DecimalValue)? format;
  final String Function(double)? interpolateFormat;

  /// 静态文本(计数类指标无动画意义)。
  final String? staticValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kpi = theme.extension<FundLensTextStyles>()!.kpiNumber;
    final tooltip = _kpiTooltips[label];
    final labelWidget = Text(label, style: theme.textTheme.bodySmall);
    final valueWidget = value != null
        ? AnimatedAmountText(
            value: value!,
            format: format!,
            interpolateFormat: interpolateFormat!,
            style: kpi,
          )
        : Text(staticValue!, style: kpi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tooltip == null)
          labelWidget
        else
          Tooltip(
            message: tooltip,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                labelWidget,
                const SizedBox(width: FundLensTokens.space1),
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: FundLensTokens.muted,
                ),
              ],
            ),
          ),
        const SizedBox(height: FundLensTokens.space1),
        valueWidget,
      ],
    );
  }
}
