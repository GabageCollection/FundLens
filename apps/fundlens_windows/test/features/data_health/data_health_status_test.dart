import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/data_health/data_health_models.dart';

DataHealthMetrics metrics({
  CoverageMetric recognitionRate = const CoverageMetric(count: 2, total: 2),
  CoverageMetric classificationRate =
      const CoverageMetric(count: 2, total: 2),
  CoverageMetric costCoverageRate = const CoverageMetric(count: 2, total: 2),
  CoverageMetric quoteCoverageRate =
      const CoverageMetric(count: 2, total: 2),
  DecimalValue? returnCoverageRate,
  int staleQuoteCount = 0,
  int pendingIssueCount = 0,
}) {
  return DataHealthMetrics(
    asOfDate: null,
    recognitionRate: recognitionRate,
    classificationRate: classificationRate,
    costCoverageRate: costCoverageRate,
    quoteCoverageRate: quoteCoverageRate,
    returnCoverageRate: returnCoverageRate ?? DecimalValue.parse('1'),
    staleQuoteCount: staleQuoteCount,
    pendingIssueCount: pendingIssueCount,
    lastImport: null,
    lastQuoteRefresh: null,
  );
}

void main() {
  group('五态优先级:刷新失败 > 正在刷新 > 需要更新 > 部分缺失 > 正常', () {
    test('刷新失败优先于一切', () {
      expect(
        deriveDataHealthStatus(
          const QuoteRefreshFailed('引擎不可用'),
          metrics(),
        ),
        DataHealthStatus.refreshFailed,
      );
    });

    test('正在刷新覆盖需要更新/部分缺失', () {
      expect(
        deriveDataHealthStatus(
          const QuoteRefreshInProgress(),
          metrics(costCoverageRate: const CoverageMetric(count: 1, total: 2)),
        ),
        DataHealthStatus.refreshing,
      );
    });

    test('存在过期行情 → 需要更新(即使同时有部分缺失)', () {
      expect(
        deriveDataHealthStatus(
          const QuoteRefreshIdle(),
          metrics(
            staleQuoteCount: 2,
            quoteCoverageRate: const CoverageMetric(count: 0, total: 2),
            pendingIssueCount: 1,
          ),
        ),
        DataHealthStatus.needsUpdate,
      );
    });

    test('无过期行情时,成本覆盖不足 → 部分缺失', () {
      expect(
        deriveDataHealthStatus(
          const QuoteRefreshIdle(),
          metrics(costCoverageRate: const CoverageMetric(count: 1, total: 2)),
        ),
        DataHealthStatus.partialMissing,
      );
    });

    test('仅待处理异常数量 > 0 → 部分缺失', () {
      expect(
        deriveDataHealthStatus(
          const QuoteRefreshIdle(),
          metrics(pendingIssueCount: 1),
        ),
        DataHealthStatus.partialMissing,
      );
    });

    test('识别率不足 → 部分缺失', () {
      expect(
        deriveDataHealthStatus(
          const QuoteRefreshIdle(),
          metrics(recognitionRate: const CoverageMetric(count: 1, total: 2)),
        ),
        DataHealthStatus.partialMissing,
      );
    });

    test('空仓(覆盖率均不适用) → 正常', () {
      expect(
        deriveDataHealthStatus(
          const QuoteRefreshIdle(),
          metrics(
            recognitionRate: const CoverageMetric(count: 0, total: 0),
            classificationRate: const CoverageMetric(count: 0, total: 0),
            costCoverageRate: const CoverageMetric(count: 0, total: 0),
            quoteCoverageRate: const CoverageMetric(count: 0, total: 0),
            returnCoverageRate: DecimalValue.zero,
          ),
        ),
        DataHealthStatus.normal,
      );
    });

    test('健康指标且刷新空闲 → 正常', () {
      expect(
        deriveDataHealthStatus(const QuoteRefreshIdle(), metrics()),
        DataHealthStatus.normal,
      );
    });
  });
}
