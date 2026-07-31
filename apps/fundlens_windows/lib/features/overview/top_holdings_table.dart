import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../app/app_shell.dart';
import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../analysis/analysis_labels.dart' show sourcePlatformLabels;
import 'asset_spectrum.dart';
import 'overview_formatters.dart';

/// 总览页“金额最高的持仓”表格。
///
/// 固定表头:产品名称 / 资产类别 / 来源平台 / 当前金额 / 资产占比 /
/// 持仓盈亏。金额与比例右对齐,产品名称左对齐;右上角提供
/// “查看全部持仓”入口。
class TopHoldingsTable extends ConsumerWidget {
  const TopHoldingsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(portfolioSummaryProvider);
    final holdings = ref.watch(filteredHoldingsProvider);
    final top = [...holdings]
      ..sort((a, b) => b.currentValue.compareTo(a.currentValue));
    final visible = top.take(5).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '金额最高的持仓',
                  style: theme.extension<FundLensTextStyles>()!.sectionTitle,
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('overview-view-all-holdings'),
                  onPressed: () => Actions.maybeInvoke(
                    context,
                    const SelectDestinationIntent(AppDestination.holdings),
                  ),
                  child: const Text('查看全部持仓'),
                ),
              ],
            ),
            const SizedBox(height: FundLensTokens.space2),
            const _HeaderRow(),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: FundLensTokens.space4,
                ),
                child: Text(
                  '当前筛选下没有持仓',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final holding in visible)
                _HoldingRow(
                  holding: holding,
                  share:
                      summary.holdingShares[holding.id] ?? DecimalValue.zero,
                ),
          ],
        ),
      ),
    );
  }
}

/// 列宽比例:名称 3 / 类别 1.2 / 平台 1.2 / 金额 2 / 占比 1.2 / 盈亏 2。
const _flex = (3.0, 1.2, 1.2, 2.0, 1.2, 2.0);

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    Widget cell(String label, double flex, {bool right = false}) => Expanded(
      flex: (flex * 10).round(),
      child: Text(
        label,
        style: style,
        textAlign: right ? TextAlign.right : TextAlign.left,
      ),
    );
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: FundLensTokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: FundLensTokens.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
      child: Row(
        children: [
          cell('产品名称', _flex.$1),
          cell('资产类别', _flex.$2),
          cell('来源平台', _flex.$3),
          cell('当前金额', _flex.$4, right: true),
          cell('资产占比', _flex.$5, right: true),
          cell('持仓盈亏', _flex.$6, right: true),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding, required this.share});

  final Holding holding;
  final DecimalValue share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = theme.extension<FundLensTextStyles>()!.financialNumber;
    final profit = holding.currentFloatingProfit;
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: FundLensTokens.surface,
        border: Border(bottom: BorderSide(color: FundLensTokens.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
      child: Row(
        children: [
          Expanded(
            flex: (_flex.$1 * 10).round(),
            child: Text(
              holding.productName,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: (_flex.$2 * 10).round(),
            child: Text(
              assetClassLabels[holding.assetClass]!,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: (_flex.$3 * 10).round(),
            child: Text(
              sourcePlatformLabels[holding.sourcePlatform]!,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: (_flex.$4 * 10).round(),
            child: Text(
              formatCurrency(holding.currentValue),
              style: number,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: (_flex.$5 * 10).round(),
            child: Text(
              formatPercent(share),
              style: number,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: (_flex.$6 * 10).round(),
            child: profit == null
                ? Text(
                    '—',
                    style: number,
                    textAlign: TextAlign.right,
                  )
                : Text(
                    formatSignedCurrency(profit),
                    style: number.copyWith(
                      color: profit.isNegative
                          ? FundLensTokens.loss
                          : FundLensTokens.profit,
                    ),
                    textAlign: TextAlign.right,
                  ),
          ),
        ],
      ),
    );
  }
}
