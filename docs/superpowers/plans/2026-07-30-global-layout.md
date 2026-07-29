# FundLens 全局页面布局优化 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 FundLens Windows 六页面引入统一限宽容器(1440/1680/1120 三档)、12 列栅格、统一 PageHeader、响应式三态侧栏,消除宽屏拉伸与大面积留白。

**Architecture:** 新增 `lib/widgets/` 布局层(`PageScaffold`/`PageHeader`/`GridRow`),`AppShell` 改造为断点驱动的三态侧栏 + 全宽简化顶栏,六个页面逐一迁入 `PageScaffold`。设计文档:`docs/superpowers/specs/2026-07-30-global-layout-design.md`。

**Tech Stack:** Flutter Windows、Riverpod、flutter_test(含 golden)。

## Global Constraints

- 所有颜色/字号/间距/圆角只用 `FundLensTokens` 语义变量,禁止硬编码;间距只允许 4/8/12/16/24/32/40/48。
- 红盈利、绿亏损;盈亏必须同时给符号或文字。
- 金额用 IBM Plex Mono(`FundLensTextStyles.financialNumber`),标题宋体 24/32 w600(`theme.textTheme.titleLarge` 现状即此样式)。
- 断点(逻辑像素):≥1280 完整侧栏 216px;768–1279 可手动折叠为 64px 图标栏;<768 抽屉导航。
- 正文档位:standard=1440(总览/分析)、dense=1680(持仓/快照)、form=1120(设置/导入)。
- 不引入新依赖;不改 Python 引擎与 `packages/fundlens_core`。
- 测试运行目录一律为 `apps/fundlens_windows`;Dart 核心包为 `packages/fundlens_core`。
- 每个任务遵循 TDD:先失败测试,再最小实现,再回归,再提交。提交信息使用中文。

---

### Task 1: 布局 tokens — 侧栏宽度与断点/容器/栅格常量

**Files:**
- Modify: `apps/fundlens_windows/lib/theme/fundlens_tokens.dart:101-104`(navWidth 段)
- Test: `apps/fundlens_windows/test/theme/theme_test.dart:30`

**Interfaces:**
- Produces(后续任务全部依赖):
  - `FundLensTokens.navWidth = 216`
  - `FundLensTokens.navRailWidth = 64`
  - `FundLensTokens.navFullBreakpoint = 1280`
  - `FundLensTokens.navDrawerBreakpoint = 768`
  - `FundLensTokens.contentMaxStandard = 1440`
  - `FundLensTokens.contentMaxDense = 1680`
  - `FundLensTokens.contentMaxForm = 1120`
  - `FundLensTokens.gridGutter = 16`
  - `FundLensTokens.gridCollapseBelow = 960`

- [ ] **Step 1: 改写失败测试**

将 `test/theme/theme_test.dart:30` 的 `expect(FundLensTokens.navWidth, 232);` 替换为:

```dart
    expect(FundLensTokens.navWidth, 216);
    expect(FundLensTokens.navRailWidth, 64);
    expect(FundLensTokens.navFullBreakpoint, 1280);
    expect(FundLensTokens.navDrawerBreakpoint, 768);
    expect(FundLensTokens.contentMaxStandard, 1440);
    expect(FundLensTokens.contentMaxDense, 1680);
    expect(FundLensTokens.contentMaxForm, 1120);
    expect(FundLensTokens.gridGutter, 16);
    expect(FundLensTokens.gridCollapseBelow, 960);
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd apps/fundlens_windows && flutter test test/theme/theme_test.dart`
Expected: FAIL — 新常量不存在(编译错误)+ navWidth 断言不符。

- [ ] **Step 3: 实现 tokens**

`lib/theme/fundlens_tokens.dart` 中把 `static const double navWidth = 232;` 改为:

```dart
  // ---- 布局:侧边栏 ----
  /// 完整侧边栏宽度。
  static const double navWidth = 216;

  /// 折叠态图标栏宽度。
  static const double navRailWidth = 64;

  /// ≥该宽度完整显示侧栏(逻辑像素)。
  static const double navFullBreakpoint = 1280;

  /// <该宽度切换为抽屉导航(逻辑像素)。
  static const double navDrawerBreakpoint = 768;

  // ---- 布局:正文容器最大宽度 ----
  /// 普通页面(总览、分析)。
  static const double contentMaxStandard = 1440;

  /// 数据密集页面(全部持仓、历史快照)。
  static const double contentMaxDense = 1680;

  /// 表单页面(设置、导入与识别),取 1040–1200 中间值。
  static const double contentMaxForm = 1120;

  // ---- 布局:12 列栅格 ----
  /// 栅格列间距。
  static const double gridGutter = 16;

  /// 容器低于该宽度时栅格降为单列堆叠。
  static const double gridCollapseBelow = 960;
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd apps/fundlens_windows && flutter test test/theme/theme_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/theme/fundlens_tokens.dart apps/fundlens_windows/test/theme/theme_test.dart
git commit -m "feat(ui): 布局 tokens — 侧栏216/断点/正文容器三档/栅格常量"
```

---

### Task 2: PageHeader 组件

**Files:**
- Create: `apps/fundlens_windows/lib/widgets/page_header.dart`
- Test: `apps/fundlens_windows/test/widgets/page_header_test.dart`

**Interfaces:**
- Produces: `PageHeader({Key?, required String crumb, required String title, List<Widget> actions = const []})`
  - 面包屑 12px muted 在上;标题用 `theme.textTheme.titleLarge`;actions 位于标题行右侧,窄屏经 `Wrap` 换行到标题下方。

- [ ] **Step 1: 写失败测试**

创建 `test/widgets/page_header_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_header.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    double width = 1200,
    List<Widget> actions = const [],
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(
          body: PageHeader(crumb: '组合', title: '资产总览', actions: actions),
        ),
      ),
    );
  }

  testWidgets('面包屑与标题形成层级:面包屑小字在上,标题大字在下', (tester) async {
    await pumpHeader(tester);
    final crumb = tester.widget<Text>(find.text('组合'));
    final title = tester.widget<Text>(find.text('资产总览'));
    expect(crumb.style!.fontSize, 12);
    expect(title.style!.fontSize, greaterThanOrEqualTo(20));
    // 面包屑位于标题上方
    expect(
      tester.getTopLeft(find.text('组合')).dy,
      lessThan(tester.getTopLeft(find.text('资产总览')).dy,
    ));
  });

  testWidgets('操作按钮显示在标题行右侧', (tester) async {
    await pumpHeader(
      tester,
      actions: [FilledButton(onPressed: () {}, child: const Text('新建快照'))],
    );
    expect(find.text('新建快照'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('新建快照')).dx,
      greaterThan(tester.getTopLeft(find.text('资产总览')).dx),
    );
  });

  testWidgets('窄屏下操作按钮换行且不溢出', (tester) async {
    await pumpHeader(
      tester,
      width: 420,
      actions: [
        const SizedBox(width: 280, child: TextField()),
        FilledButton(onPressed: () {}, child: const Text('添加持仓')),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('添加持仓'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/widgets/page_header_test.dart`
Expected: FAIL — `page_header.dart` 不存在。

- [ ] **Step 3: 实现 PageHeader**

创建 `lib/widgets/page_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 统一页面页头:面包屑(12px 辅助文字)在上、页面标题在下形成层级,
/// 操作按钮位于标题行右侧;窄屏时操作区经 Wrap 换行到标题下方,
/// 避免遮挡与溢出。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.crumb,
    required this.title,
    this.actions = const [],
  });

  /// 面包屑分组名(「组合」「数据」)。
  final String crumb;

  /// 页面标题。
  final String title;

  /// 标题行右侧的操作按钮/控件。
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          crumb,
          style: theme.textTheme.bodySmall?.copyWith(
            color: FundLensTokens.muted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: FundLensTokens.space1),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: FundLensTokens.space4,
          runSpacing: FundLensTokens.space3,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (actions.isNotEmpty)
              Wrap(
                spacing: FundLensTokens.space3,
                runSpacing: FundLensTokens.space2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/widgets/page_header_test.dart`
Expected: PASS(3 个用例)

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/widgets/page_header.dart apps/fundlens_windows/test/widgets/page_header_test.dart
git commit -m "feat(ui): 统一 PageHeader 组件 — 面包屑/标题层级 + 操作区"
```

---

### Task 3: PageScaffold 与 PageWidthTier

**Files:**
- Create: `apps/fundlens_windows/lib/widgets/page_scaffold.dart`
- Test: `apps/fundlens_windows/test/widgets/page_scaffold_test.dart`

**Interfaces:**
- Consumes: `PageHeader`(Task 2);`FundLensTokens.contentMax*`(Task 1)。
- Produces:
  - `enum PageWidthTier { standard(1440), dense(1680), form(1120) }`,字段 `final double maxWidth`
  - `PageScaffold({Key?, required PageWidthTier tier, required String crumb, required String title, List<Widget> actions = const [], required Widget body})`
  - 结构:居中 `ConstrainedBox(maxWidth: tier.maxWidth)` + 左右 24 padding;Column[24 上间距, PageHeader, 24 titleGap, Expanded(body)],外底 24。

- [ ] **Step 1: 写失败测试**

创建 `test/widgets/page_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_header.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

void main() {
  Future<void> pumpScaffold(
    WidgetTester tester,
    PageWidthTier tier, {
    double width = 1920,
  }) async {
    tester.view.physicalSize = Size(width, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(
          body: PageScaffold(
            tier: tier,
            crumb: '组合',
            title: '测试页',
            body: const ColoredBox(color: Colors.red, child: SizedBox.expand()),
          ),
        ),
      ),
    );
  }

  testWidgets('standard 档在 1920 宽屏下限宽 1440 并居中', (tester) async {
    await pumpScaffold(tester, PageWidthTier.standard);
    final headerLeft = tester.getTopLeft(find.byType(PageHeader)).dx;
    final bodySize = tester.getSize(find.byType(ColoredBox));
    // 正文宽度 = 1440 - 左右各 24 padding
    expect(bodySize.width, 1440 - 48);
    // 居中:左侧空白 = (1920 - 1440) / 2 + 24
    expect(headerLeft, (1920 - 1440) / 2 + 24);
  });

  testWidgets('dense 档限宽 1680', (tester) async {
    await pumpScaffold(tester, PageWidthTier.dense);
    expect(tester.getSize(find.byType(ColoredBox)).width, 1680 - 48);
  });

  testWidgets('form 档限宽 1120', (tester) async {
    await pumpScaffold(tester, PageWidthTier.form);
    expect(tester.getSize(find.byType(ColoredBox)).width, 1120 - 48);
  });

  testWidgets('窗口窄于档位时不溢出,跟随可用宽度', (tester) async {
    await pumpScaffold(tester, PageWidthTier.standard, width: 900);
    expect(tester.getSize(find.byType(ColoredBox)).width, 900 - 48);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/widgets/page_scaffold_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: 实现 PageScaffold**

创建 `lib/widgets/page_scaffold.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';
import 'page_header.dart';

/// 正文最大宽度档位。
enum PageWidthTier {
  /// 普通页面:资产总览、资产分析。
  standard(FundLensTokens.contentMaxStandard),

  /// 数据密集页面:全部持仓、历史快照。
  dense(FundLensTokens.contentMaxDense),

  /// 表单页面:设置与备份、导入与识别。
  form(FundLensTokens.contentMaxForm);

  const PageWidthTier(this.maxWidth);

  final double maxWidth;
}

/// 统一页面骨架:居中限宽容器 + PageHeader + 正文。
///
/// 页面标题、卡片和表格因此共享同一条左右边界;窗口窄于档位时
/// 跟随可用宽度,不产生水平溢出。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.tier,
    required this.crumb,
    required this.title,
    this.actions = const [],
    required this.body,
  });

  final PageWidthTier tier;
  final String crumb;
  final String title;
  final List<Widget> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tier.maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FundLensTokens.pagePadding,
              0,
              FundLensTokens.pagePadding,
              FundLensTokens.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: FundLensTokens.pagePadding),
                PageHeader(crumb: crumb, title: title, actions: actions),
                const SizedBox(height: FundLensTokens.titleGap),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/widgets/page_scaffold_test.dart`
Expected: PASS(4 个用例)

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/widgets/page_scaffold.dart apps/fundlens_windows/test/widgets/page_scaffold_test.dart
git commit -m "feat(ui): PageScaffold 统一限宽容器 — 1440/1680/1120 三档居中"
```

---

### Task 4: GridRow / GridCol 12 列栅格

**Files:**
- Create: `apps/fundlens_windows/lib/widgets/grid_row.dart`
- Test: `apps/fundlens_windows/test/widgets/grid_row_test.dart`

**Interfaces:**
- Consumes: `FundLensTokens.gridGutter / gridCollapseBelow`(Task 1)。
- Produces:
  - `GridCol({required int span, required Widget child})`(span 1–12)
  - `GridRow({Key?, required List<GridCol> children, double gutter = 16, double collapseBelow = 960})`
  - 宽模式:`Row` 内按 `span` 计算定宽;窄模式(宽度 < collapseBelow):`Column` 自然高度堆叠。

- [ ] **Step 1: 写失败测试**

创建 `test/widgets/grid_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/widgets/grid_row.dart';

void main() {
  Future<void> pumpGrid(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GridRow(
            children: const [
              GridCol(span: 7, child: ColoredBox(color: Colors.red, child: SizedBox(height: 40))),
              GridCol(span: 5, child: ColoredBox(color: Colors.blue, child: SizedBox(height: 40))),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('宽模式按 12 列比例分配宽度', (tester) async {
    await pumpGrid(tester, 1216); // 去掉 11 个 gutter 后每列 (1216-176)/12≈86.67
    final first = tester.getSize(find.byType(ColoredBox).first).width;
    final second = tester.getSize(find.byType(ColoredBox).last).width;
    expect(first / second, closeTo(7 / 5, 0.02));
    expect(first + second + 16, closeTo(1216, 0.5));
  });

  testWidgets('低于 collapseBelow 时降为纵向堆叠', (tester) async {
    await pumpGrid(tester, 800);
    final firstTop = tester.getTopLeft(find.byType(ColoredBox).first).dy;
    final secondTop = tester.getTopLeft(find.byType(ColoredBox).last).dy;
    expect(secondTop, greaterThan(firstTop));
    // 堆叠时两列同宽
    expect(
      tester.getSize(find.byType(ColoredBox).first).width,
      tester.getSize(find.byType(ColoredBox).last).width,
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/widgets/grid_row_test.dart`
Expected: FAIL — 文件不存在。

- [ ] **Step 3: 实现 GridRow**

创建 `lib/widgets/grid_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 12 列栅格中的一列。
class GridCol {
  const GridCol({required this.span, required this.child})
    : assert(span >= 1 && span <= 12, 'GridCol.span 必须在 1–12 之间');

  /// 占用列数(1–12),同一 GridRow 内各列 span 之和应为 12。
  final int span;

  final Widget child;
}

/// 轻量 12 列响应式栅格。
///
/// 宽度 ≥ [collapseBelow] 时按 12 列比例横向分布;低于该宽度时
/// 降为单列纵向堆叠,避免少量内容被压扁或独占超宽区域。
class GridRow extends StatelessWidget {
  const GridRow({
    super.key,
    required this.children,
    this.gutter = FundLensTokens.gridGutter,
    this.collapseBelow = FundLensTokens.gridCollapseBelow,
  });

  final List<GridCol> children;
  final double gutter;
  final double collapseBelow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < collapseBelow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: gutter),
                children[i].child,
              ],
            ],
          );
        }
        final unit = (width - 11 * gutter) / 12;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: gutter),
              SizedBox(
                width:
                    unit * children[i].span +
                    gutter * (children[i].span - 1),
                child: children[i].child,
              ),
            ],
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/widgets/grid_row_test.dart`
Expected: PASS(2 个用例)

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/widgets/grid_row.dart apps/fundlens_windows/test/widgets/grid_row_test.dart
git commit -m "feat(ui): 12 列响应式栅格 GridRow/GridCol — 窄屏自动单列"
```

---

### Task 5: AppShell 响应式三态侧栏 + 顶栏简化

**Files:**
- Modify: `apps/fundlens_windows/lib/app/app_shell.dart`(全文改造 `_AppShellState.build`、`_NavigationRegion`、`_TopBar`;保留 enum/labels/icons/crumbs/_navGroups/快捷键/品牌块/页脚)
- Test: `apps/fundlens_windows/test/app/app_shell_test.dart`

**Interfaces:**
- Consumes: `FundLensTokens.navWidth / navRailWidth / navFullBreakpoint / navDrawerBreakpoint`(Task 1)。
- Produces(测试依赖的稳定选择器):
  - 侧栏容器 key `'app-nav'`(宽 216 或折叠 64;抽屉模式关闭时不在树中)
  - 折叠切换按钮 key `'nav-collapse-toggle'`(仅 768–1279 出现)
  - 汉堡按钮 key `'nav-drawer-button'`(仅 <768 出现)
  - 数据状态按钮 key `'data-status-button'`(保留)
  - `_NavigationRegion({required AppDestination selected, required bool collapsed, required ValueChanged<AppDestination> onSelect})`
  - 顶栏不再渲染页面标题与面包屑(下沉到 Task 6–10 的 PageHeader)。

- [ ] **Step 1: 追加失败测试**

在 `test/app/app_shell_test.dart` 的 `main()` 末尾(`navigation shows a visible focus indicator` 之后)追加:

```dart
  testWidgets('≥1280 完整侧栏宽度为 216', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navWidth,
    );
  });

  testWidgets('768–1279 可手动折叠为 64px 图标栏', (tester) async {
    await pumpAtSize(tester, const Size(1100, 800));
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navWidth,
    );
    await tester.tap(find.byKey(const ValueKey('nav-collapse-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navRailWidth,
    );
    // 折叠后文字标签隐藏
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('app-nav')),
        matching: find.text('资产总览'),
      ),
      findsNothing,
    );
    // 再次点击恢复
    await tester.tap(find.byKey(const ValueKey('nav-collapse-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const ValueKey('app-nav'))).width,
      FundLensTokens.navWidth,
    );
  });

  testWidgets('<768 切换为抽屉导航', (tester) async {
    await pumpAtSize(tester, const Size(700, 800));
    expect(find.byKey(const ValueKey('app-nav')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-drawer-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-nav')), findsOneWidget);
    await tester.tap(find.text('全部持仓'));
    await tester.pumpAndSettle();
    expect(find.text('page-holdings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('顶栏不再渲染页面标题(下沉到 PageHeader)', (tester) async {
    await pumpAtSize(tester, const Size(1440, 900));
    // 替身页面只含 page-<name> 文本;顶栏若仍渲染标题则会出现「资产总览」
    expect(find.text('资产总览'), findsNothing);
  });
```

并在文件顶部 import 追加:

```dart
import 'package:fundlens_windows/theme/fundlens_tokens.dart';
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/app/app_shell_test.dart`
Expected: FAIL — `'nav-collapse-toggle'` / `'nav-drawer-button'` 找不到;侧栏宽度断言 216 ≠ 232;折叠后标签未隐藏。

- [ ] **Step 3: 改造 AppShell**

`lib/app/app_shell.dart` 做以下三处改造(其余保持不变):

**(a) `_AppShellState`** — 新增折叠状态,build 改为断点驱动:

```dart
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
              final drawerMode =
                  width < FundLensTokens.navDrawerBreakpoint;
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
                        onSelect: _select,
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(
                            drawerMode: drawerMode,
                            collapsible: collapsible,
                            collapsed: collapsed,
                            onToggleCollapse: () => setState(
                              () => _navCollapsed = !_navCollapsed,
                            ),
                            onOpenDataStatus: () =>
                                _select(AppDestination.importReview),
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
              );
            },
          ),
        ),
      ),
    );
  }
}
```

**(b) `_NavigationRegion`** — 支持折叠态:

```dart
class _NavigationRegion extends StatelessWidget {
  const _NavigationRegion({
    required this.selected,
    required this.collapsed,
    required this.onSelect,
  });

  final AppDestination selected;

  /// 折叠为 64px 图标栏:隐藏分组标签、文字与页脚,图标 + Tooltip。
  final bool collapsed;

  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: const ValueKey('app-nav'),
      duration: const Duration(milliseconds: 150),
      width: collapsed ? FundLensTokens.navRailWidth : FundLensTokens.navWidth,
      color: FundLensTokens.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BrandBlock(collapsed: collapsed),
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
    );
  }
}
```

**(c) `_BrandBlock`** — 增加 `collapsed` 参数(`const _BrandBlock({this.collapsed = false})`,字段 `final bool collapsed`);`collapsed` 时只渲染居中的「镜」badge:

```dart
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
              // …原有 FundLens / PORTFOLIO LENS 两行的 Text 保持不变…
            ),
          ),
        ],
      ),
    );
  }
```

**(d) `_NavItem`** — 增加 `collapsed` 参数(`const _NavItem({required this.destination, required this.selected, required this.collapsed, required this.onSelect})`,字段 `final bool collapsed`)。`build` 中把原 `Row` 内容按态切换:折叠时图标居中、不渲染文字,整体包 `Tooltip(message: label)`:

```dart
                    child: Tooltip(
                      message: collapsed ? label : '',
                      child: Container(
                        height: FundLensTokens.minTapTarget,
                        padding: const EdgeInsets.symmetric(
                          horizontal: FundLensTokens.space3,
                        ),
                        decoration: focused ? /* 原样保留 */ null : null,
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
                              Text(
                                label,
                                style: TextStyle(
                                  fontFamily: 'Noto Sans SC',
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: foreground,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
```

**(e) `_TopBar`** — 全文替换(移除 crumb/title 参数与渲染,改为全局操作条):

```dart
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.drawerMode,
    required this.collapsible,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onOpenDataStatus,
  });

  final bool drawerMode;
  final bool collapsible;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final VoidCallback onOpenDataStatus;

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
          if (collapsible)
            IconButton(
              key: const ValueKey('nav-collapse-toggle'),
              icon: Icon(
                collapsed ? Icons.chevron_right : Icons.chevron_left,
              ),
              tooltip: collapsed ? '展开导航' : '折叠导航',
              onPressed: onToggleCollapse,
            ),
          const Spacer(),
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
```

注意:`destinationCrumbs` 常量保留(Task 6–10 页面要用);`theme` 局部变量若无引用则删除。

- [ ] **Step 4: 运行 shell 测试确认全部通过**

Run: `cd apps/fundlens_windows && flutter test test/app/app_shell_test.dart`
Expected: PASS(含原有 8 个 + 新增 4 个用例;1100 与 700 宽度下 `page-*` 替身页可见、无 overflow 异常)

- [ ] **Step 5: 跑全量 Flutter 回归,确认除 golden 外不破坏其他测试**

Run: `cd apps/fundlens_windows && flutter test --exclude-tags golden`
Expected: PASS(golden 测试若在默认套件中失败属预期,Task 11 统一重新生成;其他失败必须修复后再继续)

- [ ] **Step 6: 提交**

```bash
git add apps/fundlens_windows/lib/app/app_shell.dart apps/fundlens_windows/test/app/app_shell_test.dart
git commit -m "feat(ui): AppShell 响应式三态侧栏 — 完整216/折叠64/抽屉;顶栏去标题化"
```

---

### Task 6: 总览页接入 PageScaffold + SummaryStrip 窄屏回退

**Files:**
- Modify: `apps/fundlens_windows/lib/features/overview/overview_page.dart:45-88`(`_OverviewContent`)
- Modify: `apps/fundlens_windows/lib/features/overview/summary_strip.dart:33-49`(Card 内 Row 布局)
- Test: `apps/fundlens_windows/test/features/overview/overview_page_test.dart`(新增;golden 不在本任务处理)

**Interfaces:**
- Consumes: `PageScaffold`/`PageWidthTier.standard`(Task 3)。
- Produces: 总览页容器内不再自带 `EdgeInsets.all(pagePadding)` 与页内大标题;标题由 PageScaffold 提供(`crumb: '组合'`, `title: '资产总览'`)。

- [ ] **Step 1: 写失败测试**

创建 `test/features/overview/overview_page_test.dart`(假仓库复用 golden 测试的 Fake):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/overview/overview_page.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

import 'asset_spectrum_test.dart'
    show FakeHoldingRepository, FakeSnapshotRepository;
import 'overview_golden_test.dart' show goldenHolding;

void main() {
  Future<void> pumpOverview(WidgetTester tester, {Size size = const Size(1600, 900)}) async {
    final container = ProviderContainer(overrides: [
      holdingRepositoryProvider.overrideWithValue(
        FakeHoldingRepository([
          goldenHolding(
            id: 'h-1',
            assetClass: AssetClass.equity,
            instrumentType: InstrumentType.offExchangeFund,
            productName: '稳健成长混合基金',
            currentValue: '52340.00',
          ),
        ]),
      ),
      snapshotRepositoryProvider.overrideWithValue(FakeSnapshotRepository()),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
    ]);
    addTearDown(container.dispose);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: FundLensTheme.light,
          home: const Scaffold(body: OverviewPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('总览页使用 standard 档 PageScaffold,标题只出现一次', (tester) async {
    await pumpOverview(tester);
    expect(find.byType(PageScaffold), findsOneWidget);
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.standard);
    expect(find.text('资产总览'), findsOneWidget);
    expect(find.text('组合'), findsOneWidget);
  });

  testWidgets('窄屏下 KPI 条换行堆叠且不溢出', (tester) async {
    await pumpOverview(tester, size: const Size(760, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('总资产'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/features/overview/overview_page_test.dart`
Expected: FAIL — 找不到 `PageScaffold`(且窄屏 KPI 条可能 overflow)。

- [ ] **Step 3: 改造总览页与 SummaryStrip**

**(a) `overview_page.dart`**:`OverviewPage.build` 的 return 改为:

```dart
    return PageScaffold(
      tier: PageWidthTier.standard,
      crumb: '组合',
      title: '资产总览',
      body: switch (state) {
        PortfolioLoading() => const Center(child: CircularProgressIndicator()),
        PortfolioDegraded(:final error) => Center(child: Text('数据暂时不可用：$error')),
        PortfolioEmpty() => Center(
          child: FilledButton.icon(
            key: const ValueKey('overview-add-first-asset'),
            onPressed: () => _addFirstAsset(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加第一项资产'),
          ),
        ),
        PortfolioReady() => const _OverviewContent(),
      },
    );
```

import 增加 `../../widgets/page_scaffold.dart`。

`_OverviewContent.build` 中:
- 删除 `Text('资产总览', style: theme.textTheme.titleLarge)` 与其下的 `SizedBox(height: FundLensTokens.titleGap)`;
- `SingleChildScrollView` 的 `padding` 改为 `const EdgeInsets.only(bottom: FundLensTokens.pagePadding)`(左右已由容器提供)。

**(b) `summary_strip.dart`**:Card 内的 `Row(children: [...])` 替换为 `LayoutBuilder` 回退——宽模式保持现有「分隔线 + Expanded 单元格」视觉,窄于 760 时改为两列 `Wrap`(不带分隔线):

```dart
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FundLensTokens.cardPadding,
          vertical: FundLensTokens.space4,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) const _CellDivider(),
                    cells[i],
                  ],
                ],
              );
            }
            final cellWidth = (constraints.maxWidth - FundLensTokens.space4) / 2;
            return Wrap(
              spacing: FundLensTokens.space4,
              runSpacing: FundLensTokens.space4,
              children: [
                for (final cell in cells)
                  SizedBox(width: cellWidth, child: cell),
              ],
            );
          },
        ),
      ),
    );
```

`_SummaryCell`/`_SignedSummaryCell` 内层原本就是 `Expanded(child: Column(...))`;为兼容 Wrap 场景,把两个 cell 的 `Expanded(` 改为 `SizedBox(width: double.infinity, child: …)`?——**不要**这样做(Expanded 在 Row 内仍需要)。正确做法:保留 cell 内部的 `Expanded` 不变,但宽模式 Row 直接放 cell;窄模式 `SizedBox(width: cellWidth, child: cell)` 中 `Expanded` 在 `SizedBox` 下无 Flex 父级会断言失败。因此:把 `_SummaryCell` 与 `_SignedSummaryCell` 的 `Expanded` 全部去掉,cell 直接返回 `Column(...)`;宽模式 Row 中改为 `Expanded(child: cells[i])`(即 `if (i > 0) const _CellDivider(), Expanded(child: cells[i])`)。窄模式 `SizedBox(width: cellWidth, child: cells[i])` 即可正常工作。

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/features/overview/`
Expected: 新增 2 个用例 PASS;`asset_spectrum_test` 等既有用例继续 PASS;**golden 用例失败属预期**(Task 11 重新生成)。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/overview/ apps/fundlens_windows/test/features/overview/overview_page_test.dart
git commit -m "feat(ui): 总览页接入 PageScaffold(standard 档)+ KPI 条窄屏换行"
```

---

### Task 7: 分析页接入 + CompositionTable 横向滚动 + 双栏栅格

**Files:**
- Modify: `apps/fundlens_windows/lib/features/analysis/analysis_page.dart:27-72`(build)
- Modify: `apps/fundlens_windows/lib/features/analysis/composition_table.dart:40-128`(Card 内容)
- Test: `apps/fundlens_windows/test/features/analysis/analysis_page_test.dart`(新增用例;若已有同名文件则追加)

**Interfaces:**
- Consumes: `PageScaffold`/`PageWidthTier.standard`(Task 3)、`GridRow`/`GridCol`(Task 4)。
- Produces: 分析页宽屏双栏(构成表 7 列 + 集中度 5 列),窄屏自动单列;构成表最小宽 520,不足时横向滚动。

- [ ] **Step 1: 写失败测试**

先看 `test/features/analysis/` 下已有测试文件的搭建方式(providers overrides 模式),保持同样风格追加:

```dart
  testWidgets('分析页使用 standard 档 PageScaffold,维度切换移入页头', (tester) async {
    await pumpAnalysis(tester); // 复用文件内已有 pump 辅助
    expect(find.byType(PageScaffold), findsOneWidget);
    expect(find.text('资产分析'), findsOneWidget);
    expect(find.text('资产类别'), findsOneWidget); // SegmentedButton 在 PageHeader actions
  });

  testWidgets('构成表在窄屏下横向滚动不压缩列', (tester) async {
    await pumpAnalysis(tester, size: const Size(760, 900));
    expect(tester.takeException(), isNull);
    // 构成表行不溢出:存在横向滚动视图
    expect(
      find.descendant(
        of: find.byType(CompositionTable),
        matching: find.byWidgetPredicate(
          (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsWidgets,
    );
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/features/analysis/`
Expected: FAIL — `PageScaffold` 未接入、无横向滚动视图。

- [ ] **Step 3: 改造**

**(a) `analysis_page.dart` build 替换为:**

```dart
    return PageScaffold(
      tier: PageWidthTier.standard,
      crumb: '组合',
      title: '资产分析',
      actions: [
        SegmentedButton<AnalysisDimension>(
          segments: const [
            ButtonSegment(value: AnalysisDimension.assetClass, label: Text('资产类别')),
            ButtonSegment(value: AnalysisDimension.instrumentType, label: Text('产品类型')),
            ButtonSegment(value: AnalysisDimension.source, label: Text('来源平台')),
          ],
          selected: {_dimension},
          onSelectionChanged: (selection) {
            setState(() => _dimension = selection.first);
          },
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: FundLensTokens.pagePadding),
        child: GridRow(
          children: [
            GridCol(span: 7, child: CompositionTable(rows: _rowsFor(summary))),
            GridCol(
              span: 5,
              child: ConcentrationPanel(
                summary: summary,
                quality: quality,
                holdings: holdings,
                thresholds: thresholds,
              ),
            ),
          ],
        ),
      ),
    );
```

import 增加 `../../widgets/page_scaffold.dart`、`../../widgets/grid_row.dart`;删除原标题 `Text`、原 `SegmentedButton` 行与相关 `SizedBox`。

**(b) `composition_table.dart`**:Card → Padding 之下的 `Column` 包一层横向滚动 + 最小宽:

```dart
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 520
                ? 520.0
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  // …原有 header Row + rows 循环内容原样保留…
                ),
              ),
            );
          },
        ),
      ),
    );
```

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/features/analysis/`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/analysis/ apps/fundlens_windows/test/features/analysis/
git commit -m "feat(ui): 分析页接入 PageScaffold + 构成表横向滚动 + 7/5 双栏栅格"
```

---

### Task 8: 持仓页接入(操作迁移到 PageHeader)

**Files:**
- Modify: `apps/fundlens_windows/lib/features/holdings/holdings_page.dart:23-95`(build)
- Test: `apps/fundlens_windows/test/features/holdings/`(在既有页面测试文件中追加用例)

**Interfaces:**
- Consumes: `PageScaffold`/`PageWidthTier.dense`(Task 3)。
- Produces: 搜索框(280 宽)、列预设 SegmentedButton、「添加持仓」按钮全部位于 PageHeader actions;`HoldingGrid` 占满正文;`HoldingActions` 与 `quoteRefreshServiceProvider` 不变。

- [ ] **Step 1: 追加失败测试**

在持仓既有测试的搭建基础上追加:

```dart
  testWidgets('持仓页使用 dense 档 PageScaffold,操作区在页头', (tester) async {
    await pumpHoldings(tester); // 复用文件内已有 pump 辅助
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.dense);
    expect(find.text('全部持仓'), findsOneWidget);
    expect(find.text('添加持仓'), findsOneWidget);
    expect(find.text('组合'), findsOneWidget);
  });

  testWidgets('125% 缩放等效宽度(约1092)下操作区不重叠', (tester) async {
    await pumpHoldings(tester, size: const Size(1092, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('添加持仓'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/features/holdings/`
Expected: FAIL — 无 `PageScaffold`。

- [ ] **Step 3: 改造 `holdings_page.dart` build**

```dart
    return PageScaffold(
      tier: PageWidthTier.dense,
      crumb: '组合',
      title: '全部持仓',
      actions: [
        SizedBox(
          width: 280,
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索名称或代码',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              ref.read(holdingFilterProvider.notifier).state =
                  filter.copyWith(query: value);
            },
          ),
        ),
        SegmentedButton<HoldingColumnPreset>(
          segments: const [
            ButtonSegment(value: HoldingColumnPreset.portfolio, label: Text('组合')),
            ButtonSegment(value: HoldingColumnPreset.trading, label: Text('交易')),
            ButtonSegment(value: HoldingColumnPreset.platform, label: Text('平台')),
          ],
          selected: {filter.preset},
          onSelectionChanged: (selection) {
            ref.read(holdingFilterProvider.notifier).state =
                filter.copyWith(preset: selection.first);
          },
        ),
        FilledButton.icon(
          onPressed: () => _addHolding(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('添加持仓'),
        ),
      ],
      body: HoldingGrid(holdings: holdings, preset: filter.preset),
    );
```

import 增加 `../../widgets/page_scaffold.dart`;删除原 `Padding`/`Column`/标题 `Row` 结构;`theme` 局部变量若无引用则删除。

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/features/holdings/`
Expected: 全部 PASS(`HoldingGrid` 自带冻结区 + 横向滚动,无需改动)。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/holdings/holdings_page.dart apps/fundlens_windows/test/features/holdings/
git commit -m "feat(ui): 持仓页接入 PageScaffold(dense 档)— 操作区迁入页头"
```

---

### Task 9: 快照页接入 + 对比选择器栅格

**Files:**
- Modify: `apps/fundlens_windows/lib/features/snapshots/snapshots_page.dart:18-79`(build)
- Modify: `apps/fundlens_windows/lib/features/snapshots/snapshot_compare_view.dart:54-88`(选择器 Row)
- Test: `apps/fundlens_windows/test/features/snapshots/`(追加用例)

**Interfaces:**
- Consumes: `PageScaffold`/`PageWidthTier.dense`(Task 3)、`GridRow`(Task 4)。
- Produces: 「新建快照」按钮在 PageHeader actions;快照列表 + `SnapshotCompareView` 在限宽容器内滚动;两个快照选择器 6/6 栅格,<720 堆叠。

- [ ] **Step 1: 追加失败测试**

```dart
  testWidgets('快照页使用 dense 档 PageScaffold,新建快照在页头', (tester) async {
    await pumpSnapshots(tester); // 复用文件内已有 pump 辅助
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.dense);
    expect(find.text('历史快照'), findsOneWidget);
    expect(find.text('新建快照'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/features/snapshots/`
Expected: FAIL — 无 `PageScaffold`。

- [ ] **Step 3: 改造**

**(a) `snapshots_page.dart`**:去掉外层 `Scaffold`,`data:` 分支改为:

```dart
        data: (list) {
          final sorted = List<PortfolioSnapshot>.of(list)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return PageScaffold(
            tier: PageWidthTier.dense,
            crumb: '组合',
            title: '历史快照',
            actions: [
              FilledButton(
                onPressed: () => _createSnapshot(context, ref),
                child: const Text('新建快照'),
              ),
            ],
            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (sorted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: FundLensTokens.space4,
                    ),
                    child: Text('还没有快照'),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final snapshot in sorted)
                          ListTile(
                            title: Text(snapshot.label),
                            subtitle: Text(_formatDate(snapshot.createdAt)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: '删除快照',
                              onPressed: () =>
                                  _confirmDelete(context, ref, snapshot),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: FundLensTokens.cardGap),
                SnapshotCompareView(snapshots: sorted),
              ],
            ),
          );
        },
```

注意:loading/error 分支同样需要页头以保持主体位置稳定——把整个 `snapshots.when(...)` 包进 PageScaffold(无 actions 变体),loading/error 分支作为 body:

```dart
    return PageScaffold(
      tier: PageWidthTier.dense,
      crumb: '组合',
      title: '历史快照',
      actions: [
        FilledButton(
          onPressed: () => _createSnapshot(context, ref),
          child: const Text('新建快照'),
        ),
      ],
      body: snapshots.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('快照加载失败：$error')),
        data: (list) { /* 上面的 ListView */ },
      ),
    );
```

**(b) `snapshot_compare_view.dart`**:选择器 `Row` 替换为:

```dart
        GridRow(
          collapseBelow: 720,
          children: [
            GridCol(
              span: 6,
              child: _selector(
                context,
                label: '较早快照',
                value: before.id,
                snapshots: sorted,
                onChanged: (id) => setState(() => _beforeId = id),
              ),
            ),
            GridCol(
              span: 6,
              child: _selector(
                context,
                label: '较晚快照',
                value: after.id,
                snapshots: sorted,
                onChanged: (id) => setState(() => _afterId = id),
              ),
            ),
          ],
        ),
```

import 增加 `../../widgets/grid_row.dart`;删除原 `SizedBox(width: 16)` 分隔。

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/features/snapshots/`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/snapshots/ apps/fundlens_windows/test/features/snapshots/
git commit -m "feat(ui): 快照页接入 PageScaffold(dense 档)+ 对比选择器 6/6 栅格"
```

---

### Task 10: 设置页 + 导入页接入(编辑态窄屏堆叠)

**Files:**
- Modify: `apps/fundlens_windows/lib/features/settings/settings_page.dart`(全文)
- Modify: `apps/fundlens_windows/lib/features/import_review/import_review_page.dart:31-67`(build)与 `:159-220`(`_EditingBody.build`)
- Test: `apps/fundlens_windows/test/features/settings/`、`apps/fundlens_windows/test/features/import_review/`(追加用例)

**Interfaces:**
- Consumes: `PageScaffold`/`PageWidthTier.form`(Task 3)、`FundLensTokens.gridCollapseBelow`。
- Produces: 两页 crumb 均为 `'数据'`;导入编辑态容器宽 <960 时,截图裁剪区(高 320)与编辑列(高 640)纵向堆叠于滚动视图内。

- [ ] **Step 1: 追加失败测试**

```dart
  testWidgets('设置页使用 form 档 PageScaffold', (tester) async {
    await pumpSettings(tester); // 复用文件内已有 pump 辅助
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.form);
    expect(find.text('设置与备份'), findsOneWidget);
    expect(find.text('数据'), findsWidgets); // 面包屑
  });

  testWidgets('导入页使用 form 档 PageScaffold', (tester) async {
    await pumpImportReview(tester); // 复用文件内已有 pump 辅助
    final scaffold = tester.widget<PageScaffold>(find.byType(PageScaffold));
    expect(scaffold.tier, PageWidthTier.form);
    expect(find.text('导入与识别'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `cd apps/fundlens_windows && flutter test test/features/settings/ test/features/import_review/`
Expected: FAIL — 无 `PageScaffold`。

- [ ] **Step 3: 改造**

**(a) `settings_page.dart` 全文替换 build:**

```dart
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
```

import 增加 `../../widgets/page_scaffold.dart`;删除 `Scaffold` 与页内标题(原 `SizedBox(height: 20)` 一并删除)。

**(b) `import_review_page.dart`**:`_ImportReviewPageState.build` 末尾的 `return Scaffold(body: body);` 改为(删除「页面标题由 AppShell 顶栏统一提供」的过时注释):

```dart
    return PageScaffold(
      tier: PageWidthTier.form,
      crumb: '数据',
      title: '导入与识别',
      body: body,
    );
```

**(c) `_EditingBody.build`** — 抽出编辑列并加窄屏堆叠:

```dart
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<ImportMode>(
            segments: const [
              ButtonSegment(value: ImportMode.partial, label: Text('部分持仓')),
              ButtonSegment(value: ImportMode.full, label: Text('全量持仓')),
            ],
            selected: {controller.mode},
            onSelectionChanged: (selection) =>
                controller.setMode(selection.first),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= FundLensTokens.gridCollapseBelow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: ScreenshotCropView(controller: controller)),
                    Expanded(flex: 2, child: _editorColumn()),
                  ],
                );
              }
              // 窄屏:裁剪区与编辑列纵向堆叠,统一滚动
              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 320,
                      child: ScreenshotCropView(controller: controller),
                    ),
                    const SizedBox(height: FundLensTokens.space3),
                    SizedBox(height: 640, child: _editorColumn()),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: controller.discard, child: const Text('取消')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: controller.canCommit ? () => _confirmCommit(context) : null,
                child: const Text('确认写入'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editorColumn() {
    return Column(
      children: [
        Expanded(flex: 3, child: OcrFieldEditor(controller: controller)),
        Expanded(flex: 2, child: DataIssueList(controller: controller)),
        ImportDiffPanel(controller: controller),
      ],
    );
  }
```

- [ ] **Step 4: 运行确认通过**

Run: `cd apps/fundlens_windows && flutter test test/features/settings/ test/features/import_review/`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add apps/fundlens_windows/lib/features/settings/settings_page.dart apps/fundlens_windows/lib/features/import_review/import_review_page.dart apps/fundlens_windows/test/features/
git commit -m "feat(ui): 设置/导入页接入 PageScaffold(form 档)+ 导入编辑态窄屏堆叠"
```

---

### Task 11: golden 重新生成 + 全量质量门禁

**Files:**
- Modify(重新生成): `apps/fundlens_windows/test/goldens/overview_1440x900.png`

**Interfaces:**
- Consumes: Task 1–10 全部。

- [ ] **Step 1: 重新生成 golden**

Run: `cd apps/fundlens_windows && flutter test test/features/overview/overview_golden_test.dart --update-goldens`
Expected: PASS,`test/goldens/overview_1440x900.png` 更新。

- [ ] **Step 2: 人工核对新 golden 图**

用图片查看器打开 `test/goldens/overview_1440x900.png`,确认:侧栏 216、顶栏无页面标题、页头「组合 / 资产总览」层级正确、正文限宽居中、无溢出条。异常则回到对应任务修复后重新生成。

- [ ] **Step 3: 全量门禁**

```bash
cd apps/fundlens_windows && flutter test
cd apps/fundlens_windows && flutter analyze
cd ../../.. && dart test packages/fundlens_core
python -m pytest engine/tests -q
```

(以仓库根目录为基准的实际命令:`dart test packages/fundlens_core` 在根目录执行;pytest 同理。)
Expected: 全部 PASS,analyze 无 error/warning。

- [ ] **Step 4: 提交**

```bash
git add apps/fundlens_windows/test/goldens/overview_1440x900.png
git commit -m "test(ui): 重新生成 overview 1440x900 golden(统一容器布局)"
```

---

### Task 12: 合并 master 并打包 Windows exe

**Files:** 无新增(工作流任务,遵循用户既定约定:任务完成即合并 master 并产出 exe)。

- [ ] **Step 1: 确认工作树干净、全部提交完成**

Run: `git status`
Expected: working tree clean。

- [ ] **Step 2: 切回主仓库并合并**

```bash
cd "D:/cc project/FundLens"
git checkout master 2>/dev/null || git checkout main
git merge --no-ff feat/phase-6-design-system -m "merge: 全局页面布局优化(统一容器/12列栅格/PageHeader/侧栏三态)"
```

Expected: 合并无冲突;若有冲突,停下向用户报告,不擅自取舍。

- [ ] **Step 3: 打包 exe**

```bash
cd "D:/cc project/FundLens/apps/fundlens_windows"
flutter build windows --release
```

Expected: `build/windows/x64/runner/Release/fundlens_windows.exe` 生成成功。

- [ ] **Step 4: 冒烟验证**

启动生成的 exe,人工确认:1920 宽屏无大面积留白;1366 宽度无水平滚动;折叠按钮与抽屉工作正常;六页切换主体位置稳定。

- [ ] **Step 5: 汇报合并与打包结果**（合并提交哈希、exe 路径、冒烟结论)。

---

## Self-Review 记录

- Spec §3–§7 各项均有对应任务:容器三档→Task 3/6–10;PageHeader→Task 2;栅格→Task 4/6/7/9;侧栏三态→Task 5;表格横向滚动→Task 7(构成表)+ 持仓表格现状已满足(Task 8 验证);缩放兼容→Task 5/6/8 窄宽用例;golden→Task 11;合并打包→Task 12。
- 类型一致性:`PageWidthTier`、`PageScaffold`、`PageHeader`、`GridRow/GridCol`、`FundLensTokens` 常量名在全部任务间一致;`_NavigationRegion`/`_NavItem`/`_BrandBlock` 新增 `collapsed` 参数在 Task 5 内自洽。
- 已知留白:Task 7/8/9/10 的测试复用「文件内已有 pump 辅助」,实施时先读对应测试文件再照其风格追加,不新建重复搭建代码。
