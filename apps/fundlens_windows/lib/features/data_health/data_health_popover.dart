import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../app/app_shell.dart';
import '../../theme/fundlens_tokens.dart';
import '../holdings/holding_actions.dart';
import '../import_review/import_review_controller.dart';
import '../holdings/holding_filters.dart';
import '../holdings/holding_status.dart';
import 'data_health_models.dart';
import 'data_health_providers.dart';

/// 数据健康面板:状态头部 + 指标列表 + 最近活动 + 刷新失败区 + 操作区。
///
/// 所有覆盖率均带 "n/m" 计算方式;不适用项(total 为 0)显示"不适用"而非 100%。
/// 操作跳转统一通过 [onNavigate] 交给按钮侧执行(锚点 context 才能命中
/// AppShell 的意图处理器),预选筛选写入 [pendingHoldingFilterProvider] 由
/// 持仓页消费。
class DataHealthPopover extends ConsumerWidget {
  const DataHealthPopover({super.key, required this.onNavigate});

  /// 面板操作需要切换页面时调用;由 [DataHealthButton] 提供,负责切页并收起浮层。
  final void Function(AppDestination destination) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dataHealthMetricsProvider);
    final status = ref.watch(dataHealthStatusProvider);
    final uiState = ref.watch(quoteRefreshUiStateProvider);

    final failedReason = switch (uiState) {
      QuoteRefreshFailed(:final reason) => reason,
      _ => null,
    };

    return Material(
      color: FundLensTokens.surface,
      borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560, minWidth: 360),
        child: SingleChildScrollView(
          // MenuAnchor 内部已有自己的滚动容器,这里必须脱离 PrimaryScrollController,
          // 否则两个 ScrollPosition 争用主控制器抛异常。
          primary: false,
          padding: const EdgeInsets.all(FundLensTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusHeader(status: status, asOfDate: metrics.asOfDate),
              const SizedBox(height: FundLensTokens.space4),
              _MetricList(metrics: metrics),
              const SizedBox(height: FundLensTokens.space4),
              const _RecentActivity(),
              if (failedReason != null) ...[
                const SizedBox(height: FundLensTokens.space4),
                _RefreshFailed(reason: failedReason),
              ],
              const SizedBox(height: FundLensTokens.space4),
              _Actions(
                isFailed: failedReason != null,
                onNavigate: onNavigate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 面板顶部:状态图标 + 状态文字 + 数据截至时间。
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.status, required this.asOfDate});

  final DataHealthStatus status;
  final DateTime? asOfDate;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      DataHealthStatus.normal => (
        '正常',
        Icons.check_circle_outline,
        FundLensTokens.accent,
      ),
      DataHealthStatus.partialMissing => (
        '部分缺失',
        Icons.error_outline,
        FundLensTokens.warn,
      ),
      DataHealthStatus.needsUpdate => (
        '需要更新',
        Icons.update,
        FundLensTokens.warn,
      ),
      DataHealthStatus.refreshing => (
        '正在刷新',
        Icons.sync,
        FundLensTokens.accent,
      ),
      DataHealthStatus.refreshFailed => (
        '刷新失败',
        Icons.error_outline,
        FundLensTokens.profit,
      ),
    };
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: FundLensTokens.space2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Noto Sans SC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: FundLensTokens.ink,
          ),
        ),
        const Spacer(),
        Text(
          asOfDate == null ? '暂无数据' : '数据截至 ${formatDate(asOfDate!)}',
          style: const TextStyle(
            fontFamily: 'Noto Sans SC',
            fontSize: 12,
            color: FundLensTokens.muted,
          ),
        ),
      ],
    );
  }
}

/// 指标列表:每项标签 + 数值(n/m 或计数)+ 计算方式说明。
class _MetricList extends StatelessWidget {
  const _MetricList({required this.metrics});

  final DataHealthMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MetricRow(
          label: '持仓识别率',
          right: _CoverageValue(
            metric: metrics.recognitionRate,
            suffix: '已识别',
          ),
        ),
        _MetricRow(
          label: '资产分类率',
          right: _CoverageValue(
            metric: metrics.classificationRate,
            suffix: '已分类',
          ),
        ),
        _MetricRow(
          label: '成本覆盖率',
          right: _CoverageValue(
            metric: metrics.costCoverageRate,
            suffix: '有成本',
          ),
        ),
        _MetricRow(
          label: '行情覆盖率',
          right: _CoverageValue(
            metric: metrics.quoteCoverageRate,
            suffix: '行情有效',
          ),
        ),
        _MetricRow(
          label: '收益覆盖率',
          right: _PercentValue(value: metrics.returnCoverageRate),
        ),
        _MetricRow(
          label: '过期行情',
          right: _CountValue(count: metrics.staleQuoteCount),
        ),
        _MetricRow(
          label: '待处理异常',
          right: _CountValue(count: metrics.pendingIssueCount),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.right});

  final String label;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FundLensTokens.space1),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 14,
              color: FundLensTokens.ink,
            ),
          ),
          const Spacer(),
          right,
        ],
      ),
    );
  }
}

/// 覆盖率数值:独立 "n/m" 分数 + 说明文字;不适用显示"不适用"。
class _CoverageValue extends StatelessWidget {
  const _CoverageValue({required this.metric, required this.suffix});

  final CoverageMetric metric;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final ratio = metric.ratio;
    if (ratio == null) {
      return const Text(
        '不适用',
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          fontSize: 14,
          color: FundLensTokens.muted,
        ),
      );
    }
    final percent = (ratio * 100).toStringAsFixed(0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${metric.count}/${metric.total}',
          style: const TextStyle(
            fontFamily: 'IBM Plex Mono',
            fontSize: 14,
            color: FundLensTokens.inkSoft,
          ),
        ),
        const SizedBox(width: FundLensTokens.space2),
        Text(
          '$suffix · $percent%',
          style: const TextStyle(
            fontFamily: 'Noto Sans SC',
            fontSize: 12,
            color: FundLensTokens.muted,
          ),
        ),
      ],
    );
  }
}

/// 百分比数值(收益覆盖率)。
class _PercentValue extends StatelessWidget {
  const _PercentValue({required this.value});

  final DecimalValue value;

  @override
  Widget build(BuildContext context) {
    final percent = (double.parse(value.canonical) * 100).toStringAsFixed(0);
    return Text(
      '$percent%',
      style: const TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontSize: 14,
        color: FundLensTokens.inkSoft,
      ),
    );
  }
}

/// 计数数值(过期行情 / 待处理异常)。
class _CountValue extends StatelessWidget {
  const _CountValue({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count 条',
      style: const TextStyle(
        fontFamily: 'IBM Plex Mono',
        fontSize: 14,
        color: FundLensTokens.inkSoft,
      ),
    );
  }
}

/// 最近导入与最近行情刷新(含计数摘要)。
class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final import = ref.watch(lastImportRecordProvider);
    final refresh = ref.watch(lastQuoteRefreshAttemptProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ActivityRow(label: '最近导入', value: _importSummary(import)),
        _ActivityRow(label: '最近行情刷新', value: _refreshSummary(refresh)),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FundLensTokens.space1),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 14,
              color: FundLensTokens.ink,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 12,
              color: FundLensTokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 最近导入摘要:时间 + 新增/更新/移除/跳过(非零项)。
String _importSummary(LastImportRecord? record) {
  if (record == null) return '本会话未导入';
  final parts = <String>['新增 ${record.inserted}'];
  if (record.updated > 0) parts.add('更新 ${record.updated}');
  if (record.removed > 0) parts.add('移除 ${record.removed}');
  if (record.skipped > 0) parts.add('跳过 ${record.skipped}');
  return '${formatDateTime(record.committedAt)} · ${parts.join(' · ')}';
}

/// 最近行情刷新摘要:时间 + 更新/失败(非零项)。
String _refreshSummary(QuoteRefreshAttempt? attempt) {
  if (attempt == null) return '本会话未刷新';
  final parts = <String>['更新 ${attempt.updated}'];
  if (attempt.failed > 0) parts.add('失败 ${attempt.failed}');
  return '${formatDateTime(attempt.at)} · ${parts.join(' · ')}';
}

/// 刷新失败区:原因 + 重试入口。
class _RefreshFailed extends ConsumerWidget {
  const _RefreshFailed({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(FundLensTokens.space3),
      decoration: BoxDecoration(
        color: FundLensTokens.warnSoft,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
        border: Border.all(color: FundLensTokens.warn),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '刷新失败原因：$reason',
            style: theme.textTheme.bodySmall?.copyWith(
              color: FundLensTokens.warnText,
            ),
          ),
          const SizedBox(height: FundLensTokens.space2),
          TextButton(
            key: const ValueKey('data-health-retry'),
            onPressed: () => _retryRefresh(context, ref),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  static Future<void> _retryRefresh(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final holdings = ref.read(holdingsProvider).value ?? [];
    await HoldingActions.refreshQuotes(ref.container, holdings);
  }
}

/// 操作区:刷新行情 / 查看缺失数据 / 补充资产分类 / 查看导入记录。
class _Actions extends ConsumerWidget {
  const _Actions({required this.isFailed, required this.onNavigate});

  final bool isFailed;
  final void Function(AppDestination destination) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('data-health-refresh'),
          onPressed: isFailed ? null : () => _refreshNow(ref),
          icon: const Icon(Icons.sync, size: 18),
          label: const Text('刷新行情'),
        ),
        const SizedBox(height: FundLensTokens.space2),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('data-health-missing'),
                onPressed: () =>
                    _navigateHoldingsWithMissing(ref, onNavigate),
                child: const Text('查看缺失数据'),
              ),
            ),
            const SizedBox(width: FundLensTokens.space2),
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('data-health-classify'),
                onPressed: () =>
                    _navigateHoldingsToClassify(ref, onNavigate),
                child: const Text('补充资产分类'),
              ),
            ),
          ],
        ),
        const SizedBox(height: FundLensTokens.space2),
        OutlinedButton.icon(
          key: const ValueKey('data-health-imports'),
          onPressed: () => onNavigate(AppDestination.importReview),
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('查看导入记录'),
        ),
      ],
    );
  }

  static Future<void> _refreshNow(WidgetRef ref) async {
    final holdings = ref.read(holdingsProvider).value ?? [];
    await HoldingActions.refreshQuotes(ref.container, holdings);
  }

  static void _navigateHoldingsWithMissing(
    WidgetRef ref,
    void Function(AppDestination) onNavigate,
  ) {
    ref.read(pendingHoldingFilterProvider.notifier).state = HoldingFilterState(
      statuses: {
        HoldingDataStatus.incomplete,
        HoldingDataStatus.noQuote,
        HoldingDataStatus.staleQuote,
        HoldingDataStatus.missingCost,
      },
    );
    onNavigate(AppDestination.holdings);
  }

  static void _navigateHoldingsToClassify(
    WidgetRef ref,
    void Function(AppDestination) onNavigate,
  ) {
    ref.read(pendingHoldingFilterProvider.notifier).state =
        HoldingFilterState(assetClasses: {AssetClass.other});
    onNavigate(AppDestination.holdings);
  }
}

String formatDate(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String formatDateTime(DateTime value) {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  return '${formatDate(value)} $hh:$mm';
}
