import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_retry_view.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_scaffold.dart';
import 'snapshot_compare_view.dart';
import 'snapshot_deletion.dart';

/// Snapshot history page: create, delete and compare snapshots.
///
/// Snapshot rows are never editable; the only row action is deletion behind
/// a confirmation that names the date and label.
///
/// 创建/删除为异步写操作:进行中禁用入口按钮,成功给 Toast,失败按
/// "发生了什么+哪些数据受影响+如何下一步"提示并保持数据不变。
class SnapshotsPage extends ConsumerStatefulWidget {
  const SnapshotsPage({super.key});

  @override
  ConsumerState<SnapshotsPage> createState() => _SnapshotsPageState();
}

class _SnapshotsPageState extends ConsumerState<SnapshotsPage> {
  /// 快照创建/删除进行中标记,用于禁用入口防止重复触发。
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final snapshots = ref.watch(snapshotsProvider);

    return PageScaffold(
      tier: PageWidthTier.dense,
      crumb: '组合',
      title: '历史快照',
      actions: [
        FilledButton(
          onPressed: _busy ? null : _createSnapshot,
          child: const Text('新建快照'),
        ),
      ],
      body: snapshots.when(
        loading: () => const LoadingView(label: '正在加载快照…'),
        error: (error, _) => ErrorRetryView(
          title: '快照加载失败',
          message: '历史快照未能加载，现有快照未受影响，请重试。',
          onRetry: () => ref.invalidate(snapshotsProvider),
        ),
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
                            onPressed: _busy
                                ? null
                                : () => _confirmDelete(snapshot),
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

  Future<void> _createSnapshot() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        // 空标签在字段下方就近提示,不允许静默提交空标签。
        String? error;
        String? submit() {
          final trimmed = controller.text.trim();
          if (trimmed.isEmpty) return '标签不能为空';
          return null;
        }

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('新建快照'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '快照标签',
                errorText: error,
              ),
              onChanged: (_) {
                if (error != null) setDialogState(() => error = null);
              },
              onSubmitted: (value) {
                final message = submit();
                if (message != null) {
                  setDialogState(() => error = message);
                  return;
                }
                Navigator.of(dialogContext).pop(value.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final message = submit();
                  if (message != null) {
                    setDialogState(() => error = message);
                    return;
                  }
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );
    final trimmed = label;
    if (trimmed == null || trimmed.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(snapshotRepositoryProvider)
          .createFromCurrent(label: trimmed);
      ref.invalidate(snapshotsProvider);
      if (!mounted) return;
      showAppToast(context, '已创建快照「$trimmed」');
    } catch (e) {
      // 快照写入失败(磁盘满/数据库损坏等):提示重试,数据保持原状。
      if (!mounted) return;
      showAppToast(
        context,
        '快照创建失败，现有持仓与快照未受影响，请重试。',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete(PortfolioSnapshot snapshot) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除快照',
      content: Text(
        '将删除快照「${snapshot.label}」（${_formatDate(snapshot.createdAt)}），'
        '该历史记录删除后无法恢复，对比视图将少一个可选快照。',
      ),
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await ref.read(snapshotDeletionProvider)(snapshot.id);
      ref.invalidate(snapshotsProvider);
      if (!mounted) return;
      showAppToast(context, '已删除快照「${snapshot.label}」');
    } catch (e) {
      // 删除失败(数据库错误等):提示重试,历史记录保持原状。
      if (!mounted) return;
      showAppToast(
        context,
        '快照删除失败，历史记录未删除，请重试。',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
