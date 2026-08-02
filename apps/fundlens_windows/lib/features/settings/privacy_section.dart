import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'widgets/setting_info_row.dart';
import 'widgets/settings_section_card.dart';

/// Outcome of the startup sweep of orphaned import-temporary copies.
final class TempCleanupResult {
  const TempCleanupResult({
    required this.removedJobs,
    required this.issueReported,
  });

  /// Number of orphaned job directories removed at startup.
  final int removedJobs;

  /// True when at least one directory could not be removed and will be
  /// retried on the next launch.
  final bool issueReported;
}

/// Set by the bootstrap once the startup sweep completes; null means the
/// sweep has not finished (or never started) this session.
final tempCleanupResultProvider = StateProvider<TempCleanupResult?>(
  (ref) => null,
);

/// Privacy facts: local-only storage, encryption, temp-cleanup state,
/// redacted logging and the network scope. Every row is a factual statement,
/// not a toggle.
class PrivacySection extends ConsumerWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cleanup = ref.watch(tempCleanupResultProvider);
    final cleanupText = switch (cleanup) {
      null => '正在启动时检查…',
      TempCleanupResult(removedJobs: 0, issueReported: false) =>
        '已检查，无残留临时文件',
      TempCleanupResult(removedJobs: final n, issueReported: false) =>
        '已清理 $n 个过期临时目录',
      _ => '部分临时目录未能清理，将在下次启动重试',
    };
    final hasCleanupIssue = cleanup?.issueReported ?? false;

    return SettingsSectionCard(
      key: const ValueKey('privacy-section'),
      title: '隐私与安全',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingInfoRow(label: '本机存储', value: '持仓、截图与备份仅保存在本机'),
          const SettingInfoRow(
            label: '本地加密',
            value: '数据库 SQLCipher 加密，密钥由系统凭据保管',
          ),
          SettingInfoRow(
            label: '临时清理',
            value: cleanupText,
            valueColor: hasCleanupIssue ? theme.colorScheme.error : null,
          ),
          const SettingInfoRow(label: '日志脱敏', value: '日志中的路径与敏感信息已脱敏'),
          const SettingInfoRow(label: '网络范围', value: '仅在行情任务或手动刷新时联网'),
        ],
      ),
    );
  }
}
