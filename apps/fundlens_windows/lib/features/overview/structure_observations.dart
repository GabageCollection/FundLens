import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_tokens.dart';
import 'asset_spectrum.dart';

/// Factual structure observations for the overview page.
///
/// Texts state measured shares only (e.g. “最大单项占总资产 34.9%”). No ideal
/// allocation, thresholds or action verbs ever appear here.
class StructureObservations extends ConsumerWidget {
  const StructureObservations({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    if (summary.totalValue.isZero) return const SizedBox.shrink();

    final observations = [
      '最大单项占总资产 ${formatPercent(summary.largestHoldingShare)}',
      '最大资产类别占总资产 ${formatPercent(summary.largestAssetClassShare)}',
      '现金及存款占总资产 ${formatPercent(summary.cashAndDepositShare)}',
      '权益敞口占总资产 ${formatPercent(summary.equityExposureShare)}',
    ];

    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final observation in observations)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: FundLensTokens.space1,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(
                    top: FundLensTokens.space2,
                    right: FundLensTokens.space3,
                  ),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: FundLensTokens.accent,
                  ),
                ),
                Expanded(child: Text(observation, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}
