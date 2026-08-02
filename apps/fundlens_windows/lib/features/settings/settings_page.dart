import 'package:flutter/material.dart';

import '../../theme/fundlens_tokens.dart';
import '../../widgets/grid_row.dart';
import '../../widgets/page_scaffold.dart';
import 'app_info_section.dart';
import 'asset_rules_section.dart';
import 'backup_section.dart';
import 'market_settings_section.dart';
import 'privacy_section.dart';
import 'snapshot_settings_section.dart';

/// 设置与备份 page. The six modules sit in two balanced columns; below the
/// grid collapse breakpoint the row falls back to a single stacked column.
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
        child: GridRow(
          children: [
            GridCol(
              span: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MarketSettingsSection(),
                  SnapshotSettingsSection(),
                  PrivacySection(),
                ],
              ),
            ),
            GridCol(
              span: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AssetRulesSection(),
                  BackupSection(),
                  AppInfoSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
