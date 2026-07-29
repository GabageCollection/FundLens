import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../analysis/analysis_labels.dart';

/// Two-snapshot comparison: total amount change, per-class changes and
/// per-holding changes with added/removed badges. The delta is always
/// labelled "资产金额变化".
class SnapshotCompareView extends ConsumerStatefulWidget {
  const SnapshotCompareView({super.key, required this.snapshots});

  final List<PortfolioSnapshot> snapshots;

  @override
  ConsumerState<SnapshotCompareView> createState() =>
      _SnapshotCompareViewState();
}

class _SnapshotCompareViewState extends ConsumerState<SnapshotCompareView> {
  final _diffService = SnapshotDiffService();
  String? _beforeId;
  String? _afterId;

  List<PortfolioSnapshot> get _sorted {
    final sorted = List<PortfolioSnapshot>.of(widget.snapshots)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;
    if (sorted.length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('至少需要两个快照才能比较'),
      );
    }

    // Default to the two latest snapshots.
    final before = sorted.firstWhere(
      (s) => s.id == _beforeId,
      orElse: () => sorted[1],
    );
    final after = sorted.firstWhere(
      (s) => s.id == _afterId,
      orElse: () => sorted[0],
    );
    final diff = _diffService.compare(before, after);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _selector(
                context,
                label: '较早快照',
                value: before.id,
                snapshots: sorted,
                onChanged: (id) => setState(() => _beforeId = id),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _selector(
                context,
                label: '较晚快照',
                value: after.id,
                snapshots: sorted,
                onChanged: (id) => setState(() => _afterId = id),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _totalChange(context, diff),
        const SizedBox(height: 16),
        _classChanges(context, diff),
        const SizedBox(height: 16),
        _holdingChanges(context, before, after, diff),
      ],
    );
  }

  Widget _selector(
    BuildContext context, {
    required String label,
    required String value,
    required List<PortfolioSnapshot> snapshots,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: [
            for (final snapshot in snapshots)
              DropdownMenuItem(
                value: snapshot.id,
                child: Text(
                  '${_formatDate(snapshot.createdAt)} ${snapshot.label}',
                ),
              ),
          ],
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ],
    );
  }

  Widget _totalChange(BuildContext context, SnapshotDiff diff) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diff.metricLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            _signedAmount(context, diff.totalAmountChange, large: true),
          ],
        ),
      ),
    );
  }

  Widget _classChanges(BuildContext context, SnapshotDiff diff) {
    final entries = diff.assetClassAmountChanges.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('资产类别变化', style: Theme.of(context).textTheme.labelLarge),
            const Divider(height: FundLensTokens.space4),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: FundLensTokens.space2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        assetClassLabels[entry.key] ?? entry.key.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    _signedAmount(context, entry.value),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _holdingChanges(
    BuildContext context,
    PortfolioSnapshot before,
    PortfolioSnapshot after,
    SnapshotDiff diff,
  ) {
    final beforeById = {for (final h in before.holdings) h.holdingId: h};
    final afterById = {for (final h in after.holdings) h.holdingId: h};
    final ids = diff.holdingAmountChanges.keys.toList()
      ..sort(
        (a, b) => diff.holdingAmountChanges[b]!.compareTo(
          diff.holdingAmountChanges[a]!,
        ),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('持仓变化', style: Theme.of(context).textTheme.labelLarge),
            const Divider(height: FundLensTokens.space4),
            for (final id in ids)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: FundLensTokens.space2,
                ),
                child: Row(
                  children: [
                    if (!beforeById.containsKey(id))
                      const _ChangeBadge(label: '新增')
                    else if (!afterById.containsKey(id))
                      const _ChangeBadge(label: '移除'),
                    Expanded(
                      child: Text(
                        (afterById[id] ?? beforeById[id])!.productName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    _signedAmount(context, diff.holdingAmountChanges[id]!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _signedAmount(
    BuildContext context,
    DecimalValue value, {
    bool large = false,
  }) {
    final styles = Theme.of(context).extension<FundLensTextStyles>()!;
    final base = large ? styles.kpiNumber : styles.financialNumber;
    final color = value.isNegative
        ? FundLensTokens.loss
        : value.isZero
        ? FundLensTokens.ink
        : FundLensTokens.profit;
    return Text(formatSignedAmount(value), style: base.copyWith(color: color));
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: FundLensTokens.space2),
      padding: const EdgeInsets.symmetric(
        horizontal: FundLensTokens.space2,
        vertical: FundLensTokens.space1,
      ),
      decoration: BoxDecoration(
        color: FundLensTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
        border: Border.all(color: FundLensTokens.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
