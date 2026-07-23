import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import 'market_settings_section.dart';
import 'privacy_section.dart';
import 'structure_thresholds_section.dart';

/// 设置与备份 page: opt-in structure thresholds, quote refresh controls,
/// privacy facts and a descriptive (not yet functional) backup section.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: ListView(
      padding: const EdgeInsets.all(FundLensTokens.pagePadding),
      children: [
        Text('设置与备份', style: theme.textTheme.titleLarge),
        const SizedBox(height: 20),
        const StructureThresholdsSection(),
        const MarketSettingsSection(),
        const PrivacySection(),
        Container(
          key: const ValueKey('backup-section'),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: FundLensTokens.paper,
            borderRadius: BorderRadius.circular(FundLensTokens.radiusMedium),
            border: Border.all(color: FundLensTokens.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('加密备份', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              Text(
                '备份文件使用与数据库相同的密钥加密，仅保存在你选择的位置。'
                '此功能将在后续版本提供。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}
