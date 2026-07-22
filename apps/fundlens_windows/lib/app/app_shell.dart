import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/fundlens_tokens.dart';

/// The six fixed destinations of the FundLens desktop shell.
enum AppDestination { overview, analysis, holdings, snapshots, importReview, settings }

const destinationLabels = <AppDestination, String>{
  AppDestination.overview: '资产总览',
  AppDestination.analysis: '资产分析',
  AppDestination.holdings: '全部持仓',
  AppDestination.snapshots: '历史快照',
  AppDestination.importReview: '导入与识别',
  AppDestination.settings: '设置与备份',
};

const destinationIcons = <AppDestination, IconData>{
  AppDestination.overview: Icons.dashboard_outlined,
  AppDestination.analysis: Icons.insights_outlined,
  AppDestination.holdings: Icons.table_rows_outlined,
  AppDestination.snapshots: Icons.photo_library_outlined,
  AppDestination.importReview: Icons.fact_check_outlined,
  AppDestination.settings: Icons.settings_outlined,
};

/// Intent that switches the shell to a fixed destination (Ctrl+1..6).
class SelectDestinationIntent extends Intent {
  const SelectDestinationIntent(this.destination);
  final AppDestination destination;
}

/// Desktop shell: fixed-width Graphite navigation rail plus an expanded
/// content region. Page switches use [IndexedStack] so each page keeps its
/// search/filter state.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.pages})
      : assert(pages.length == AppDestination.values.length, 'AppShell requires exactly six pages');

  /// One widget per [AppDestination], in enum order.
  final List<Widget> pages;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _selected = AppDestination.overview;

  void _select(AppDestination destination) {
    if (_selected != destination) {
      setState(() => _selected = destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      for (final (index, destination) in AppDestination.values.indexed)
        SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + index), control: true):
            SelectDestinationIntent(destination),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          SelectDestinationIntent: CallbackAction<SelectDestinationIntent>(
            onInvoke: (intent) {
              _select(intent.destination);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NavigationRegion(
                  selected: _selected,
                  onSelect: _select,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        title: destinationLabels[_selected]!,
                        onOpenDataStatus: () => _select(AppDestination.importReview),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: IndexedStack(
                          index: _selected.index,
                          children: widget.pages,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationRegion extends StatelessWidget {
  const _NavigationRegion({required this.selected, required this.onSelect});

  final AppDestination selected;
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('app-nav'),
      width: FundLensTokens.navWidth,
      color: FundLensTokens.graphite,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Text(
                'FundLens',
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: FundLensTokens.paper,
                ),
              ),
            ),
            for (final destination in AppDestination.values)
              _NavItem(
                destination: destination,
                selected: destination == selected,
                onSelect: () => onSelect(destination),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onSelect});

  final AppDestination destination;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final label = destinationLabels[destination]!;
    final foreground = selected ? FundLensTokens.paper : const Color(0xFF9AA7A1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: FocusableActionDetector(
        onShowFocusHighlight: (_) {},
        child: Builder(
          builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Semantics(
              button: true,
              selected: selected,
              label: label,
              child: Material(
                color: selected
                    ? FundLensTokens.lensIndigo
                    : (focused ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
                borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
                child: InkWell(
                  onTap: onSelect,
                  borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: focused
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
                            border: Border.all(color: FundLensTokens.paper, width: 2),
                          )
                        : null,
                    child: Row(
                      children: [
                        Icon(destinationIcons[destination], size: 18, color: foreground),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Noto Sans SC',
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onOpenDataStatus});

  final String title;
  final VoidCallback onOpenDataStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: FundLensTokens.paper,
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.pagePadding, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          OutlinedButton.icon(
            key: const ValueKey('data-status-button'),
            onPressed: onOpenDataStatus,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('数据状态'),
            style: OutlinedButton.styleFrom(
              foregroundColor: FundLensTokens.graphite,
              side: const BorderSide(color: FundLensTokens.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
