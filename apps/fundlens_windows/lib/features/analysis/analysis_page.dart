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
    DecimalValue shareOf(DecimalValue amount) =>
        total.isZero ? DecimalValue.zero : amount.divide(total);

    final rows = switch (_dimension) {
      AnalysisDimension.assetClass => summary.byAssetClass.entries
          .map(
            (entry) => CompositionRow(
              label: assetClassLabels[entry.key]!,
              amount: entry.value,
              share: shareOf(entry.value),
              color: FundLensTokens.categoryColors[entry.key],
            ),
          )
          .toList(),
      AnalysisDimension.instrumentType => summary.byInstrumentType.entries
          .map(
            (entry) => CompositionRow(
              label: instrumentTypeLabels[entry.key]!,
              amount: entry.value,
              share: shareOf(entry.value),
              color: _instrumentTypeColor(entry.key),
            ),
          )
          .toList(),
      AnalysisDimension.source => summary.bySource.entries
          .map(
            (entry) => CompositionRow(
              label: sourcePlatformLabels[entry.key]!,
              amount: entry.value,
              share: shareOf(entry.value),
              color: FundLensTokens.categoryColors[AssetClass.other],
            ),
          )
          .toList(),
    };
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    return rows;
  }

  /// Decorative bar color per instrument type, borrowed from the asset-class
  /// palette of the class it typically belongs to.
  static Color? _instrumentTypeColor(InstrumentType type) {
    final assetClass = switch (type) {
      InstrumentType.cashManagement => AssetClass.cash,
      InstrumentType.bankDeposit => AssetClass.deposit,
      InstrumentType.stock || InstrumentType.etf => AssetClass.equity,
      InstrumentType.lof || InstrumentType.offExchangeFund => AssetClass.mixed,
      InstrumentType.reit => AssetClass.other,
      InstrumentType.accumulatedGold ||
      InstrumentType.physicalGold => AssetClass.gold,
    };
    return FundLensTokens.categoryColors[assetClass];
  }
}
