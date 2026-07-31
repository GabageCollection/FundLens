import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'asset_spectrum.dart';
import 'overview_formatters.dart';

/// 各 KPI 指标的一句话口径说明,以 Tooltip 呈现。
const _kpiTooltips = <String, String>{
  '总资产': '当前全部持仓金额之和',
  '覆盖成本': '有成本数据持仓的成本之和',
  '浮动盈亏': '当前金额减去持有成本,仅统计有成本资产',
  '总收益率': '有成本资产的浮动盈亏之和除以其成本之和',
  '收益覆盖率': '有成本数据资产的当前金额占总资产的比例',
};

/// 总览页顶部 KPI 区:总资产、覆盖成本、浮动盈亏、总收益率、收益覆盖率。
///
/// 金额带币种符号与千位分隔;盈亏同时显示 `+`/`-` 符号与红/绿颜色
/// (国内习惯:红盈利、绿亏损),不单独依赖颜色。底部标注数据截至时间。
class SummaryStrip extends ConsumerWidget {
  const SummaryStrip({super.key});

  DateTime? _dataAsOf(List<Holding> holdings) {
    DateTime? latest;
    for (final holding in holdings) {
      final at = holding.valuationDate ?? holding.updatedAt;
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    return latest;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final holdings = ref.watch(holdingsProvider).value ?? const <Holding>[];
    final asOf = _dataAsOf(holdings);
    final cells = <Widget>[
      _SummaryCell(label: '总资产', value: formatCurrency(summary.totalValue)),
      _SummaryCell(label: '覆盖成本', value: formatCurrency(summary.totalCost)),
      _SignedSummaryCell(label: '浮动盈亏', value: summary.totalFloatingProfit),
      _SignedSummaryCell(
        label: '总收益率',
        value: summary.totalReturn,
        asPercent: true,
      ),
      _SummaryCell(
        label: '收益覆盖率',
        value: formatPercent(summary.returnCoverage),
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FundLensTokens.cardPadding,
          vertical: FundLensTokens.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
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
            if (asOf != null) ...[
              const SizedBox(height: FundLensTokens.space3),
              Text(
                '数据截至 ${formatAsOf(asOf)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 1px vertical rule between KPI cells (`.kpi + .kpi` border in the design).
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

/// KPI 标签行:标签文字 + 口径说明 Tooltip(信息图标)。
class _LabelWithTooltip extends StatelessWidget {
  const _LabelWithTooltip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tooltip = _kpiTooltips[label];
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.bodySmall,
    );
    if (tooltip == null) return labelWidget;
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          labelWidget,
          const SizedBox(width: FundLensTokens.space1),
          const Icon(
            Icons.info_outline,
            size: 13,
            color: FundLensTokens.muted,
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kpi = theme.extension<FundLensTextStyles>()!.kpiNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelWithTooltip(label: label),
        const SizedBox(height: FundLensTokens.space1),
        Text(value, style: kpi),
      ],
    );
  }
}

class _SignedSummaryCell extends StatelessWidget {
  const _SignedSummaryCell({
    required this.label,
    required this.value,
    this.asPercent = false,
  });

  final String label;
  final DecimalValue? value;
  final bool asPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kpi = theme.extension<FundLensTextStyles>()!.kpiNumber;
    if (value == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelWithTooltip(label: label),
          const SizedBox(height: FundLensTokens.space1),
          Text('—', style: kpi),
        ],
      );
    }
    final signed = value!;
    final color = signed.isNegative
        ? FundLensTokens.loss
        : FundLensTokens.profit;
    final text = asPercent
        ? '${signed.isNegative ? '-' : '+'}'
              '${(signed.value.abs().toDouble() * 100).toStringAsFixed(1)}%'
        : formatSignedCurrency(signed);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelWithTooltip(label: label),
        const SizedBox(height: FundLensTokens.space1),
        Text(text, style: kpi.copyWith(color: color)),
      ],
    );
  }
}
