import 'package:fundlens_core/fundlens_core.dart';

import '../import_review/import_review_controller.dart';

/// 最近一次行情刷新的事实记录。
final class QuoteRefreshAttempt {
  const QuoteRefreshAttempt({
    required this.at,
    required this.source,
    required this.updated,
    required this.failed,
  });

  final DateTime at;
  final String source;
  final int updated;
  final int failed;
}

/// 行情刷新在界面层的整体状态,驱动状态按钮与失败原因展示。
sealed class QuoteRefreshUiState {
  const QuoteRefreshUiState();
}

/// 空闲:未在刷新,最近一次刷新成功或尚未进行。
final class QuoteRefreshIdle extends QuoteRefreshUiState {
  const QuoteRefreshIdle();
}

/// 刷新进行中。
final class QuoteRefreshInProgress extends QuoteRefreshUiState {
  const QuoteRefreshInProgress();
}

/// 刷新失败,携带给用户看的失败原因。
final class QuoteRefreshFailed extends QuoteRefreshUiState {
  const QuoteRefreshFailed(this.reason);
  final String reason;
}

/// 全局数据健康状态(状态按钮五态)。
enum DataHealthStatus { normal, partialMissing, needsUpdate, refreshing, refreshFailed }

/// 单项覆盖率:count/total 及比值。
///
/// [ratio] 在 total == 0(不适用)时为 null,界面据此显示"不适用"而不是 100%。
final class CoverageMetric {
  const CoverageMetric({required this.count, required this.total});

  final int count;
  final int total;

  double? get ratio => total == 0 ? null : count / total;
}

/// 派生全局数据健康状态,优先级从高到低:
/// 刷新失败 > 正在刷新 > 需要更新(行情过期) > 部分缺失(字段/分类/成本) > 正常。
DataHealthStatus deriveDataHealthStatus(
  QuoteRefreshUiState uiState,
  DataHealthMetrics metrics,
) {
  if (uiState is QuoteRefreshFailed) return DataHealthStatus.refreshFailed;
  if (uiState is QuoteRefreshInProgress) return DataHealthStatus.refreshing;
  if (metrics.staleQuoteCount > 0) return DataHealthStatus.needsUpdate;
  // 收益覆盖率:zero 表示总资产为 0(空仓),不适用而非缺失;真实缺失
  // (总资产>0 但成本缺失)会同时由 pendingIssueCount 命中。
  final returnIncomplete = !metrics.returnCoverageRate.isZero &&
      metrics.returnCoverageRate.compareTo(DecimalValue.parse('1')) != 0;
  if (metrics.pendingIssueCount > 0 ||
      _isCovered(metrics.recognitionRate) ||
      _isCovered(metrics.classificationRate) ||
      _isCovered(metrics.costCoverageRate) ||
      _isCovered(metrics.quoteCoverageRate) ||
      returnIncomplete) {
    return DataHealthStatus.partialMissing;
  }
  return DataHealthStatus.normal;
}

/// 覆盖率缺失:total 为 0(不适用)时不算缺失。
bool _isCovered(CoverageMetric metric) {
  final ratio = metric.ratio;
  return ratio != null && ratio < 1.0;
}

/// 数据健康面板展示的指标快照,全部由真实持仓数据派生。
final class DataHealthMetrics {
  const DataHealthMetrics({
    required this.asOfDate,
    required this.recognitionRate,
    required this.classificationRate,
    required this.costCoverageRate,
    required this.quoteCoverageRate,
    required this.returnCoverageRate,
    required this.staleQuoteCount,
    required this.pendingIssueCount,
    required this.lastImport,
    required this.lastQuoteRefresh,
  });

  /// 数据截至时间:全部持仓估值日期的最大值;无估值日期时取更新时间最大值。
  final DateTime? asOfDate;

  /// 持仓识别率:有产品代码的持仓数 ÷ 需识别持仓数。
  final CoverageMetric recognitionRate;

  /// 资产分类率:非"其他"分类的持仓数 ÷ 持仓总数。
  final CoverageMetric classificationRate;

  /// 成本覆盖率:有有效成本的持仓数 ÷ 持仓总数。
  final CoverageMetric costCoverageRate;

  /// 行情覆盖率:行情有效(有价且未过期)的自动行情持仓数 ÷ 自动行情持仓总数。
  final CoverageMetric quoteCoverageRate;

  /// 收益覆盖率:复用 PortfolioSummary.returnCoverage(有成本资产金额 ÷ 总资产)。
  final DecimalValue returnCoverageRate;

  /// 过期行情数量:自动行情持仓中行情过期或缺失的数量。
  final int staleQuoteCount;

  /// 待处理异常数量:数据状态非"正常"的持仓数。
  final int pendingIssueCount;

  /// 最近一次导入记录;无导入时为 null。
  final LastImportRecord? lastImport;

  /// 最近一次行情刷新时间;本会话未刷新时为 null。
  final DateTime? lastQuoteRefresh;
}
