import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/confirm_dialog.dart';
import '../data_health/data_health_providers.dart';
import 'holding_actions.dart';
import 'holding_filters.dart';

/// 保存路径选择(测试可覆写);返回 null 表示用户取消。
final holdingSavePathProvider =
    Provider<Future<String?> Function(String suggestedName)>((ref) {
  return (name) => FilePicker.platform.saveFile(
        dialogTitle: '导出持仓',
        fileName: name,
      );
});

/// 批量操作条:选中 ≥1 项持仓时浮现。
class HoldingBatchBar extends ConsumerWidget {
  const HoldingBatchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 始终先订阅持仓流(即使无选择也保持数据预热),避免有选择的首帧
    // 因 StreamProvider 异步首值而延迟一整帧显示。
    final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
    final selection = ref.watch(holdingSelectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();

    final selected = [
      for (final h in holdings)
        if (selection.contains(h.id)) h,
    ];
    if (selected.isEmpty) return const SizedBox.shrink();

    final canRefresh = ref.watch(quoteRefreshServiceProvider) != null &&
        selected.any(holdingSupportsQuoteRefresh);
    // 已有一次刷新进行中:禁用入口,避免并发触发被误报为失败。
    final refreshing =
        ref.watch(quoteRefreshUiStateProvider) is QuoteRefreshInProgress;

    return Container(
      // 宽度充足时单行 48 高;窄窗口(高 DPI / 200% 缩放)折叠为多行自适应。
      constraints: const BoxConstraints(minHeight: 48),
      decoration: const BoxDecoration(
        color: FundLensTokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: FundLensTokens.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: FundLensTokens.space4,
        vertical: FundLensTokens.space1,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leading = <Widget>[
            Text(
              '已选 ${selected.length} 项',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: FundLensTokens.space4),
            TextButton(
              onPressed: () => _changeAssetClass(context, ref, selected),
              child: const Text('修改资产类别'),
            ),
            TextButton(
              onPressed: () => _changeSourcePlatform(context, ref, selected),
              child: const Text('修改来源平台'),
            ),
            TextButton(
              onPressed: canRefresh && !refreshing
                  ? () => _refreshQuotes(context, ref, selected)
                  : null,
              child: Text(refreshing ? '刷新中…' : '刷新行情'),
            ),
            TextButton(
              onPressed: () => _export(context, ref, selected),
              child: const Text('导出'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: FundLensTokens.profit,
              ),
              onPressed: () => _delete(context, ref, selected),
              child: const Text('删除'),
            ),
          ];
          // 窄窗口:折叠为多行,避免横向溢出;取消选择跟随其后。
          if (constraints.maxWidth < 720) {
            return Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: FundLensTokens.space2,
              runSpacing: 0,
              children: [
                ...leading,
                TextButton(
                  onPressed: () => ref
                      .read(holdingSelectionProvider.notifier)
                      .state = const {},
                  child: const Text('取消选择'),
                ),
              ],
            );
          }
          return Row(
            children: [
              ...leading,
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(holdingSelectionProvider.notifier).state =
                        const {},
                child: const Text('取消选择'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeAssetClass(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final target = await showDialog<AssetClass>(
      context: context,
      builder: (context) => const _EnumPickerDialog<AssetClass>(
        title: '修改资产类别',
        options: HoldingLabels.assetClass,
      ),
    );
    if (target == null || !context.mounted) return;
    try {
      await _applyBatch(
        ref,
        selected,
        (h) => h.copyWith(
          assetClass: target,
          fieldProvenance: {
            ...h.fieldProvenance,
            'assetClass': const FieldProvenance(
              kind: ProvenanceKind.userCorrected,
              source: '批量修改',
            ),
          },
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      // 数据库写入失败(磁盘满/损坏等):提示用户,避免异常静默上抛。
      if (context.mounted) {
        showHoldingToast(
          context,
          '修改失败：${selected.length} 项持仓未变更，请重试。',
          isError: true,
        );
      }
      return;
    }
    if (context.mounted) {
      showHoldingToast(context, '已更新 ${selected.length} 项持仓');
    }
  }

  Future<void> _changeSourcePlatform(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final target = await showDialog<SourcePlatform>(
      context: context,
      builder: (context) => const _EnumPickerDialog<SourcePlatform>(
        title: '修改来源平台',
        options: HoldingLabels.sourcePlatform,
      ),
    );
    if (target == null || !context.mounted) return;
    try {
      await _applyBatch(
        ref,
        selected,
        (h) => h.copyWith(
          sourcePlatform: target,
          fieldProvenance: {
            ...h.fieldProvenance,
            'sourcePlatform': const FieldProvenance(
              kind: ProvenanceKind.userCorrected,
              source: '批量修改',
            ),
          },
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      // 数据库写入失败(磁盘满/损坏等):提示用户,避免异常静默上抛。
      if (context.mounted) {
        showHoldingToast(
          context,
          '修改失败：${selected.length} 项持仓未变更，请重试。',
          isError: true,
        );
      }
      return;
    }
    if (context.mounted) {
      showHoldingToast(context, '已更新 ${selected.length} 项持仓');
    }
  }

  Future<void> _applyBatch(
    WidgetRef ref,
    List<Holding> selected,
    Holding Function(Holding h) transform,
  ) async {
    final repo = ref.read(holdingRepositoryProvider);
    await repo.inTransaction(() async {
      for (final holding in selected) {
        await repo.upsert(transform(holding));
      }
    });
  }

  Future<void> _refreshQuotes(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final report = await HoldingActions.refreshQuotes(ref.container, selected);
    if (!context.mounted) return;
    if (report == null) {
      // 刷新进行中(并发拦截)不是失败:提示稍候;其余情况才是失败。
      final refreshing = ref
          .read(quoteRefreshUiStateProvider) is QuoteRefreshInProgress;
      showHoldingToast(
        context,
        refreshing
            ? '正在刷新行情，请稍候…'
            : '行情刷新失败，保留最近一次估值。请稍后重试。',
        isError: !refreshing,
      );
      return;
    }
    showHoldingToast(
      context,
      '行情:更新 ${report.updated.length} · '
      '保留 ${report.retained.length} · '
      '失败 ${report.failed.length}',
    );
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final path = await ref.read(holdingSavePathProvider)('holdings-$y$m$d.csv');
    if (path == null || !context.mounted) return;
    try {
      await HoldingActions.export(selected, path);
    } catch (e) {
      // 写文件失败(路径无权限/磁盘满/文件被占用):提示用户,避免异常上抛。
      if (context.mounted) {
        showHoldingToast(context, '导出失败：未生成文件，请重试。', isError: true);
      }
      return;
    }
    if (context.mounted) {
      // 不引入 path 包:手动取文件名。
      final name = path.split(RegExp(r'[\\/]')).last;
      showHoldingToast(context, '已导出到 $name');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<Holding> selected,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除持仓',
      content: Text('确定删除选中的 ${selected.length} 项持仓吗?此操作不可撤销。'),
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(holdingRepositoryProvider)
          .deleteByIds([for (final h in selected) h.id]);
    } catch (e) {
      // 删除失败(数据库错误等):保留选择以便用户重试,不进入成功路径。
      if (context.mounted) {
        showHoldingToast(
          context,
          '删除失败：${selected.length} 项持仓未删除，请重试。',
          isError: true,
        );
      }
      return;
    }
    ref.read(holdingSelectionProvider.notifier).state = const {};
    if (!context.mounted) return;
    showHoldingToast(context, '已删除 ${selected.length} 项持仓');
  }
}

/// 单选目标值对话框(批量修改类别/平台共用)。
class _EnumPickerDialog<T> extends StatelessWidget {
  const _EnumPickerDialog({required this.title, required this.options});

  final String title;
  final Map<T, String> options;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in options.entries)
              InkWell(
                onTap: () => Navigator.of(context).pop(entry.key),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FundLensTokens.space2,
                  ),
                  child: Text(entry.value),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
