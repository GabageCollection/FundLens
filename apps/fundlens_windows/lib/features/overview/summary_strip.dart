import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'asset_spectrum.dart';

/// Top strip of the overview page: total assets, covered cost, floating
/// profit, total return and return coverage. Profit is red with `+`, loss is
/// green with `-`; the sign is always printed, never color alone.
class SummaryStrip extends ConsumerWidget {
  const SummaryStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final cells = <Widget>[
      _SummaryCell(label: '总资产', value: summary.totalValue.canonical),
      _SummaryCell(label: '覆盖成本', value: summary.totalCost.canonical),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const _CellDivider(),
              cells[i],
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
      margin: const EdgeInsets.only(right: 20),
      color: FundLensTokens.border,
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
    final number =
        theme.extension<FundLensTextStyles>()!.financialNumber;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: number.copyWith(fontSize: 18)),
        ],
      ),
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
    final number =
        theme.extension<FundLensTextStyles>()!.financialNumber;
    if (value == null) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('—', style: number.copyWith(fontSize: 18)),
          ],
        ),
      );
    }
    final signed = value!;
    final color = signed.isNegative ? FundLensTokens.loss : FundLensTokens.profit;
    final text = asPercent
        ? '${signed.isNegative ? '-' : '+'}'
            '${(signed.value.abs().toDouble() * 100).toStringAsFixed(1)}%'
        : formatSignedAmount(signed);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            text,
            style: number.copyWith(fontSize: 18, color: color),
          ),
        ],
      ),
    );
  }
}
