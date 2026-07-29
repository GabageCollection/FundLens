import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../application/portfolio_state.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../holdings/holding_editor_dialog.dart';
import 'asset_spectrum.dart';
import 'structure_observations.dart';
import 'summary_strip.dart';

/// 资产总览 page: summary strip, interactive Asset Spectrum, factual
/// structure observations, top holdings and quote freshness.
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioStateProvider);
    return switch (state) {
      PortfolioLoading() => const Center(child: CircularProgressIndicator()),
      PortfolioDegraded(:final error) => Center(child: Text('数据暂时不可用：$error')),
      PortfolioEmpty() => Center(
        child: FilledButton.icon(
          key: const ValueKey('overview-add-first-asset'),
          onPressed: () => _addFirstAsset(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('添加第一项资产'),
        ),
      ),
      PortfolioReady() => const _OverviewContent(),
    };
  }

  Future<void> _addFirstAsset(BuildContext context, WidgetRef ref) async {
    final holding = await showHoldingEditorDialog(context);
    if (holding == null) return;
    await ref.read(holdingRepositoryProvider).upsert(holding);
  }
}

class _OverviewContent extends ConsumerWidget {
  const _OverviewContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final holdings = ref.watch(filteredHoldingsProvider);
    final topHoldings = [...holdings]
      ..sort((a, b) => b.currentValue.compareTo(a.currentValue));
    final visible = topHoldings.take(5).toList(growable: false);
    final dataQuality = ref.watch(dataQualityProvider);
    final freshness = dataQuality.quoteFreshness;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(FundLensTokens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('资产总览', style: theme.textTheme.titleLarge),
          const SizedBox(height: FundLensTokens.titleGap),
          const SummaryStrip(),
          const SizedBox(height: FundLensTokens.cardGap),
          const AssetSpectrum(),
          const SizedBox(height: FundLensTokens.cardGap),
          const StructureObservations(),
          const SizedBox(height: FundLensTokens.cardGap),
          Text(
            '金额最高的持仓',
            style: theme.extension<FundLensTextStyles>()!.sectionTitle,
          ),
          const SizedBox(height: FundLensTokens.space2),
          for (final holding in visible) _TopHoldingRow(holding: holding),
          const SizedBox(height: FundLensTokens.cardGap),
          Text(
            freshness == null
                ? '行情新鲜度：无自动行情持仓'
                : '行情新鲜度：${formatPercent(freshness)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TopHoldingRow extends StatelessWidget {
  const _TopHoldingRow({required this.holding});

  final Holding holding;

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
            flex: 3,
            child: Text(
              holding.productName,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              assetClassLabels[holding.assetClass]!,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              holding.currentValue.canonical,
              style: number,
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: profit == null
                ? const SizedBox.shrink()
                : Text(
                    formatSignedAmount(profit),
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
