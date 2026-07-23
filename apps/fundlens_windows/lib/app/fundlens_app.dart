import 'package:flutter/material.dart';

import '../features/analysis/analysis_page.dart';
import '../features/holdings/holdings_page.dart';
import '../features/import_review/import_review_page.dart';
import '../features/overview/overview_page.dart';
import '../features/settings/settings_page.dart';
import '../features/snapshots/snapshots_page.dart';
import '../theme/fundlens_theme.dart';
import 'app_shell.dart';

/// Root widget of the FundLens Windows application.
///
/// Injects the six fixed feature pages into [AppShell]. Tests may pass
/// [pages] to substitute lighter stand-ins.
class FundLensApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FundLens',
      theme: FundLensTheme.light,
      home: AppShell(pages: pages ?? defaultPages),
    );
  }
}
