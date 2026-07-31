# FundLens 全局页面布局优化 — 设计文档

日期:2026-07-30
分支:`feat/phase-6-design-system`
状态:已获用户确认(2026-07-30)

## 1. 背景与问题

当前 `AppShell` 为固定 232px 侧边栏 + 全宽顶栏 + `IndexedStack` 六页面,每个页面用 `pagePadding=24` 全宽铺开。在 1920px 宽屏下内容整体拉伸,出现大面积无效留白;顶栏中"面包屑 + 同尺寸标题"重复表达层级;侧边栏无折叠能力;表格在小窗/高缩放下被强行压缩。

## 2. 目标(验收标准)

- 1920px 宽屏下不再出现明显大块无效空白;
- 1366px 宽度下主要功能无需水平滚动;
- 页面标题、卡片和表格左右边界保持一致;
- 所有页面切换时主体位置稳定,不产生明显跳动;
- 125% / 150% 系统缩放下无遮挡、截断或按钮重叠。

## 3. 方案选型

采用 **方案 A:Shell 级统一容器 + `PageScaffold`/`PageHeader` 组件**。

- 方案 B(每页自行 `ConstrainedBox` 限宽):容器、页头、居中逻辑散落六处,一致性靠自觉,排除。
- 方案 C(引入第三方栅格/响应式包):违反"依赖版本固定、未经评审不升级"约束,排除。

## 4. 布局层新增组件(`apps/fundlens_windows/lib/widgets/`)

### 4.1 PageScaffold

```dart
PageScaffold({required PageWidthTier tier, required PageHeader header, required Widget body})
```

- 内容区 `LayoutBuilder` → `Align(alignment: Alignment.topCenter)` + `ConstrainedBox(maxWidth: tier.maxWidth)`。
- 宽度档枚举 `PageWidthTier`:`standard = 1440`、`dense = 1680`、`form = 1120`(取 1040–1200 中间值)。
- 水平 padding 24(`FundLensTokens.pagePadding`),垂直 padding 24。
- 页面归类(用户已确认):
  - standard:资产总览、资产分析
  - dense:全部持仓、历史快照(含对比视图)
  - form:设置与备份、导入与识别

### 4.2 PageHeader

```dart
PageHeader({required String crumb, required String title, List<Widget> actions = const []})
```

- 面包屑 12px `Noto Sans SC` `FundLensTokens.muted` 在上;标题 24/32 `Noto Serif SC` w600 在下;右侧 actions 槽。
- 与正文同一容器,标题/卡片/表格左右边界天然对齐。
- 替代现顶栏中"面包屑 + 同尺寸标题"的重复表达。

### 4.3 GridRow / GridCol(12 列响应式栅格)

- `GridRow({gutter = 16, children: List<GridCol>})`,`GridCol({span 1–12, child})`。
- 基于 `LayoutBuilder` 计算列宽:`(width - 11 * gutter) / 12 * span + (span - 1) * gutter`。
- 容器宽度 < 960 时自动降为单列纵向堆叠。
- 替换现有 `Expanded flex` 分栏场景:总览 KPI 条、资产分析双栏、快照对比双栏、导入页双栏。

## 5. AppShell 响应式改造

### 5.1 侧边栏三态(断点为逻辑像素,天然兼容 125%/150% 系统缩放)

| 窗口逻辑宽度 | 形态 |
|---|---|
| ≥1280 | 完整侧栏,宽度 216(由 232 调整) |
| 768–1279 | 完整 / 64px 图标栏,顶栏左侧折叠按钮手动切换;折叠态 hover 显示 tooltip 标签;会话内记忆状态 |
| <768 | `Scaffold.drawer` 抽屉 + 顶栏汉堡按钮 |

注:最小窗口 1280×720 物理像素在 150% 缩放下为 853 逻辑像素,抽屉分支真实可达。

### 5.2 顶栏

- 保持全宽,仅放全局元素:折叠/汉堡按钮、数据状态按钮、用户头像。
- **页面标题与面包屑均从顶栏移除**,统一下沉到各页 `PageHeader`(面包屑 12px 小字在上、标题在下形成层级),消除顶栏与页内的重复表达。
- 右侧按钮组采用收缩策略(Wrap / 必要时省略头像文字),125%/150% 缩放下不重叠。

### 5.3 页面切换

- 保留 `IndexedStack`,各页搜索/筛选状态不丢失。
- 同档页面主体位置完全稳定;跨档切换时容器居中,位移对称且幅度小。

## 6. 表格与小屏策略

- `HoldingGrid`、`CompositionTable`、快照对比表:外层包横向 `SingleChildScrollView` + 最小列宽约束,小屏横向滚动而非压缩列;表头与数据行共用同一滚动边界。
- 12 列栅格在容器 < 960 时降单列,避免少量内容独占超宽区域。

## 7. 测试与质量门禁

- 新增 widget 测试:
  - 三档容器最大宽度断言(standard/dense/form);
  - 三个断点下侧栏形态(完整 / 图标栏 / 抽屉);
  - `PageHeader` 层级(面包屑小字 + 大标题,非重复同级文字);
  - 折叠状态在会话内保持。
- overview 1440×900 golden 因布局变化失效,重新生成。
- 门禁全部通过:
  - `dart test packages/fundlens_core`
  - `flutter test apps/fundlens_windows`
  - `flutter analyze apps/fundlens_windows`
  - `python -m pytest engine/tests -q`(本次不改 Python,仍跑回归)
- 完成后按既定工作流合并 master 并打包 Windows exe。

## 8. 范围外(YAGNI)

- 不做主题/暗色模式、不做移动端适配(断点仅为窗口缩放与高 DPI 服务)。
- 不引入新依赖。
- 不改 Python 引擎与领域层任何代码。
