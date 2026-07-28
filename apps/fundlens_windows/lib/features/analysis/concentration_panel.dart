import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'analysis_labels.dart';
import 'structure_thresholds.dart';

/// Factual structure panel: largest positions, exposures and data quality.
///
/// Values are compared only against thresholds explicitly set by the user.
/// When no threshold exists for a row, the actual value is shown without any
/// status judgment.
class ConcentrationPanel extends StatelessWidget {
  const ConcentrationPanel({
    super.key,
    required this.summary,
    required this.quality,
    required this.holdings,
    required this.thresholds,
  });

  final PortfolioSummary summary;
  final DataQualitySummary quality;
  final List<Holding> holdings;
  final StructureThresholds thresholds;

  @override
  Widget build(BuildContext context) {
    final largestHolding = _largestHolding();
    final largestClass = _largestAssetClass();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _factRow(
              context,
              label: '最大单项持仓',
              name: largestHolding?.productName,
              value: largestHolding == null
                  ? null
                  : formatShare(summary.largestHoldingShare),
              status: _maxStatus(
                summary.largestHoldingShare,
                thresholds.maxSingleHoldingShare,
              ),
            ),
            _factRow(
              context,
              label: '最大资产类别',
              name:
                  largestClass == null ? null : assetClassLabels[largestClass],
              value: largestClass == null
                  ? null
                  : formatShare(summary.largestAssetClassShare),
              status: _maxStatus(
                summary.largestAssetClassShare,
                thresholds.maxAssetClassShare,
              ),
            ),
            _factRow(
              context,
              label: '现金及存款占比',
              value: formatShare(summary.cashAndDepositShare),
              status: _minStatus(
                summary.cashAndDepositShare,
                thresholds.minCashAndDepositShare,
              ),
            ),
            _factRow(
              context,
              label: '权益敞口占比',
              value: formatShare(summary.equityExposureShare),
              status: _maxStatus(
                summary.equityExposureShare,
                thresholds.maxEquityExposureShare,
              ),
            ),
            _factRow(
              context,
              label: '数据完整度',
              value: formatShare(quality.dataCompleteness),
            ),
            _factRow(
              context,
              label: '收益覆盖度',
              value: formatShare(summary.returnCoverage),
            ),
            _factRow(
              context,
              label: '行情新鲜度',
              value: quality.quoteFreshness == null
                  ? '—'
                  : formatShare(quality.quoteFreshness!),
            ),
          ],
        ),
      ),
    );
  }

  Holding? _largestHolding() {
    if (holdings.isEmpty) return null;
    var best = holdings.first;
    for (final holding in holdings.skip(1)) {
      if (holding.currentValue.compareTo(best.currentValue) > 0) {
        best = holding;
      }
    }
    return best;
  }

  AssetClass? _largestAssetClass() {
    AssetClass? best;
    DecimalValue? bestValue;
    for (final entry in summary.byAssetClass.entries) {
      if (bestValue == null || entry.value.compareTo(bestValue) > 0) {
        best = entry.key;
        bestValue = entry.value;
      }
    }
    return best;
  }

  /// Comparison text for a "must not exceed" threshold; null when unset.
  String? _maxStatus(DecimalValue actual, DecimalValue? threshold) {
    if (threshold == null) return null;
    return actual.compareTo(threshold) > 0
        ? '超出你设置的阈值'
        : '在你设置的阈值范围内';
  }

  /// Comparison text for a "must not fall below" threshold; null when unset.
  String? _minStatus(DecimalValue actual, DecimalValue? threshold) {
    if (threshold == null) return null;
    return actual.compareTo(threshold) < 0
        ? '低于你设置的阈值'
        : '在你设置的阈值范围内';
  }

  Widget _factRow(
    BuildContext context, {
    required String label,
    String? name,
    String? value,
    String? status,
  }) {
    final numberStyle =
        Theme.of(context).extension<FundLensTextStyles>()!.financialNumber;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (name != null) ...[
            Text(name, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(value ?? '—', style: numberStyle)),
          if (status != null) _StatusChip(status: status),
        ],
      ),
    );
  }
}

/// Pill badge for a threshold comparison: soft green when inside the
/// threshold, soft red when outside (`.chip.ok` / `.chip.bad`).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final breached = status.startsWith('超出') || status.startsWith('低于');
    final background =
        breached ? FundLensTokens.profitSoft : FundLensTokens.lossSoft;
    final foreground = breached ? FundLensTokens.profit : FundLensTokens.loss;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'Noto Sans SC',
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          color: foreground,
        ),
      ),
    );
  }
}
