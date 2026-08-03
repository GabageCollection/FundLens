import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/portfolio_providers.dart';
import '../../application/schedule_policy.dart';
import '../../widgets/app_toast.dart';
import '../data_health/data_health_providers.dart';
import '../holdings/holding_actions.dart';
import 'persisted_settings.dart';
import 'widgets/settings_section_card.dart';

/// 数据与行情:自动刷新开关、刷新频率、上次/下次刷新时间、手动刷新与失败原因。
class MarketSettingsSection extends ConsumerWidget {
  const MarketSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(dailyAutoRefreshEnabledProvider);
    final frequency = ref.watch(refreshFrequencyProvider);
    final lastAttempt = ref.watch(lastQuoteRefreshAttemptProvider);
    final lastAttemptUtc = ref.watch(lastRefreshAttemptAtUtcProvider);
    final nextRun = ref.watch(nextQuoteRefreshProvider);
    final uiState = ref.watch(quoteRefreshUiStateProvider);
    final service = ref.watch(quoteRefreshServiceProvider);

    return SettingsSectionCard(
      key: const ValueKey('market-section'),
      title: '数据与行情',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动刷新行情'),
              subtitle: Text(
                frequency == ScheduleFrequency.manual
                    ? '当前为仅手动模式，不会自动刷新'
                    : '按所选频率自动刷新行情估值',
              ),
              value: enabled,
              onChanged: (value) {
                ref.read(dailyAutoRefreshEnabledProvider.notifier).state =
                    value;
                unawaited(
                  persistSetting(
                    ref.container,
                    SettingKeys.autoRefreshEnabled,
                    value ? '1' : '0',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text('刷新频率', style: theme.textTheme.bodySmall),
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
                ref.read(refreshFrequencyProvider.notifier).state = value;
                unawaited(
                  persistSetting(
                    ref.container,
                    SettingKeys.refreshFrequency,
                    value.name,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _lastRefreshText(lastAttemptUtc, lastAttempt),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            frequency == ScheduleFrequency.manual || !enabled
                ? '下次刷新：—'
                : '下次刷新：${nextRun == null ? '—' : _formatDateTime(nextRun)}',
            style: theme.textTheme.bodySmall,
          ),
          if (uiState is QuoteRefreshFailed) ...[
            const SizedBox(height: 4),
            Text(
              '刷新失败：${uiState.reason}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          if (service == null) ...[
            const SizedBox(height: 8),
            Text(
              '行情引擎不可用，当前显示的是最近一次估值。请稍后重试刷新。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed:
                service == null ? null : () => _refreshNow(context, ref),
            child: const Text('手动刷新行情'),
          ),
        ],
      ),
    );
  }

  String _lastRefreshText(
    DateTime? lastAttemptUtc,
    QuoteRefreshAttempt? sessionAttempt,
  ) {
    if (lastAttemptUtc == null) return '上次刷新：尚未刷新';
    final base = '上次刷新：${_formatDateTime(lastAttemptUtc.toLocal())}';
    final attempt = sessionAttempt;
    if (attempt == null) return base;
    return '$base · 更新 ${attempt.updated} 条 · 失败 ${attempt.failed} 条';
  }

  Future<void> _refreshNow(BuildContext context, WidgetRef ref) async {
    final holdings = ref.read(holdingsProvider).value ?? [];
    // 委托统一入口:同时维护全局刷新状态、新鲜集合与最近刷新记录。
    final report = await HoldingActions.refreshQuotes(ref.container, holdings);
    if (report == null && context.mounted) {
      showAppToast(context, '行情引擎不可用，当前显示的是最近一次估值。请稍后重试刷新。', isError: true);
    }
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
