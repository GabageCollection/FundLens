import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import 'backup_section.dart';
import 'market_settings_section.dart';
import 'privacy_section.dart';
import 'structure_thresholds_section.dart';
import 'update_section.dart';

/// 设置与备份 page: opt-in structure thresholds, quote refresh controls,
/// the manual update check, privacy facts and the encrypted backup section.
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
        const UpdateSection(),
        const PrivacySection(),
        const BackupSection(),
      ],
      ),
    );
  }
}
