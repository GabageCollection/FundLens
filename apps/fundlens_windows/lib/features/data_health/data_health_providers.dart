import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../import_review/import_review_controller.dart';
import 'data_health_metrics.dart';
import 'data_health_models.dart';

export 'data_health_models.dart'
    show QuoteRefreshUiState, QuoteRefreshIdle, QuoteRefreshInProgress,
        QuoteRefreshFailed, DataHealthStatus, QuoteRefreshAttempt;
final quoteRefreshUiStateProvider =
    StateProvider<QuoteRefreshUiState>((ref) => const QuoteRefreshIdle());

/// The last quote refresh attempt; null until one runs in this session.
final lastQuoteRefreshAttemptProvider =
    StateProvider<QuoteRefreshAttempt?>((ref) => null);

/// 最近一次导入记录;从导入控制器读取(IndexedStack 保持页面存活,
/// 控制器在页面构建时已 restore)。
final lastImportRecordProvider = Provider<LastImportRecord?>((ref) {
  return ref.watch(importReviewControllerProvider).lastRecord;
});

/// 数据健康指标,由真实持仓数据派生。
final dataHealthMetricsProvider = Provider<DataHealthMetrics>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
  final freshIds = ref.watch(freshQuoteHoldingIdsProvider);
  final summary = ref.watch(portfolioSummaryProvider);
  final lastQuoteRefresh = ref.watch(lastQuoteRefreshAttemptProvider)?.at;
  final lastImport = ref.watch(lastImportRecordProvider);
  return calculateDataHealthMetrics(
    holdings: holdings,
    freshQuoteHoldingIds: freshIds,
    returnCoverage: summary.returnCoverage,
    lastImport: lastImport,
    lastQuoteRefresh: lastQuoteRefresh,
    now: DateTime.now(),
  );
});

/// 数据健康状态按钮五态。
final dataHealthStatusProvider = Provider<DataHealthStatus>((ref) {
  final uiState = ref.watch(quoteRefreshUiStateProvider);
  final metrics = ref.watch(dataHealthMetricsProvider);
  return deriveDataHealthStatus(uiState, metrics);
});
