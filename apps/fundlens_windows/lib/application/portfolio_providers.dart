import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../features/overview/trend_chart.dart';
import '../importing/import_models.dart';
import 'app_dependencies.dart';
import 'portfolio_state.dart';
import 'selection_state.dart';

/// Single shared subscription to the holdings stream.
///
/// All page-level providers below derive from this one [StreamProvider], so
/// `HoldingRepository.watchAll` is subscribed exactly once per container.
final holdingsProvider = StreamProvider<List<Holding>>((ref) {
  return ref.watch(holdingRepositoryProvider).watchAll();
});

/// Distinct loading/empty/data/degraded view of the holdings stream.
final portfolioStateProvider = Provider<PortfolioState>((ref) {
  final holdings = ref.watch(holdingsProvider);
  return holdings.when(
    loading: () => const PortfolioLoading(),
    error: (error, _) => PortfolioDegraded(error),
    data: (list) => list.isEmpty
        ? const PortfolioEmpty()
        : PortfolioReady(List.unmodifiable(list)),
  );
});

final portfolioSummaryProvider = Provider<PortfolioSummary>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
  return ref.watch(portfolioCalculatorProvider).calculate(holdings);
});

final dataQualityProvider = Provider<DataQualitySummary>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
  final freshIds = ref.watch(freshQuoteHoldingIdsProvider);
  return ref
      .watch(dataQualityCalculatorProvider)
      .calculate(holdings, freshQuoteHoldingIds: freshIds);
});

/// Holdings filtered by the Asset Spectrum selection; unfiltered when no
/// asset class is selected.
final filteredHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
  final selected = ref.watch(selectedAssetClassProvider);
  return selected == null
      ? holdings
      : holdings
          .where((holding) => holding.assetClass == selected)
          .toList(growable: false);
});

final snapshotsProvider = FutureProvider<List<PortfolioSnapshot>>((ref) {
  return ref.watch(snapshotRepositoryProvider).getAll();
});

/// 净值趋势点:每个历史快照一点,加上当前持仓的实时点(仅当当前有资产)。
///
/// 快照为不可变历史,当前点来自实时汇总;不提供快照之外的任何历史。
final trendPointsProvider = Provider<List<TrendPoint>>((ref) {
  final snapshots =
      ref.watch(snapshotsProvider).value ?? const <PortfolioSnapshot>[];
  final points = [
    for (final snapshot in snapshots) trendPointFromSnapshot(snapshot),
  ];
  final summary = ref.watch(portfolioSummaryProvider);
  if (!summary.totalValue.isZero) {
    points.add(
      TrendPoint(
        at: DateTime.now(),
        totalValue: summary.totalValue,
        coveredCost: summary.totalCost,
      ),
    );
  }
  points.sort((a, b) => a.at.compareTo(b.at));
  return List.unmodifiable(points);
});

/// Data issues derived from the current holdings.
///
/// Issues are only surfaced on the import/recognition page; other pages link
/// to it. Stale automatic quotes are informational, malformed rows warn.
final dataIssuesProvider = Provider<List<DataIssue>>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
  final freshIds = ref.watch(freshQuoteHoldingIdsProvider);
  final issues = <DataIssue>[];
  for (final holding in holdings) {
    if (holding.productName.trim().isEmpty) {
      issues.add(const DataIssue(
        code: 'missing_product_name',
        field: 'productName',
        severity: IssueSeverity.warning,
        message: '持仓缺少产品名称',
      ));
    }
    if (holding.currency.trim().isEmpty) {
      issues.add(const DataIssue(
        code: 'missing_currency',
        field: 'currency',
        severity: IssueSeverity.warning,
        message: '持仓缺少币种',
      ));
    }
    if (holding.currentValue.isNegative) {
      issues.add(const DataIssue(
        code: 'negative_current_value',
        field: 'currentValue',
        severity: IssueSeverity.warning,
        message: '当前金额为负数',
      ));
    }
    if (holding.valuationMethod == ValuationMethod.automaticQuote &&
        !freshIds.contains(holding.id)) {
      issues.add(const DataIssue(
        code: 'stale_quote',
        field: 'currentPrice',
        severity: IssueSeverity.info,
        message: '行情未更新，显示的是最近一次估值',
      ));
    }
  }
  return List.unmodifiable(issues);
});
