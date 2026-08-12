import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/data_health/data_health_button.dart';
import '../theme/fundlens_tokens.dart';

/// The six fixed destinations of the FundLens desktop shell.
enum AppDestination {
  overview,
  analysis,
  holdings,
  snapshots,
  importReview,
  settings,
}

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

/// Sidebar grouping: section label followed by its destinations.
const _navGroups = <(String, List<AppDestination>)>[
  (
    '组合',
    [
      AppDestination.overview,
      AppDestination.analysis,
      AppDestination.holdings,
      AppDestination.snapshots,
    ],
  ),
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
    : assert(
        pages.length == AppDestination.values.length,
        'AppShell requires exactly six pages',
      );

  /// One widget per [AppDestination], in enum order.
  final List<Widget> pages;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppDestination _selected = AppDestination.overview;

  /// 768–1279 区间用户手动折叠状态,会话内保持。
  bool _navCollapsed = false;

  void _select(AppDestination destination) {
    if (_selected != destination) {
      setState(() => _selected = destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      for (final (index, destination) in AppDestination.values.indexed)
        SingleActivator(
          LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + index),
          control: true,
        ): SelectDestinationIntent(
          destination,
        ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final drawerMode = width < FundLensTokens.navDrawerBreakpoint;
              final collapsible =
                  !drawerMode && width < FundLensTokens.navFullBreakpoint;
              final collapsed = collapsible && _navCollapsed;

              return Scaffold(
                drawer: drawerMode
                    ? Drawer(
                        width: FundLensTokens.navWidth,
                        child: _NavigationRegion(
                          selected: _selected,
                          collapsed: false,
                          onSelect: (destination) {
                            _select(destination);
                            Navigator.of(context).maybePop();
                          },
                        ),
                      )
                    : null,
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!drawerMode)
                      _NavigationRegion(
                        selected: _selected,
                        collapsed: collapsed,
                        collapsible: collapsible,
                        onToggleCollapse: () =>
                            setState(() => _navCollapsed = !_navCollapsed),
                        onSelect: _select,
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(drawerMode: drawerMode),
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
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavigationRegion extends StatelessWidget {
  const _NavigationRegion({
    required this.selected,
    required this.collapsed,
    required this.onSelect,
    this.collapsible = false,
    this.onToggleCollapse,
  });

  final AppDestination selected;

  /// 折叠为 64px 图标栏:隐藏分组标签、文字与页脚,图标 + Tooltip。
  final bool collapsed;

  /// 768–1279 区间允许手动折叠;折叠开关位于品牌区而非顶栏。
  final bool collapsible;
  final VoidCallback? onToggleCollapse;

  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    // 内容按目标态即时切换并固定在目标宽度布局,宽度动画由外层裁剪,
    // 避免展开/折叠过渡期间 Row 子内容瞬时溢出(overflow 异常)。
    final contentWidth = collapsed
        ? FundLensTokens.navRailWidth
        : FundLensTokens.navWidth;
    return AnimatedContainer(
      key: const ValueKey('app-nav'),
      duration: const Duration(milliseconds: 150),
      width: contentWidth,
      color: FundLensTokens.sidebar,
      clipBehavior: Clip.hardEdge,
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: contentWidth,
        maxWidth: contentWidth,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (collapsed)
                Column(
                  children: [
                    const _BrandBlock(collapsed: true),
                    if (collapsible)
                      _CollapseToggle(
                        collapsed: true,
                        onToggle: onToggleCollapse!,
                      ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(child: _BrandBlock()),
                    if (collapsible)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: FundLensTokens.space3,
                          right: FundLensTokens.space3,
                        ),
                        child: _CollapseToggle(
                          collapsed: false,
                          onToggle: onToggleCollapse!,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: FundLensTokens.space2),
              for (final (label, destinations) in _navGroups) ...[
                if (!collapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FundLensTokens.space6,
                      FundLensTokens.space3,
                      FundLensTokens.space3,
                      FundLensTokens.space2,
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Noto Sans SC',
                        fontSize: 12,
                        letterSpacing: 1.1,
                        color: FundLensTokens.sidebarMuted,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: FundLensTokens.space3),
                for (final destination in destinations)
                  _NavItem(
                    destination: destination,
                    selected: destination == selected,
                    collapsed: collapsed,
                    onSelect: () => onSelect(destination),
                  ),
              ],
              const Spacer(),
              if (!collapsed) const _SidebarFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 折叠/展开开关:位于侧栏品牌区,图标与 tooltip 随当前态切换。
class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('nav-collapse-toggle'),
      icon: Icon(
        collapsed ? Icons.chevron_right : Icons.chevron_left,
        size: 18,
      ),
      color: FundLensTokens.sidebarInk,
      tooltip: collapsed ? '展开导航' : '折叠导航',
      onPressed: onToggle,
    );
  }
}

/// Brand mark: terracotta「镜」badge + serif wordmark + latin subtitle.
class _BrandBlock extends StatelessWidget {
  const _BrandBlock({this.collapsed = false});

  /// 折叠态只渲染居中的「镜」badge,隐藏文字标。
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final badge = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: FundLensTokens.accentStrong,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusControl),
      ),
      alignment: Alignment.center,
      child: Text(
        '镜',
        style: TextStyle(
          fontFamily: 'Noto Serif SC',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: onPrimary,
        ),
      ),
    );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(
          top: FundLensTokens.space6,
          bottom: FundLensTokens.space3,
        ),
        child: Center(child: badge),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FundLensTokens.space6,
        FundLensTokens.space6,
        FundLensTokens.space6,
        FundLensTokens.space3,
      ),
      child: Row(
        children: [
          badge,
          const SizedBox(width: FundLensTokens.space3),
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
                    fontSize: 18,
                    color: FundLensTokens.sidebarTitle,
                  ),
                ),
                Text(
                  'PORTFOLIO LENS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 12,
                    letterSpacing: 1,
                    color: FundLensTokens.sidebarMuted,
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
      padding: const EdgeInsets.symmetric(
        horizontal: FundLensTokens.space6,
        vertical: FundLensTokens.space4,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: FundLensTokens.surface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 3.5,
                backgroundColor: FundLensTokens.sidebarInk,
              ),
              SizedBox(width: FundLensTokens.space2),
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
          SizedBox(height: FundLensTokens.space1),
          Text(
            'FundLens · 数据仅保存在本机',
            style: TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 12,
              color: FundLensTokens.sidebarMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onSelect,
  });

  final AppDestination destination;
  final bool selected;

  /// 折叠态图标居中、不渲染文字,以 Tooltip 提供标签语义。
  final bool collapsed;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final label = destinationLabels[destination]!;
    final foreground = selected
        ? Theme.of(context).colorScheme.onPrimary
        : FundLensTokens.sidebarInk;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FundLensTokens.space3,
        vertical: FundLensTokens.space1,
      ),
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
                    : (focused
                          ? FundLensTokens.surface.withValues(alpha: 0.06)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
                child: InkWell(
                  onTap: onSelect,
                  borderRadius: BorderRadius.circular(
                    FundLensTokens.radiusSmall,
                  ),
                  child: Tooltip(
                    message: collapsed ? label : '',
                    child: Container(
                      height: FundLensTokens.minTapTarget,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FundLensTokens.space3,
                      ),
                      decoration: focused
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                FundLensTokens.radiusSmall,
                              ),
                              border: Border.all(
                                color: FundLensTokens.surface,
                                width: FundLensTokens.focusOutlineWidth,
                              ),
                            )
                          : null,
                      child: Row(
                        mainAxisAlignment: collapsed
                            ? MainAxisAlignment.center
                            : MainAxisAlignment.start,
                        children: [
                          Icon(
                            destinationIcons[destination],
                            size: 16,
                            color: foreground,
                          ),
                          if (!collapsed) ...[
                            const SizedBox(width: FundLensTokens.space3),
                            // Expanded + ellipsis:高 DPI/200% 缩放时文字不横向溢出。
                            Expanded(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Noto Sans SC',
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: foreground,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

/// 顶部全局操作条：左侧仅抽屉入口(窄屏)，右侧为数据健康入口与账户头像。
/// 折叠开关已移入侧栏品牌区;页面标题与面包屑在各页面的 PageHeader。
class _TopBar extends StatelessWidget {
  const _TopBar({required this.drawerMode});

  final bool drawerMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FundLensTokens.canvas,
      padding: const EdgeInsets.symmetric(
        horizontal: FundLensTokens.pagePadding,
        vertical: FundLensTokens.space3,
      ),
      child: Row(
        children: [
          if (drawerMode)
            IconButton(
              key: const ValueKey('nav-drawer-button'),
              icon: const Icon(Icons.menu),
              tooltip: '打开导航',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const Spacer(),
          const DataHealthButton(),
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
