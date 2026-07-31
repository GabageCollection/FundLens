import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import '../../widgets/page_scaffold.dart';
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
    return const PageScaffold(
      tier: PageWidthTier.form,
      crumb: '数据',
      title: '设置与备份',
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: FundLensTokens.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StructureThresholdsSection(),
            MarketSettingsSection(),
            UpdateSection(),
            PrivacySection(),
            BackupSection(),
          ],
        ),
      ),
    );
  }
}
