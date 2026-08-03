# FundLens 全部页面改造后完整回归检查

> 会话开始：2026-08-03 ｜ 模型：deepseek-v4-flash（effort: max）

## 目标

页面改造系列（总览重设计/分析重构/持仓页改造/导入四步向导/设置页重组/数据健康/a11y）全部合入 master（HEAD `6651f64`）后，完成一次完整回归：15 步端到端流程 + 9 项验证要求 + 质量门禁全绿 + 输出报告（含前后截图对比）。

## 已确认决策

1. **设备范围**：按窗口尺寸验证（1920×1080 / 1440×900 / 1366×768 / 1280×720）；平板/移动端记入「仍存在的限制」（V1 范围外）。
2. **截图基线**：页面改造系列起点前提交（待 git log 精确定位）。
3. **缺陷处理**：发现即修复（TDD），完成后合并 master 并重新打包 exe。

## 阶段

- [ ] 阶段 0：规划文件与基线定位
- [ ] 阶段 1：质量门禁全量执行（dart test / flutter test / flutter analyze / pytest / ruff+mypy）
- [x] 阶段 2：新增 15 步自动化回归集成测试 `integration_test/full_regression_test.dart`（6/6 全绿）
- [x] 阶段 3：多窗口尺寸布局验证（四尺寸 × 六页面，4/4 无溢出）
- [ ] 阶段 4：真实应用冒烟（Release exe + 真实引擎）
- [ ] 阶段 5：优化前后截图对比（worktree 检出基线 + 外部截屏）
- [ ] 阶段 6：缺陷修复（如有）
- [ ] 阶段 7：报告 `docs/regression/2026-08-03-full-regression-report.md`、提交 master、重新打包 exe

## 遇到的错误

| 错误 | 尝试次数 | 解决方案 |
|------|---------|---------|
| dart.bat test packages/fundlens_core 报 No pubspec.yaml | 2 | dart test 须在包目录内运行：cd packages/fundlens_core |
| with_sqlite3mc_server.py 内嵌 flutter 找不到 | 1 | PATH 前缀 /d/flutter/bin 后重跑通过 |
| integration_test 编译错误（quoteRefreshServiceProvider 未定义等 4 项） | 2 | 补 holding_actions/backup_cipher import；scope 字段类型改实例；删 unused import |
| 第 4 次运行 ensureVisible('合并金额') 抛 No element | 1 | DropdownButton 收起时选项 Offstage 找不到；改按 `resolution-1` key 展开菜单再选；且 back() 会清空 resolutions，V2 重导须重新选「合并金额」 |
