import 'package:flutter/material.dart';

import '../theme/fundlens_theme.dart';
import 'app_shell.dart';

/// Root widget of the FundLens Windows application.
///
/// Injects the six fixed page widgets into [AppShell]. Later tasks replace
/// the placeholder pages with real feature pages.
class FundLensApp extends StatelessWidget {
  const FundLensApp({super.key, this.pages});

  /// One widget per [AppDestination], in enum order. Defaults to placeholders.
  final List<Widget>? pages;

  @override
  Widget build(BuildContext context) {
    final effectivePages = pages ??
        [
          for (final destination in AppDestination.values)
            _PlaceholderPage(title: _placeholderTitles[destination]!),
        ];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FundLens',
      theme: FundLensTheme.light,
      home: AppShell(pages: effectivePages),
    );
  }
}

const _placeholderTitles = <AppDestination, String>{
  AppDestination.overview: '资产总览',
  AppDestination.analysis: '资产分析',
  AppDestination.holdings: '全部持仓',
  AppDestination.snapshots: '历史快照',
  AppDestination.importReview: '导入与识别',
  AppDestination.settings: '设置与备份',
};

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('page-$title', style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
