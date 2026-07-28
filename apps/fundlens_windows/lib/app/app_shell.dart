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

/// Breadcrumb group shown in the top bar, per destination.
const destinationCrumbs = <AppDestination, String>{
  AppDestination.overview: '组合',
  AppDestination.analysis: '组合',
  AppDestination.holdings: '组合',
  AppDestination.snapshots: '组合',
  AppDestination.importReview: '数据',
  AppDestination.settings: '数据',
};

/// Sidebar grouping: section label followed by its destinations.
const _navGroups = <(String, List<AppDestination>)>[
  ('组合', [
    AppDestination.overview,
    AppDestination.analysis,
    AppDestination.holdings,
    AppDestination.snapshots,
  ]),
  ('数据', [AppDestination.importReview, AppDestination.settings]),
];

/// Intent that switches the shell to a fixed destination (Ctrl+1..6).
class SelectDestinationIntent extends Intent {
  const SelectDestinationIntent(this.destination);
  final AppDestination destination;
}

/// Desktop shell: fixed-width warm-ink sidebar plus an expanded content
/// region. Page switches use [IndexedStack] so each page keeps its
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
                        crumb: destinationCrumbs[_selected]!,
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
      color: FundLensTokens.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _BrandBlock(),
            const SizedBox(height: 8),
            for (final (label, destinations) in _navGroups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 12, 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 11,
                    letterSpacing: 1.1,
                    color: Color(0xFF6E6656),
                  ),
                ),
              ),
              for (final destination in destinations)
                _NavItem(
                  destination: destination,
                  selected: destination == selected,
                  onSelect: () => onSelect(destination),
                ),
            ],
            const Spacer(),
            const _SidebarFooter(),
          ],
        ),
      ),
    );
  }
}

/// Brand mark: terracotta「镜」badge + serif wordmark + latin subtitle.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: FundLensTokens.accentStrong,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              '镜',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FundLens',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontWeight: FontWeight.w600,
                    fontSize: 19,
                    color: Color(0xFFF3EFE6),
                  ),
                ),
                Text(
                  'PORTFOLIO LENS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 9.5,
                    letterSpacing: 1,
                    color: Color(0xFF7D7462),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Engine note + local-only version line, pinned to the sidebar bottom.
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x14FFFDF8))),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 3.5, backgroundColor: FundLensTokens.sidebarInk),
              SizedBox(width: 6),
              Text(
                '行情引擎按需启动',
                style: TextStyle(
                  fontFamily: 'Noto Sans SC',
                  fontSize: 12,
                  color: FundLensTokens.sidebarInk,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'FundLens · 数据仅保存在本机',
            style: TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 11,
              color: Color(0xFF6E6656),
            ),
          ),
        ],
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
    final foreground = selected ? Colors.white : FundLensTokens.sidebarInk;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
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
                    ? FundLensTokens.sidebarActive
                    : (focused ? Colors.white.withValues(alpha: 0.06) : Colors.transparent),
                borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
                child: InkWell(
                  onTap: onSelect,
                  borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: focused
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
                            border: Border.all(color: FundLensTokens.surface, width: 2),
                          )
                        : null,
                    child: Row(
                      children: [
                        Icon(destinationIcons[destination], size: 17, color: foreground),
                        const SizedBox(width: 11),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Noto Sans SC',
                            fontSize: 13.5,
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
  const _TopBar({
    required this.crumb,
    required this.title,
    required this.onOpenDataStatus,
  });

  final String crumb;
  final String title;
  final VoidCallback onOpenDataStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: FundLensTokens.canvas,
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.pagePadding, vertical: 10),
      child: Row(
        children: [
          Text(crumb, style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('data-status-button'),
            onPressed: onOpenDataStatus,
            icon: const Icon(Icons.fact_check_outlined, size: 16),
            label: const Text('数据状态'),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 16,
            backgroundColor: FundLensTokens.ink,
            child: Text(
              '木',
              style: TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FundLensTokens.canvas,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
