import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/page_scaffold.dart';
import 'snapshot_compare_view.dart';
import 'snapshot_deletion.dart';

/// Snapshot history page: create, delete and compare snapshots.
///
/// Snapshot rows are never editable; the only row action is deletion behind
/// a confirmation that names the date and label.
class SnapshotsPage extends ConsumerWidget {
  const SnapshotsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshots = ref.watch(snapshotsProvider);

    return PageScaffold(
      tier: PageWidthTier.dense,
      crumb: '组合',
      title: '历史快照',
      actions: [
        FilledButton(
          onPressed: () => _createSnapshot(context, ref),
          child: const Text('新建快照'),
        ),
      ],
      body: snapshots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('快照加载失败：$error')),
        data: (list) {
          final sorted = List<PortfolioSnapshot>.of(list)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              if (sorted.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: FundLensTokens.space4,
                  ),
                  child: Text('还没有快照'),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final snapshot in sorted)
                        ListTile(
                          title: Text(snapshot.label),
                          subtitle: Text(_formatDate(snapshot.createdAt)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除快照',
                            onPressed: () =>
                                _confirmDelete(context, ref, snapshot),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: FundLensTokens.cardGap),
              SnapshotCompareView(snapshots: sorted),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createSnapshot(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建快照'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '快照标签'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    final trimmed = label?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    await ref
        .read(snapshotRepositoryProvider)
        .createFromCurrent(label: trimmed);
    ref.invalidate(snapshotsProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PortfolioSnapshot snapshot,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除快照'),
        content: Text(
          '将删除快照「${snapshot.label}」（${_formatDate(snapshot.createdAt)}），'
          '此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(snapshotDeletionProvider)(snapshot.id);
    ref.invalidate(snapshotsProvider);
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
