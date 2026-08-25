import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/analysis/analysis_page.dart';
import '../features/holdings/holdings_page.dart';
import '../features/import_review/import_review_page.dart';
import '../features/overview/overview_page.dart';
import '../features/settings/persisted_settings.dart';
import '../features/settings/settings_page.dart';
import '../features/snapshots/snapshots_page.dart';
import '../theme/fundlens_theme.dart';
import '../theme/fundlens_tokens.dart';
import 'app_shell.dart';

/// Root widget of the FundLens Windows application.
///
/// Injects the six fixed feature pages into [AppShell]. Tests may pass
/// [pages] to substitute lighter stand-ins.
class FundLensApp extends ConsumerWidget {
  const FundLensApp({super.key, this.pages});

  /// One widget per [AppDestination], in enum order. Defaults to the six
  /// real feature pages.
  final List<Widget>? pages;

  static const defaultPages = <Widget>[
    OverviewPage(),
    AnalysisPage(),
    HoldingsPage(),
    SnapshotsPage(),
    ImportReviewPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themeModeProvider);
    final systemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final dark = preference == ThemeModePreference.dark ||
        (preference == ThemeModePreference.system && systemDark);
    // 组件直接读取 FundLensTokens 语义色:先切换全局调色板,再构建主题,
    // 两者必须指向同一明暗实例。
    FundLensTokens.applyPalette(
      dark ? FundLensPalette.dark : FundLensPalette.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FundLens',
      theme: dark ? FundLensTheme.dark : FundLensTheme.light,
      home: AppShell(pages: pages ?? defaultPages),
    );
  }
}
