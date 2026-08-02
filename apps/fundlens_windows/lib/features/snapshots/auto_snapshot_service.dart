import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_dependencies.dart';
import '../../application/schedule_policy.dart';
import '../settings/persisted_settings.dart';

/// Creates automatic portfolio snapshots on a schedule and prunes old auto
/// snapshots to the configured keep count.
///
/// Only snapshots whose label starts with [autoLabelPrefix] participate in
/// pruning; user-named snapshots are never deleted.
final class AutoSnapshotService {
  AutoSnapshotService({
    required this.container,
    required this.policy,
    required this.clock,
  });

  static const autoLabelPrefix = '自动快照 ';

  final ProviderContainer container;
  final SchedulePolicy policy;
  final DateTime Function() clock;

  static bool isAutoSnapshotLabel(String label) =>
      label.startsWith(autoLabelPrefix);

  /// Creates one auto snapshot when due, then prunes to the keep count.
  Future<void> runIfDue() async {
    if (!container.read(snapshotAutoCreateEnabledProvider)) return;
    final frequency = container.read(snapshotCreateFrequencyProvider);
    if (frequency == ScheduleFrequency.manual) return;
    final last = container.read(snapshotLastAutoCreateAtUtcProvider);
    if (!policy.shouldRun(frequency, last)) return;

    final now = clock().toUtc();
    await container
        .read(snapshotRepositoryProvider)
        .createFromCurrent(label: '$autoLabelPrefix${_formatDate(now)}');

    container.read(snapshotLastAutoCreateAtUtcProvider.notifier).state = now;
    await persistSetting(
      container,
      SettingKeys.snapshotLastAutoCreateAtUtc,
      now.toIso8601String(),
    );

    await prune();
  }

  /// Deletes the oldest auto snapshots that exceed the keep count. Returns the
  /// number of snapshots removed. Idempotent: a half-finished run finishes on
  /// the next launch.
  Future<int> prune() async {
    final repo = container.read(snapshotRepositoryProvider);
    final keepCount = container.read(snapshotKeepCountProvider).clamp(1, 100);
    final all = await repo.getAll();
    final auto = all
        .where((s) => isAutoSnapshotLabel(s.label))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final excess = auto.skip(keepCount).toList();
    for (final snapshot in excess) {
      await repo.deleteById(snapshot.id);
    }
    return excess.length;
  }

  static String _formatDate(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
