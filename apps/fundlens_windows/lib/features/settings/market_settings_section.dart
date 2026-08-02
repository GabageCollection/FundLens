import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../application/portfolio_providers.dart';
import '../holdings/holding_actions.dart';
import 'structure_thresholds_section.dart';

/// Whether the daily automatic quote refresh is enabled.
final dailyAutoRefreshEnabledProvider = StateProvider<bool>((ref) => true);

/// Factual record of the most recent quote refresh attempt.
final class QuoteRefreshAttempt {
  const QuoteRefreshAttempt({
    required this.at,
    required this.source,
    required this.updated,
    required this.failed,
  });

  final DateTime at;
  final String source;
  final int updated;
  final int failed;
}

/// The last quote refresh attempt; null until one runs in this session.
final lastQuoteRefreshAttemptProvider =
    StateProvider<QuoteRefreshAttempt?>((ref) => null);

/// Quote refresh settings: daily auto-refresh toggle, last attempt facts,
/// a manual refresh action and the degraded engine state.
class MarketSettingsSection extends ConsumerWidget {
  const MarketSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(dailyAutoRefreshEnabledProvider);
    final lastAttempt = ref.watch(lastQuoteRefreshAttemptProvider);
    final service = ref.watch(quoteRefreshServiceProvider);

    return SettingsSectionCard(
      title: '行情与数据',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('每日自动刷新'),
              subtitle: const Text('每天首次打开时刷新一次行情估值'),
              value: enabled,
              onChanged: (value) {
                ref.read(dailyAutoRefreshEnabledProvider.notifier).state =
                    value;
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lastAttempt == null
                ? '上次刷新：本会话尚未刷新'
                : '上次刷新：${_formatDateTime(lastAttempt.at)} · '
                    '来源 ${lastAttempt.source} · '
                    '更新 ${lastAttempt.updated} 条 · '
                    '失败 ${lastAttempt.failed} 条',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (service == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '行情引擎不可用，显示的是最近一次估值',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          FilledButton.tonal(
            onPressed:
                service == null ? null : () => _refreshNow(context, ref),
            child: const Text('手动刷新行情'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshNow(BuildContext context, WidgetRef ref) async {
    final service = ref.read(quoteRefreshServiceProvider);
    if (service == null) return;
    final holdings = ref.read(holdingsProvider).value ?? [];
    try {
      final report = await service.refresh(holdings);
      final source = report.updated.isEmpty
          ? '无更新'
          : report.updated.first.fieldProvenance['currentPrice']?.source ??
              '未知';
      ref.read(lastQuoteRefreshAttemptProvider.notifier).state =
          QuoteRefreshAttempt(
        at: DateTime.now(),
        source: source,
        updated: report.updated.length + report.retained.length,
        failed: report.failed.length,
      );
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('行情引擎不可用，显示的是最近一次估值')),
        );
      }
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
