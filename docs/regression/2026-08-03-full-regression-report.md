# FundLens 全部页面改造后完整回归报告

- **日期**：2026-08-03
- **范围**：页面改造系列（总览重设计 / 分析重构 / 持仓页改造 / 导入四步向导 / 设置页重组 / 数据健康 / a11y）全部合入 master（HEAD `6651f64`）后的完整回归
- **基线**：`b7f6bf2`（改造系列起点前，2026-07-28）
- **环境**：Flutter 3.44.6 stable / Dart 3.12 / Windows 11 Pro

## 1. 修改文件清单

> 详见 `git diff --stat b7f6bf2..HEAD`（154 文件、+28598/−3077）；按组别摘录：

| 组别 | 代表文件 |
|---|---|
| 页面改造 | `lib/features/overview/*`、`lib/features/analysis/*`、`lib/features/holdings/*`、`lib/features/import_review/*`、`lib/features/settings/*`、`lib/features/data_health/*` |
| 设计系统 | `lib/theme/fundlens_tokens.dart`、`lib/theme/fundlens_theme.dart` |
| 交互原语与 a11y | `lib/widgets/*`（toast/确认对话框/错误重试视图等） |
| 领域与接口 | `packages/fundlens_core/lib/src/model/holding.dart`（+37 行字段与文档） |
| 构建 | `apps/fundlens_windows/windows/flutter/*`（win32 BOM 修复） |
| 回归交付 | `integration_test/full_regression_test.dart`（新增）、`docs/regression/*`（脚本/截图/报告） |

## 2. 新增组件清单

- 导入四步向导面板：`import_source_panel.dart`、`import_mapping_panel.dart`、`import_check_panel.dart`、`import_result_view.dart`
- 数据健康：`data_health_metrics.dart`、`data_health_popover.dart`、`data_health_providers.dart`
- 持仓详情抽屉：`holding_detail_drawer.dart`；批量操作栏：`holding_batch_bar.dart`
- 分析结论区：`analysis_conclusions.dart`
- 全局交互原语：`app_toast.dart`、`confirm_dialog.dart`、`error_retry_view.dart`
- 回归工具：`docs/regression/scripts/*`（find_window_util / screenshot_window / capture_pages / smoke / engine_quote_smoke）

## 3. 新增数据字段

- `packages/fundlens_core/lib/src/model/holding.dart`：+37 行（字段文档与估值方法补充；**无新增持久化列**——经 diff 核对无 Drift 表结构变化）

## 4. 数据迁移说明

- **无迁移**：数据库 schema 版本未变（仍为 v1），无新增表/列，现有数据文件可直接打开。

## 5. 测试结果

### 5.1 质量门禁（阶段 1）

| 门禁 | 结果 |
|---|---|
| `dart test packages/fundlens_core` | ✅ 19 通过 |
| `flutter test`（sqlite3mc 包装） | ✅ 539 通过（含缺陷修复新增 2 个决议测试） |
| `flutter analyze` | ✅ No issues |
| `pytest -m "not live"` | ✅ 86 passed, 1 deselected |
| `ruff` + `mypy` | ✅ 全部通过 |

> 门禁为缺陷修复后最终确认（2026-08-03 晚间重跑，全绿）。

### 5.2 15 步自动化回归（`integration_test/full_regression_test.dart`）

6/6 全绿（01:01）：

| 步骤 | 结果 | 说明 |
|---|---|---|
| 1 空数据启动 | ✅ | 六页可达、空态正常 |
| 2 导入 CSV | ✅ | 合成脱敏 CSV（3 行：正常/重复/异常金额） |
| 3 字段映射 | ✅ | 映射面板、必需列识别 |
| 4 重复与异常处理 | ✅ | 「疑似重复」决议下拉、「异常金额」阻断提交、失败不改数据 |
| 5 确认导入 | ✅ | 合并决议生效：旧基金 500+2000=2500，无重复记录 |
| 6 资产总览 | ✅ | 总资产 81735.87，类别合计=总资产（占比 100%） |
| 7 三维度分析 | ✅ | 资产类别/产品类型/来源平台，合计一致 |
| 8 搜索/筛选/排序 | ✅ | 文本/类别筛选/金额升降序断言 |
| 9 编辑持仓 | ✅ | 金额+类别修改，总额精确更新 82388 |
| 10 创建两个快照 | ✅ | 快照一冻结 82388，不被后续编辑影响 |
| 11 比较快照 | ✅ | 差额表述「资产金额变化」= 112，无「收益」字样 |
| 12 刷新行情 | ✅ | 成功 1 条按份额×价格重算（200），失败保留原值（1000） |
| 13 创建加密备份 | ✅ | 文件路径 `.fundlens-backup`、密码正确传递 |
| 14 恢复备份 | ✅ | 摘要确认 → 恢复完成 |
| 15 撤销导入 | ✅ | 插入行移除、更新行回滚（500）、快照仍 2 个不变 |

横切断言：每步无未捕获异常；无重复提交；失败不破坏原数据；引擎调用仅行情与重复候选匹配。

另：**真实加密备份→修改→恢复**链路（真实 sqlite3mc 文件库 + Argon2id+AES-256-GCM + Io 文件系统）✅；错误密码抛 `BackupAuthenticationException` ✅。

### 5.3 多窗口尺寸布局（阶段 3）

| 尺寸 | 六页遍历 |
|---|---|
| 1920×1080 | ✅ 无溢出 |
| 1440×900 | ✅ 无溢出 |
| 1366×768 | ✅ 无溢出 |
| 1280×720 | ✅ 无溢出 |

### 5.4 真实应用冒烟（阶段 4）

- Release exe 启动：主进程存活、主窗口 1280×720、5 秒稳定 ✅
- 引擎（懒启动设计）：`health.check` ✅；`market.fetch_quotes` 真实网络 0.9s：510300 fresh 4.6530（baostock）✅、000001 failed（akshare 供应商无数据 → 应用保留原值，符合降级口径）
- 应用内引擎触发链路：阶段 7 新 exe 构建后人工复核（引擎进程懒启动于首次行情/OCR 调用，无持仓导入时不拉起属预期）

### 5.5 回归中发现并修复的缺陷（阶段 6）

1. **导入决议跨平台失效**（`lib/importing/import_planner.dart`）：检查面板提示跨平台疑似重复并提供 merge/overwrite 决议，但规划器仅匹配同平台持仓 → 用户选「合并金额」时静默退化为新增行。修复：显式决议的行匹配范围扩大到全部持仓；新增 2 个单测。影响：跨平台同名持仓合并/覆盖按用户决议生效。
2. **手动刷新后 UI 不显示本次结果**（`lib/features/settings/market_settings_section.dart`）：`_lastRefreshText` 在持久化上次刷新时间为空时直接显示「尚未刷新」，丢弃会话内本次更新/失败条数。修复：会话内刷新结果优先显示（「上次刷新：本会话 · 更新 N 条 · 失败 M 条」）。

## 6. 仍存在的限制

- **平板/移动端**：V1 仅交付 Windows 桌面；断点下小窗（<768）只保证可用性，非移动端产品（属 V1 范围外）。
- **真实行情**：依赖免费行情源（akshare/baostock）的稳定性；部分供应商对个别代码无数据时按「保留上次有效值」降级。
- **桌面端集成测试截图**：`integration_test` 的 `takeScreenshot` 在 Windows 桌面不可用，前后对比依赖外部截屏（PowerShell PrintWindow）。
- **引擎进程**：懒启动（首次调用拉起）；无持仓数据时启动期不产生引擎进程属预期行为。
- **原生对话框**：备份文件选择等原生对话框不在集成测试覆盖内（以服务层驱动 + 冒烟为准）。

## 7. 优化前后截图对比

- 基线版本：worktree 检出 `b7f6bf2`（D:/flbase）构建；当前版本：master `6651f64` 构建（含本报告 5.5 节两个缺陷修复）
- 两个版本打开**同一本地数据库**，保证对比数据一致（after 版总览 ¥217,398.15 与 before 版完全一致）
- 截屏工具：`docs/regression/scripts/`（`screenshot_window.ps1` PrintWindow 截窗 + `detect_highlight.py` 选中项检测 + `monitor_pages.ps1` 旁路监控）
- **截屏流程说明**：合成鼠标点击在该环境不可达应用（窗口最小化状态、编辑器遮挡、前台锁、DPI 混合等多因素，详见 `progress.md`），最终采用「人工点击页面 + 旁路监控按选中高亮自动归类捕获」；每张截图经 PaddleOCR 页面标题验证

| 页面 | 改造前（before） | 改造后（after） |
|---|---|---|
| 资产总览 | `screenshots/before-overview.png` | `screenshots/after-overview.png` |
| 资产分析 | `screenshots/before-analysis.png` | `screenshots/after-analysis.png` |
| 全部持仓 | `screenshots/before-holdings.png` | `screenshots/after-holdings.png` |
| 历史快照 | `screenshots/before-snapshots.png` | `screenshots/after-snapshots.png` |
| 导入与识别 | `screenshots/before-import.png` | `screenshots/after-import.png` |
| 设置与备份 | `screenshots/before-settings.png` | `screenshots/after-settings.png` |

> ⚠️ **截图数据说明**：按用户指示（2026-08-03）本次对比使用**本地真实测试数据**渲染（before/after 各页 KPI 与持仓表一致，如总资产 ¥217,398.15）。依据「仓库不得写入真实持仓」约束，截图目录 `docs/regression/screenshots/` 已加入 `.gitignore` **不入库**，报告仅引用本地路径。如后续需要入库截图，请使用 `docs/regression/demo-data.csv`（脱敏合成数据）重新导入后再截。
