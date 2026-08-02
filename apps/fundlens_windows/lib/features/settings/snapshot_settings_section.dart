import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/schedule_policy.dart';
import 'persisted_settings.dart';
import 'structure_thresholds_section.dart';

/// 快照设置:自动创建开关、创建频率、保存数量与自动清理说明。
class SnapshotSettingsSection extends ConsumerStatefulWidget {
  const SnapshotSettingsSection({super.key});

  @override
  ConsumerState<SnapshotSettingsSection> createState() =>
      _SnapshotSettingsSectionState();
}

class _SnapshotSettingsSectionState
    extends ConsumerState<SnapshotSettingsSection> {
  late final TextEditingController _keepCountController;

  @override
  void initState() {
    super.initState();
    _keepCountController = TextEditingController();
  }

  @override
  void dispose() {
    _keepCountController.dispose();
    super.dispose();
  }

  void _onKeepCountChanged(String raw) {
    final value = int.tryParse(raw);
    if (value == null) return;
    final clamped = value.clamp(1, 100);
    ref.read(snapshotKeepCountProvider.notifier).state = clamped;
    unawaited(
      persistSetting(
        ref.container,
        SettingKeys.snapshotKeepCount,
        '$clamped',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = ref.watch(snapshotAutoCreateEnabledProvider);
    final frequency = ref.watch(snapshotCreateFrequencyProvider);
    final keepCount = ref.watch(snapshotKeepCountProvider);
    final lastAuto = ref.watch(snapshotLastAutoCreateAtUtcProvider);

    // 与 provider 同步(如启动加载/恢复后重载);守卫避免覆盖用户输入。
    final expectedText = '$keepCount';
    if (_keepCountController.text != expectedText) {
      _keepCountController.text = expectedText;
    }

    return SettingsSectionCard(
      title: '快照设置',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动创建快照'),
              subtitle: const Text('按所选频率保存当前持仓为历史快照'),
              value: enabled,
              onChanged: (value) {
                ref.read(snapshotAutoCreateEnabledProvider.notifier).state =
                    value;
                unawaited(
                  persistSetting(
                    ref.container,
                    SettingKeys.snapshotAutoCreateEnabled,
                    value ? '1' : '0',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('创建频率', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ScheduleFrequency>(
              segments: const [
                ButtonSegment(
                  value: ScheduleFrequency.daily,
                  label: Text('每天'),
                ),
                ButtonSegment(
                  value: ScheduleFrequency.weekly,
                  label: Text('每周'),
                ),
                ButtonSegment(
                  value: ScheduleFrequency.manual,
                  label: Text('仅手动'),
                ),
              ],
              selected: {frequency},
              onSelectionChanged: (selection) {
                final value = selection.first;
                ref.read(snapshotCreateFrequencyProvider.notifier).state =
                    value;
                unawaited(
                  persistSetting(
                    ref.container,
                    SettingKeys.snapshotCreateFrequency,
                    value.name,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('保存数量', style: theme.textTheme.bodyMedium),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: TextFormField(
                  key: const ValueKey('snapshot-keep-count'),
                  controller: _keepCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(suffixText: '份'),
                  onChanged: _onKeepCountChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '仅自动快照参与数量清理，手动创建的快照始终保留',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            lastAuto == null
                ? '上次自动创建：尚未创建'
                : '上次自动创建：${_formatDateTime(lastAuto.toLocal())}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
