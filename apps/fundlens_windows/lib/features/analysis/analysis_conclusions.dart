import 'package:fundlens_core/fundlens_core.dart';

import '../../app/app_shell.dart';
import 'analysis_labels.dart';
import 'structure_thresholds.dart';

/// 结论状态:正常(绿)/提示(琥珀)/需要处理(红)。
enum ConclusionStatus { normal, attention, warning }

/// 分析结论卡中的一行:指标名称、当前结果、状态标签、一句话解释与可选入口。
final class ConclusionItem {
  const ConclusionItem({
    required this.name,
    required this.result,
    this.status,
    required this.explanation,
    this.action,
    this.actionLabel,
  });

  final String name;

  /// 当前结果(已格式化的金额/百分比,或 '—')。
  final String result;

  /// 状态标签;null 表示不输出状态判断(如未设阈值)。
  final ConclusionStatus? status;

  /// 一句话解释(只陈述可测量的事实,不包含投资行为措辞)。
  final String explanation;

  /// 修复入口跳转目标;null 表示无需处理。
  final AppDestination? action;
  final String? actionLabel;
}

/// 基于当前持仓与组合汇总生成五项分析结论。
///
/// 只陈述事实与数据问题:分类不足时优先提示数据问题,不输出
/// "最大资产类别:其他 100%"这类误导性结论。
List<ConclusionItem> buildAnalysisConclusions({
  required PortfolioSummary summary,
  required DataQualitySummary quality,
  required List<Holding> holdings,
  required StructureThresholds thresholds,
  required Set<String> freshQuoteHoldingIds,
}) {
  // 1. 资产结构:已分类率 = 1 − 其他占比。
  final otherAmount =
      summary.byAssetClass[AssetClass.other] ?? DecimalValue.zero;
  final classifiedRate = summary.totalValue.isZero
      ? DecimalValue.zero
      : DecimalValue.parse('1') - otherAmount.divide(summary.totalValue);
  final uncategorized = holdings
      .where((h) => h.assetClass == AssetClass.other)
      .length;
  final classifiedResult = formatShare(classifiedRate);
  final ConclusionItem structure;
  if (classifiedRate.compareTo(DecimalValue.parse('1')) < 0) {
    structure = ConclusionItem(
      name: '资产结构',
      result: classifiedResult,
      status: ConclusionStatus.warning,
      explanation: uncategorized == holdings.length
          ? '全部资产暂时被归入"其他",请补充资产类别后再进行结构分析。'
          : '有 $uncategorized 项持仓未归入明确类别,结构占比可能失真。',
      action: AppDestination.holdings,
      actionLabel: '补充资产分类',
    );
  } else {
    structure = ConclusionItem(
      name: '资产结构',
      result: classifiedResult,
      status: ConclusionStatus.normal,
      explanation: '所有资产均已明确分类,结构占比真实可靠。',
    );
  }

  // 2. 集中度:最大单项持仓占比(仅当设置阈值时输出判断)。
  final largest = _largestHolding(holdings);
  final threshold = thresholds.maxSingleHoldingShare;
  final ConclusionStatus? concentrationStatus;
  final String concentrationExplanation;
  if (threshold == null) {
    concentrationStatus = null;
    concentrationExplanation = '未设置集中度阈值,仅展示实际占比。';
  } else if (summary.largestHoldingShare.compareTo(threshold) > 0) {
    concentrationStatus = ConclusionStatus.warning;
    concentrationExplanation = '单一产品的价格波动会明显影响总资产的变化幅度。';
  } else {
    concentrationStatus = ConclusionStatus.normal;
    concentrationExplanation = '最大单项持仓占比在你设置的阈值范围内。';
  }
  final concentration = ConclusionItem(
    name: '集中度',
    result: largest == null
        ? formatShare(summary.largestHoldingShare)
        : '${largest.productName} ${formatShare(summary.largestHoldingShare)}',
    status: concentrationStatus,
    explanation: concentrationExplanation,
    action: concentrationStatus == ConclusionStatus.warning
        ? AppDestination.holdings
        : null,
    actionLabel: concentrationStatus == ConclusionStatus.warning
        ? '查看持仓'
        : null,
  );

  // 3. 数据质量:字段完整度。
  final complete =
      quality.dataCompleteness.compareTo(DecimalValue.parse('1')) >= 0;
  final qualityItem = ConclusionItem(
    name: '数据质量',
    result: formatShare(quality.dataCompleteness),
    status: complete ? ConclusionStatus.normal : ConclusionStatus.attention,
    explanation: complete ? '持仓字段完整,可直接进行结构分析。' : '存在缺字段的持仓,请核对数据状态。',
    action: complete ? null : AppDestination.importReview,
    actionLabel: complete ? null : '查看数据状态',
  );

  // 4. 收益覆盖:有成本资产金额占总资产比例。
  final covered = summary.totalValue * summary.returnCoverage;
  final uncovered = summary.totalValue - covered;
  final coveredFull =
      summary.returnCoverage.compareTo(DecimalValue.parse('1')) >= 0;
  final coverage = ConclusionItem(
    name: '收益覆盖',
    result: formatShare(summary.returnCoverage),
    status: coveredFull ? ConclusionStatus.normal : ConclusionStatus.attention,
    explanation: coveredFull
        ? '全部资产均纳入收益统计。'
        : '¥${formatAmount(uncovered)} 的资产缺少成本,未纳入收益统计。',
    action: coveredFull ? null : AppDestination.holdings,
    actionLabel: coveredFull ? null : '查看持仓',
  );

  // 5. 行情新鲜度:自动行情持仓中已刷新金额的占比。
  final freshness = quality.quoteFreshness;
  final ConclusionItem freshnessItem;
  if (freshness == null) {
    freshnessItem = ConclusionItem(
      name: '行情新鲜度',
      result: '—',
      explanation: '没有自动行情持仓,不涉及行情新鲜度。',
    );
  } else {
    final fresh = freshness.compareTo(DecimalValue.parse('1')) >= 0;
    final staleCount = holdings
        .where(
          (h) =>
              h.valuationMethod == ValuationMethod.automaticQuote &&
              !freshQuoteHoldingIds.contains(h.id),
        )
        .length;
    freshnessItem = ConclusionItem(
      name: '行情新鲜度',
      result: formatShare(freshness),
      status: fresh ? ConclusionStatus.normal : ConclusionStatus.attention,
      explanation: fresh
          ? '自动行情持仓的行情均已更新。'
          : '有 $staleCount 项自动行情持仓的行情未更新,显示的是最近一次估值。',
      action: fresh ? null : AppDestination.importReview,
      actionLabel: fresh ? null : '查看数据状态',
    );
  }

  return [structure, concentration, qualityItem, coverage, freshnessItem];
}

Holding? _largestHolding(List<Holding> holdings) {
  if (holdings.isEmpty) return null;
  var best = holdings.first;
  for (final holding in holdings.skip(1)) {
    if (holding.currentValue.compareTo(best.currentValue) > 0) {
      best = holding;
    }
  }
  return best;
}
