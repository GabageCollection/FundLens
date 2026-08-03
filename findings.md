# findings.md — 探索发现

## 关键资产（复用清单）

- 集成测试模板：`apps/fundlens_windows/integration_test/windows_workflow_test.dart`
  - 模式：ProviderScope overrides + `WorkflowHoldingRepository`（内存、watch 流）+ `WorkflowSnapshotRepository` + `FakeDataEngineClient`（来自 `test/features/import_review/import_review_harness.dart`）
  - 六页导航标签：资产总览/资产分析/全部持仓/历史快照/导入与识别/设置与备份
- `FakeImportFilePicker` 支持 `csvFile` 注入（`pickTabularFile() => tabularFile ?? csvFile`）→ 可绕开原生文件对话框
- `FakeScreenshotTempStore`、`InMemoryImportDraftStore` 同样在 harness 中
- 备份服务：`backupServiceProvider`、`databaseRestoreServiceProvider`（可服务层直接驱动）
- 示例 CSV：`docs/import-template/fundlens-import-template.csv`（assets 下同名副本）
- 已有产物：`apps/fundlens_windows/build/windows/x64/runner/Release/FundLens.exe`、`dist/engine/fundlens_engine/fundlens_engine.exe`（43MB，旧版本构建可复用，跳过 PyInstaller）

## 门禁命令

```bash
dart test packages/fundlens_core
python tools/with_sqlite3mc_server.py 8765 "flutter test"   # 在 apps/fundlens_windows 内
flutter analyze apps/fundlens_windows
engine/.venv/Scripts/python.exe -m pytest engine/tests -m "not live" -q
engine/.venv/Scripts/python.exe -m ruff check engine
engine/.venv/Scripts/python.exe -m mypy engine/src
```

- Flutter 未用 FVM，SDK 路径 `D:\flutter\bin\flutter.bat`；Dart SDK `^3.12.2`
- Python 虚拟环境：`engine/.venv`（开发）；`engine/.venv-build`（构建）
- 无 CI、无 flutter_driver、golden 仅总览一张且 png 未入库 → 截图需外部手段

## 功能映射（15 步流程 → 文件）

| 步骤 | 关键文件 |
|---|---|
| CSV 导入向导 | `features/import_review/import_review_page.dart` + `_controller.dart` + `_mapping_panel.dart` + `_check_panel.dart` + `_result_view.dart` |
| 重复/异常 | `importing/import_planner.dart`（merge/overwrite/keepBoth/skip 四种决议）、`importing/import_models.dart`、`data_issue_list.dart` |
| 确认/撤销导入 | `importing/import_commit_service.dart` |
| 资产总览 | `features/overview/*`、`application/portfolio_providers.dart` |
| 分析三维度 | `features/analysis/analysis_chart.dart`（`AnalysisDimension.assetClass/instrumentType/source`） |
| 搜索/筛选/排序 | `features/holdings/holding_filters.dart`（`holdingFilterProvider`、`visibleHoldingsProvider`） |
| 编辑持仓 | `features/holdings/holding_editor_dialog.dart` |
| 快照创建/比较 | `features/snapshots/snapshots_page.dart`、`snapshot_compare_view.dart`、core `snapshot_diff_service.dart` |
| 行情刷新 | `market/quote_refresh_service.dart`、`features/holdings/holding_actions.dart` |
| 备份/恢复 | `features/settings/backup_section.dart`、`backup/backup_service.dart`、`backup/database_restore_service.dart` |

## 改造系列提交（待验证精确基线）

- `2aa976b` 资产总览页重设计（候选基线：其父提交）
- `002ceab` merge 资产分析页重构
- `b5bb0b9` merge 全部持仓页改造
- `24949ce` merge 导入与识别页改造
- `e47f7ae` 设置页重组完成；`9ed110f` a11y 交互原语；`6651f64` HEAD（win32 BOM 修复）

## 测试覆盖空白点（背景）

- core 层仅 3 个测试文件；无 CSV 端到端集成测试；备份恢复无 UI 集成测试；golden 单一

## 阶段 4 冒烟方案

- `docs/regression/scripts/smoke.ps1`：启动 Release exe → 验证主进程/窗口（≥1280×720）/fundlens_engine 子进程/5 秒稳定性。注意 Windows PowerShell 5.1 按 GBK 读无 BOM UTF-8 → 脚本必须纯 ASCII。
- `docs/regression/scripts/engine_quote_smoke.py`：直接驱动 dist 引擎（stdin/stdout 逐行 JSON-RPC，`schema_version:1`，方法 `health.check`/`market.fetch_quotes`，kind 用 `fund`/`etf`），验证真实网络行情或降级。

## 阶段 5 截图方案（决策）

- 基线 b7f6bf2 检出到 `.claude/worktrees/baseline-screenshots`（或临时 worktree），旧版本构建复用 `dist/engine` 与 Release 布局（`flutter build windows --release`）。
- 演示数据：两版本导入同一脱敏合成 CSV（`docs/import-template/fundlens-import-template.csv` 脱敏行）。
- 交互：AppShell 支持 Ctrl+1..6 切页快捷键；导入第一步需原生文件对话框/拖拽 → 由用户辅助拖拽一次，或 PowerShell SendKeys 文件路径+Enter（对话框时序脆弱，优先拖拽）。
- 截图：`docs/regression/scripts/screenshot_window.ps1`（PrintWindow + 兜底前置截屏），输出 `docs/regression/screenshots/before|after/<page>.png`。

## 重复决议交互要点（集成测试踩坑）

- 重复检测条件（`import_review_controller.dart:1144`）：同名 **且 `c.sourcePlatform != holding.sourcePlatform`**（跨平台才算疑似重复）。手动添加默认 `manual`，CSV 的 `source_platform=支付宝` → `alipay`，可匹配。
- `_ResolutionSection`（`import_check_panel.dart:292`）仅在 `plan.updates.isNotEmpty || duplicateCount > 0` 时渲染；行过滤条件 `duplicateIndexes.contains(i) || updatedNames.contains(name)`。
- 每个决议行是 `DropdownButton<DuplicateResolution>`（key `resolution-<行索引>`），默认 `overwrite`。**收起时选项文本在 Offstage**，`find.text('合并金额')` 默认找不到 → 须先 `tap` 展开菜单再 `tap(find.text('合并金额').last)`。
- `_SummaryGrid` 的「疑似重复/异常金额」label **始终渲染**（warn 才高亮），`find.text` 断言只能证明 summary 存在，不能证明检测到问题；须用 `resolution-N` key 或按钮禁用态断言实际检测。
- `back()` 语义（`_controller.dart:1552`）：ImportCheck → 返回字段映射（**保留 resolutions**）→ 再返回来源选择（`_resetReview()` **清空 resolutions**）。重新导入时决议回到默认 overwrite → 测试须在最终确认前重新选择决议。
