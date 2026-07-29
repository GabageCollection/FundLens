import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'analysis_labels.dart';

/// One exact amount/share row in a composition view.
final class CompositionRow {
  const CompositionRow({
    required this.label,
    required this.amount,
    required this.share,
    this.color,
  });

  final String label;
  final DecimalValue amount;

  /// Share of the total in the range 0..1.
  final DecimalValue share;

  /// Decorative share-bar color; falls back to the accent when null.
  final Color? color;
}

/// Exact amount/share table with a thin proportional bar per row.
class CompositionTable extends StatelessWidget {
  const CompositionTable({super.key, required this.rows});

  final List<CompositionRow> rows;

  @override
  Widget build(BuildContext context) {
    final numberStyle =
        Theme.of(context).extension<FundLensTextStyles>()!.financialNumber;
    final labelStyle = Theme.of(context).textTheme.bodyMedium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('名称',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                SizedBox(
                  width: 140,
                  child: Text('金额',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                SizedBox(
                  width: 90,
                  child: Text('占比',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
            const Divider(height: 17),
            for (final row in rows) ...[
              Row(
                children: [
                  Expanded(child: Text(row.label, style: labelStyle)),
                  SizedBox(
                    width: 140,
                    child: Text(
                      formatAmount(row.amount),
                      textAlign: TextAlign.right,
                      style: numberStyle,
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      formatShare(row.share),
                      textAlign: TextAlign.right,
                      style: numberStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final share = double.parse(row.share.canonical)
                      .clamp(0.0, 1.0)
                      .toDouble();
                  return Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: FundLensTokens.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(FundLensTokens.radiusSmall),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: constraints.maxWidth * share,
                      height: 4,
                      decoration: BoxDecoration(
                        color: row.color ?? FundLensTokens.accent,
                        borderRadius:
                            BorderRadius.circular(FundLensTokens.radiusSmall),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
