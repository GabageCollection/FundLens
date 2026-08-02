import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import '../../widgets/page_scaffold.dart';
import 'asset_rules_section.dart';
import 'backup_section.dart';
import 'market_settings_section.dart';
import 'privacy_section.dart';
import 'snapshot_settings_section.dart';
import 'update_section.dart';

/// 设置与备份 page: quote refresh controls, asset rules, snapshot settings,
/// the encrypted backup section, privacy facts and app info.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      tier: PageWidthTier.form,
      crumb: '数据',
      title: '设置与备份',
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: FundLensTokens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MarketSettingsSection(),
            AssetRulesSection(),
            SnapshotSettingsSection(),
            BackupSection(),
            PrivacySection(),
            UpdateSection(),
          ],
        ),
      ),
    );
  }
}
