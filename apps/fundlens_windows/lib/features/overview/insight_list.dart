import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../app/app_shell.dart';
import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../importing/import_models.dart' show IssueSeverity;
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../analysis/analysis_labels.dart' show formatAmount;
import 'asset_spectrum.dart' show formatPercent;

/// 总览页提醒的跳转目标。
enum OverviewInsightAction {
  /// 全部持仓页。
  holdings,

  /// 导入与识别页(数据状态)。
  importReview,
}

/// 一条有层级的风险/数据提醒:发现了什么、为什么需要关注、可执行操作。
///
/// 只陈述可测量的事实与影响,不包含任何投资行为措辞。
final class OverviewInsight {
  const OverviewInsight({
    required this.code,
    required this.severity,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.action,
  });

  final String code;
  final IssueSeverity severity;

  /// 发现了什么(含具体数字)。
  final String title;

  /// 为什么需要关注。
  final String detail;

  /// 可执行操作的按钮文案。
  final String actionLabel;
  final OverviewInsightAction action;
}

/// 单项持仓集中度提醒阈值(占总资产 25%)。
const singleHoldingWarnShare = '0.25';

/// 前 3 项持仓集中度提醒阈值(占总资产 60%)。
const top3HoldingWarnShare = '0.60';

/// 基于当前持仓与组合汇总构建风险/数据提醒列表。
///
/// 每条提醒都包含发现、影响与可执行操作;全部正常时返回空列表。
List<OverviewInsight> buildOverviewInsights({
  required List<Holding> holdings,
  required PortfolioSummary summary,
  required Set<String> freshQuoteHoldingIds,
}) {
  final insights = <OverviewInsight>[];
  if (holdings.isEmpty || summary.totalValue.isZero) return insights;

  // 1. 单项持仓集中度。
  final singleThreshold = DecimalValue.parse(singleHoldingWarnShare);
  final largest = holdings.reduce(
    (a, b) => a.currentValue.compareTo(b.currentValue) >= 0 ? a : b,
  );
  final largestShare = summary.holdingShares[largest.id] ?? DecimalValue.zero;
  if (largestShare.compareTo(singleThreshold) >= 0) {
    insights.add(
      OverviewInsight(
        code: 'single_concentration',
        severity: IssueSeverity.warning,
        title:
            '${largest.productName}占总资产 ${formatPercent(largestShare)},集中度较高。',
        detail: '单一产品的价格波动会明显影响总资产的变化幅度。',
        actionLabel: '查看持仓',
        action: OverviewInsightAction.holdings,
      ),
    );
  }

  // 2. 前 3 项持仓集中度。
  if (holdings.length >= 3) {
    final sorted = [...holdings]
      ..sort((a, b) => b.currentValue.compareTo(a.currentValue));
    final top3Value = sorted
        .take(3)
        .fold(DecimalValue.zero, (sum, h) => sum + h.currentValue);
    final top3Share = top3Value.divide(summary.totalValue);
    if (top3Share.compareTo(DecimalValue.parse(top3HoldingWarnShare)) >= 0) {
      insights.add(
        OverviewInsight(
          code: 'top3_concentration',
          severity: IssueSeverity.warning,
          title: '前 3 项持仓合计占总资产 ${formatPercent(top3Share)},集中度较高。',
          detail: '资产变化主要由少数几项持仓决定,其余持仓的分散作用有限。',
          actionLabel: '查看持仓',
          action: OverviewInsightAction.holdings,
        ),
      );
    }
  }

  // 3. 未分类资产数量。
  final uncategorized =
      holdings.where((h) => h.assetClass == AssetClass.other).length;
  if (uncategorized > 0) {
    insights.add(
      OverviewInsight(
        code: 'uncategorized_assets',
        severity: IssueSeverity.info,
        title: '有 $uncategorized 项持仓未归入明确的资产类别。',
        detail: '未分类资产会让资产结构占比失真,无法准确回答“资产集中在哪里”。',
        actionLabel: '查看持仓',
        action: OverviewInsightAction.holdings,
      ),
    );
  }

  // 4. 缺少成本的持仓数量。
  final missingCost =
      holdings.where((h) => h.effectiveCostAmount == null).length;
  if (missingCost > 0) {
    insights.add(
      OverviewInsight(
        code: 'missing_cost',
        severity: IssueSeverity.info,
        title: '有 $missingCost 项持仓缺少成本数据。',
        detail: '缺少成本的持仓不计入浮动盈亏与总收益率,收益统计会低估整体表现。',
        actionLabel: '查看持仓',
        action: OverviewInsightAction.holdings,
      ),
    );
  }

  // 5. 行情过期数量。
  final stale = holdings.where(
    (h) =>
        h.valuationMethod == ValuationMethod.automaticQuote &&
        !freshQuoteHoldingIds.contains(h.id),
  );
  if (stale.isNotEmpty) {
    insights.add(
      OverviewInsight(
        code: 'stale_quotes',
        severity: IssueSeverity.info,
        title: '有 ${stale.length} 项自动行情持仓的行情未更新。',
        detail: '这些持仓显示的是最近一次估值,当前金额可能与实际存在偏差。',
        actionLabel: '查看数据状态',
        action: OverviewInsightAction.importReview,
      ),
    );
  }

  // 6. 收益未覆盖金额。
  final coveredValue = holdings
      .where((h) => h.effectiveCostAmount != null)
      .fold(DecimalValue.zero, (sum, h) => sum + h.currentValue);
  final uncoveredValue = summary.totalValue - coveredValue;
  if (!uncoveredValue.isZero && !uncoveredValue.isNegative) {
    insights.add(
      OverviewInsight(
        code: 'uncovered_return',
        severity: IssueSeverity.info,
        title: '¥${formatAmount(uncoveredValue)} 的资产未纳入收益统计。',
        detail: '这部分资产缺少成本,总收益率只反映有成本资产的表现。',
        actionLabel: '查看持仓',
        action: OverviewInsightAction.holdings,
      ),
    );
  }

  return List.unmodifiable(insights);
}

/// 当前组合的风险/数据提醒列表(派生自持仓流)。
final overviewInsightsProvider = Provider<List<OverviewInsight>>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? const <Holding>[];
  return buildOverviewInsights(
    holdings: holdings,
    summary: ref.watch(portfolioSummaryProvider),
    freshQuoteHoldingIds: ref.watch(freshQuoteHoldingIdsProvider),
  );
});

/// 总览页右侧的“风险与数据提醒”卡。
///
/// 每条提醒分层呈现:发现了什么(标题)、为什么需要关注(说明)、
/// 可执行操作(按钮)。没有问题时显示明确的正常状态。
class OverviewInsightList extends ConsumerWidget {
  const OverviewInsightList({super.key});

  void _runAction(BuildContext context, OverviewInsight insight) {
    final destination = switch (insight.action) {
      OverviewInsightAction.holdings => AppDestination.holdings,
      OverviewInsightAction.importReview => AppDestination.importReview,
    };
    // 总览页位于 AppShell 内时跳转到目标页;独立嵌套(测试)时安全空操作。
    Actions.maybeInvoke(context, SelectDestinationIntent(destination));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insights = ref.watch(overviewInsightsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '风险与数据提醒',
              style: theme.extension<FundLensTextStyles>()!.sectionTitle,
            ),
            const SizedBox(height: FundLensTokens.space3),
            if (insights.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: FundLensTokens.space4,
                ),
                child: Text(
                  '未发现需要处理的数据或风险问题',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              for (final insight in insights)
                _InsightRow(
                  insight: insight,
                  onAction: () => _runAction(context, insight),
                ),
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight, required this.onAction});

  final OverviewInsight insight;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWarning = insight.severity == IssueSeverity.warning;
    final iconColor = isWarning ? FundLensTokens.warn : FundLensTokens.muted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: FundLensTokens.space3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FundLensTokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isWarning ? Icons.error_outline : Icons.info_outline,
              size: 16,
              color: iconColor,
            ),
          ),
          const SizedBox(width: FundLensTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: FundLensTokens.space1),
                Text(insight.detail, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: FundLensTokens.space2),
          TextButton(onPressed: onAction, child: Text(insight.actionLabel)),
        ],
      ),
    );
  }
}
