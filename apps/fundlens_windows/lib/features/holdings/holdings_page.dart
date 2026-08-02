import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../widgets/page_scaffold.dart';
import 'holding_detail_drawer.dart';
import 'holding_editor_dialog.dart';
import 'holding_filters.dart';
import 'holding_grid.dart';
import 'holding_status.dart';
import 'holding_toolbar.dart';

/// 全部持仓 page: filters, the virtualized grid and manual CRUD actions.
class HoldingsPage extends ConsumerWidget {
  const HoldingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(visibleHoldingsProvider);
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
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(assetClasses: toggled(filter.assetClasses, v)),
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
      body: HoldingGrid(
        holdings: holdings,
        totalValue: ref.watch(portfolioSummaryProvider).totalValue,
        freshQuoteHoldingIds: ref.watch(freshQuoteHoldingIdsProvider),
        sort: filter.sort,
        onSortChanged: (sort) =>
            ref.read(holdingFilterProvider.notifier).state =
                filter.copyWith(sort: sort),
        selectedIds: ref.watch(holdingSelectionProvider),
        onSelectedChanged: (id, selected) {
          final current = ref.read(holdingSelectionProvider);
          ref.read(holdingSelectionProvider.notifier).state = {...current}
            ..remove(id)
            ..addAll(selected ? [id] : const <String>[]);
        },
        onSelectAllChanged: (all) {
          ref.read(holdingSelectionProvider.notifier).state =
              all ? {for (final h in holdings) h.id} : const <String>{};
        },
        onRowTap: (holding) => showHoldingDetailDrawer(context, holding.id),
      ),
    );
  }

  Future<void> _addHolding(BuildContext context, WidgetRef ref) async {
    final holding = await showHoldingEditorDialog(context);
    if (holding == null) return;
    await ref.read(holdingRepositoryProvider).upsert(holding);
  }
}
