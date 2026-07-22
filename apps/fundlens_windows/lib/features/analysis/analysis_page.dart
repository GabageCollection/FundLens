import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_tokens.dart';
import 'analysis_labels.dart';
import 'composition_table.dart';
import 'concentration_panel.dart';
import 'structure_thresholds.dart';

enum AnalysisDimension { assetClass, instrumentType, source }

/// Structural analysis page: factual composition views and concentration
/// facts. No allocation advice is emitted anywhere on this page.
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  AnalysisDimension _dimension = AnalysisDimension.assetClass;

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(portfolioSummaryProvider);
    final quality = ref.watch(dataQualityProvider);
    final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
    final thresholds = ref.watch(structureThresholdsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(FundLensTokens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('资产分析', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          SegmentedButton<AnalysisDimension>(
            segments: const [
              ButtonSegment(
                value: AnalysisDimension.assetClass,
                label: Text('资产类别'),
              ),
              ButtonSegment(
                value: AnalysisDimension.instrumentType,
                label: Text('产品类型'),
              ),
              ButtonSegment(
                value: AnalysisDimension.source,
                label: Text('来源平台'),
              ),
            ],
            selected: {_dimension},
            onSelectionChanged: (selection) {
              setState(() => _dimension = selection.first);
            },
          ),
          const SizedBox(height: 20),
          CompositionTable(rows: _rowsFor(summary)),
          const SizedBox(height: 20),
          ConcentrationPanel(
            summary: summary,
            quality: quality,
            holdings: holdings,
            thresholds: thresholds,
          ),
        ],
      ),
    );
  }

  List<CompositionRow> _rowsFor(PortfolioSummary summary) {
    final total = summary.totalValue;
    final rows = switch (_dimension) {
      AnalysisDimension.assetClass => summary.byAssetClass.entries
          .map((entry) => (assetClassLabels[entry.key]!, entry.value)),
      AnalysisDimension.instrumentType => summary.byInstrumentType.entries
          .map((entry) => (instrumentTypeLabels[entry.key]!, entry.value)),
      AnalysisDimension.source => summary.bySource.entries
          .map((entry) => (sourcePlatformLabels[entry.key]!, entry.value)),
    }
        .map(
          (entry) => CompositionRow(
            label: entry.$1,
            amount: entry.$2,
            share: total.isZero ? DecimalValue.zero : entry.$2.divide(total),
          ),
        )
        .toList();
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }
}
