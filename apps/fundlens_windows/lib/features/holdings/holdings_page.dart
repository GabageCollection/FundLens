import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../app/app_shell.dart';
import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../application/portfolio_state.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/error_retry_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_scaffold.dart';
import 'holding_actions.dart';
import 'holding_batch_bar.dart';
import 'holding_detail_drawer.dart';
import 'holding_editor_dialog.dart';
import 'holding_filters.dart';
import 'holding_grid.dart';
import 'holding_status.dart';
import 'holding_toolbar.dart';

/// 全部持仓页:工具栏 + 批量条 + 计数 + 虚拟表格 + 空状态。
class HoldingsPage extends ConsumerWidget {
  const HoldingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 数据健康面板的"查看缺失数据/补充资产分类"预选筛选:本帧应用一次并清空。
    // IndexedStack 保持本页存活,watch 到非空即在帧末应用,同时覆盖
    // "先设置后挂载"与"先挂载后设置"两条时序。
    final pendingFilter = ref.watch(pendingHoldingFilterProvider);
    if (pendingFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(holdingFilterProvider.notifier).state = pendingFilter;
        ref.read(pendingHoldingFilterProvider.notifier).state = null;
      });
    }

    final state = ref.watch(portfolioStateProvider);
    final filter = ref.watch(holdingFilterProvider);

    return PageScaffold(
      tier: PageWidthTier.dense,
      crumb: '组合',
      title: '全部持仓',
      actions: [
        HoldingSearchField(
          query: filter.query,
          onChanged: (value) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(query: value),
        ),
        HoldingFilterDropdown<AssetClass>(
          label: '资产类别',
          shortLabel: '类别',
          options: [
            for (final entry in HoldingLabels.assetClass.entries)
              (entry.key, entry.value),
          ],
          selected: filter.assetClasses,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state = filter
                  .copyWith(assetClasses: toggled(filter.assetClasses, v)),
        ),
        HoldingFilterDropdown<SourcePlatform>(
          label: '来源平台',
          shortLabel: '平台',
          options: [
            for (final entry in HoldingLabels.sourcePlatform.entries)
              (entry.key, entry.value),
          ],
          selected: filter.sources,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(sources: toggled(filter.sources, v)),
        ),
        HoldingFilterDropdown<HoldingDataStatus>(
          label: '数据状态',
          shortLabel: '状态',
          options: [
            for (final entry in holdingDataStatusLabels.entries)
              (entry.key, entry.value),
          ],
          selected: filter.statuses,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(statuses: toggled(filter.statuses, v)),
        ),
        HoldingFilterDropdown<String?>(
          label: '组合标签',
          shortLabel: '标签',
          options: [
            (null, '未标记'),
            for (final tag in ref.watch(holdingTagOptionsProvider)) (tag, tag),
          ],
          selected: filter.tags,
          onToggled: (v) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(tags: toggled(filter.tags, v)),
        ),
        HoldingSortMenu(
          sort: filter.sort,
          onSelected: (sort) =>
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(sort: sort),
        ),
        FilledButton.icon(
          onPressed: () => _addHolding(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('添加持仓'),
        ),
      ],
      body: switch (state) {
        PortfolioLoading() =>
          const LoadingView(label: '正在加载持仓…'),
        PortfolioDegraded() => ErrorRetryView(
          title: '持仓数据暂时不可用',
          message: '持仓数据加载失败，本地数据未受影响，请重试。',
          onRetry: () => ref.invalidate(holdingsProvider),
        ),
        PortfolioEmpty() => const _EmptyHoldingsBody(),
        PortfolioReady() => const _ReadyBody(),
      },
    );
  }

  Future<void> _addHolding(BuildContext context, WidgetRef ref) async {
    final holding = await showHoldingEditorDialog(context);
    if (holding == null || !context.mounted) return;
    try {
      await ref.read(holdingRepositoryProvider).upsert(holding);
    } catch (e) {
      // 数据库写入失败(磁盘满/损坏等):提示用户重试,避免异常静默上抛。
      if (context.mounted) {
        showHoldingToast(context, '保存失败：持仓未添加，请重试。', isError: true);
      }
      return;
    }
    if (context.mounted) showHoldingToast(context, '已保存');
  }
}

/// 有持仓时的主体:批量条 + 计数 + 表格/无结果状态。
class _ReadyBody extends ConsumerWidget {
  const _ReadyBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleHoldingsProvider);
    final filter = ref.watch(holdingFilterProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HoldingBatchBar(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FundLensTokens.space4,
            vertical: FundLensTokens.space2,
          ),
          child: Text(
            '共 ${visible.length} 项持仓',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? (filter.hasActiveFilter
                  ? const _NoResultBody()
                  : const SizedBox.shrink())
              : HoldingGrid(
                  holdings: visible,
                  totalValue:
                      ref.watch(portfolioSummaryProvider).totalValue,
                  freshQuoteHoldingIds:
                      ref.watch(freshQuoteHoldingIdsProvider),
                  sort: filter.sort,
                  onSortChanged: (sort) =>
                      ref.read(holdingFilterProvider.notifier).state =
                          filter.copyWith(sort: sort),
                  selectedIds: ref.watch(holdingSelectionProvider),
                  onSelectedChanged: (id, selected) {
                    final next = {...ref.read(holdingSelectionProvider)};
                    if (selected) {
                      next.add(id);
                    } else {
                      next.remove(id);
                    }
                    ref.read(holdingSelectionProvider.notifier).state = next;
                  },
                  onSelectAllChanged: (all) {
                    ref.read(holdingSelectionProvider.notifier).state = all
                        ? {for (final h in visible) h.id}
                        : const <String>{};
                  },
                  onRowTap: (holding) =>
                      showHoldingDetailDrawer(context, holding.id),
                ),
        ),
      ],
    );
  }
}

/// 全库无持仓:导入与手动添加两个入口。
class _EmptyHoldingsBody extends ConsumerWidget {
  const _EmptyHoldingsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('还没有持仓', style: theme.textTheme.titleMedium),
          const SizedBox(height: FundLensTokens.space2),
          Text(
            '导入 Excel / CSV 或截图识别,或手动添加第一项。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: FundLensTokens.space4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                key: const ValueKey('empty-import'),
                onPressed: () => Actions.maybeInvoke(
                  context,
                  const SelectDestinationIntent(AppDestination.importReview),
                ),
                icon: const Icon(Icons.upload_file),
                label: const Text('导入资产'),
              ),
              const SizedBox(width: FundLensTokens.space3),
              OutlinedButton.icon(
                key: const ValueKey('empty-manual'),
                onPressed: () async {
                  final holding = await showHoldingEditorDialog(context);
                  if (holding == null || !context.mounted) return;
                  try {
                    await ref.read(holdingRepositoryProvider).upsert(holding);
                  } catch (e) {
                    // 数据库写入失败(磁盘满/损坏等):提示用户重试,避免异常静默上抛。
                    if (context.mounted) {
                      showHoldingToast(
                        context,
                        '保存失败：持仓未添加，请重试。',
                        isError: true,
                      );
                    }
                    return;
                  }
                  if (context.mounted) showHoldingToast(context, '已保存');
                },
                icon: const Icon(Icons.add),
                label: const Text('手动添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 筛选/搜索无结果。
class _NoResultBody extends ConsumerWidget {
  const _NoResultBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(holdingFilterProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('没有符合条件的持仓'),
          const SizedBox(height: FundLensTokens.space3),
          OutlinedButton(
            key: const ValueKey('clear-filters'),
            onPressed: () =>
                ref.read(holdingFilterProvider.notifier).state =
                    filter.cleared(),
            child: const Text('清除筛选'),
          ),
        ],
      ),
    );
  }
}
