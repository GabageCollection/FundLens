import 'package:fundlens_core/fundlens_core.dart';

import '../../market/quote_refresh_service.dart';
import '../holdings/holding_status.dart';
import '../import_review/import_review_controller.dart';
import 'data_health_models.dart';

export 'data_health_models.dart' show DataHealthMetrics;

/// 单条持仓行情是否过期(仅对自动行情有意义)。
///
/// 沿用现有口径([QuoteRefreshService.maxQuoteAge] + 会话内刷新集合):
/// - 非自动行情恒不过期;
/// - 不在本次刷新集合中的自动行情视为过期(启动时安全降级);
/// - 估值日期缺失或超过最大可接受年龄视为过期。
bool isStaleQuote(Holding h, Set<String> freshQuoteHoldingIds, DateTime now) {
  if (h.valuationMethod != ValuationMethod.automaticQuote) return false;
  if (!freshQuoteHoldingIds.contains(h.id)) return true;
  if (h.valuationDate == null) return true;
  return h.valuationDate!.toUtc().isBefore(
    now.toUtc().subtract(QuoteRefreshService.maxQuoteAge),
  );
}

/// 从真实持仓数据计算数据健康指标。
DataHealthMetrics calculateDataHealthMetrics({
  required List<Holding> holdings,
  required Set<String> freshQuoteHoldingIds,
  required DecimalValue returnCoverage,
  required LastImportRecord? lastImport,
  required DateTime? lastQuoteRefresh,
  required DateTime now,
}) {
  final quotedHoldings = holdings
      .where((h) => h.valuationMethod == ValuationMethod.automaticQuote)
      .toList();

  final recognitionDenominator = holdings
      .where((h) => h.valuationMethod != ValuationMethod.manualAmount)
      .length;
  final recognitionCount = holdings
      .where(
        (h) =>
            h.valuationMethod != ValuationMethod.manualAmount &&
            h.productCode != null &&
            h.productCode!.trim().isNotEmpty,
      )
      .length;

  final classificationCount = holdings
      .where((h) => h.assetClass != AssetClass.other)
      .length;

  final costCount = holdings
      .where((h) {
        final cost = h.effectiveCostAmount;
        return cost != null && !cost.isZero;
      })
      .length;

  final quoteCoverageCount = quotedHoldings
      .where(
        (h) =>
            h.currentPrice != null &&
            !isStaleQuote(h, freshQuoteHoldingIds, now),
      )
      .length;

  final staleQuoteCount = quotedHoldings
      .where((h) => isStaleQuote(h, freshQuoteHoldingIds, now))
      .length;

  final pendingIssueCount = holdings
      .where(
        (h) =>
            deriveHoldingDataStatus(
              h,
              freshQuoteHoldingIds: freshQuoteHoldingIds,
            ) !=
            HoldingDataStatus.normal,
      )
      .length;

  DateTime? asOfDate;
  for (final h in holdings) {
    final date = h.valuationDate ?? h.updatedAt;
    if (date != null && (asOfDate == null || date.isAfter(asOfDate))) {
      asOfDate = date;
    }
  }

  return DataHealthMetrics(
    asOfDate: asOfDate,
    recognitionRate: CoverageMetric(
      count: recognitionCount,
      total: recognitionDenominator,
    ),
    classificationRate: CoverageMetric(
      count: classificationCount,
      total: holdings.length,
    ),
    costCoverageRate: CoverageMetric(count: costCount, total: holdings.length),
    quoteCoverageRate: CoverageMetric(
      count: quoteCoverageCount,
      total: quotedHoldings.length,
    ),
    returnCoverageRate: returnCoverage,
    staleQuoteCount: staleQuoteCount,
    pendingIssueCount: pendingIssueCount,
    lastImport: lastImport,
    lastQuoteRefresh: lastQuoteRefresh,
  );
}
