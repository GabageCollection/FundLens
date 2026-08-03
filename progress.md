# progress.md — 会话日志

## 2026-08-03 会话

### 阶段 0：基线定位 ✅
- 基线提交：**b7f6bf2**（`89d5c97^`，阶段五暖墨换肤之前的父提交 = 全部页面改造起点前）
- 改造系列 merge：89d5c97(暖墨) → e9e2e06(设计系统) → 700151c(布局) → 2aa976b(总览) → 002ceab(分析) → b5bb0b9(持仓) → 24949ce(导入) → 后续数据健康/设置/a11y
- HEAD：6651f64；工具链：flutter/dart 在 D:\flutter\bin，python venv 在 engine/.venv

### 阶段 1：质量门禁 ✅ 全部通过
| 门禁 | 结果 |
|---|---|
| dart test packages/fundlens_core | ✅ 19 个测试全部通过 |
| flutter test（sqlite3mc 包装） | ✅ 537 个测试全部通过（00:30） |
| flutter analyze | ✅ No issues found（67.1s） |
| pytest（-m "not live"） | ✅ 86 passed, 1 deselected |
| ruff + mypy | ✅ ruff All checks passed；mypy 20 files no issues |

> 注：dart test 必须在包目录内运行（`cd packages/fundlens_core`）；with_sqlite3mc_server.py 内嵌的 flutter 命令需要 PATH 含 D:\flutter\bin。
> 初跑 flutter test 因 PATH 缺 flutter 失败 → 加 PATH 前缀后通过（记入错误表）。

### 阶段 2 + 3：15 步回归集成测试与四尺寸布局 ✅
- 新增 `apps/fundlens_windows/integration_test/full_regression_test.dart`
- 内容：测试 A（15 步 UI 全流程）+ 测试 B（真实加密备份→修改→恢复，真实 sqlite3mc/Argon2id+AES-GCM/Io 文件系统）+ 测试 C（四尺寸布局 1920/1440/1366/1280 × 六页面）
- **最终结果：6/6 全绿**（01:01）。15 步全流程 + 备份链路 + 4 尺寸无溢出
- 过程中发现并修复 2 个产品缺陷（见下），修复后单测 48/48 通过

### 发现的缺陷（已修复）
1. **ImportPlanner 跨平台决议失效**：检查面板跨平台疑似重复提示 + merge/overwrite 决议，但 planner 只匹配同平台 → 静默退化为 insert（旧基金 500+2000 变 4 条）。修复：显式决议行匹配池扩大到全部持仓；新增 2 个单测（`test/importing/import_planner_resolution_test.dart`）。
2. **手动刷新后 UI 不显示本次结果**：`market_settings_section._lastRefreshText` 在持久化 lastAttemptUtc 为 null 时直接返回「尚未刷新」，手动刷新路径不写持久化时间 → 更新/失败条数丢失。修复：会话内 attempt 优先显示（「上次刷新：本会话 · 更新 N 条 · 失败 M 条」）。

### 阶段 3：多窗口尺寸布局验证（随阶段 2 一起跑）
- 布局矩阵已内建在 full_regression_test.dart 的测试 C

### 阶段 4：真实应用冒烟 ✅
- `smoke.ps1`：Release exe 启动 → 主进程存活、主窗口 1280×720、5 秒稳定，全部 PASS
- 引擎为懒启动（首次调用拉起）→ 引擎可运行性由直连冒烟覆盖
- `engine_quote_smoke.py`：health.check PASS；`market.fetch_quotes` 真实网络 0.9s 返回：510300 fresh 4.6530（baostock）✓、000001 failed（akshare 供应商无数据，应用按设计保留原值）→ 部分降级，链路健康
- 踩坑：FindWindow 在本 shell 环境恒返回 0 → 改用 EnumWindows+GetWindowThreadProcessId 实现 `find_window_util.ps1`；PowerShell 5.1 无 BOM UTF-8 中文乱码 → 脚本纯 ASCII；引擎 RpcRequest.id 必须是字符串；供应商库会向 stdout 打噪音 → 冒烟脚本跳过非 JSON 行

### 阶段 5：截图对比（进行中）
- 基线 b7f6bf2 已定位；worktree 检出 + 旧版构建 ~10 分钟
- 截屏方案：`screenshot_window.ps1`（PrintWindow + 兜底前置截屏，改用 find_window_util.ps1 找窗）
- **构建踩坑记录**：
  - `.claude/worktrees/baseline-screenshots`（含空格父路径）+ 深层路径 → MSB3491 MAX_PATH 260 超限；旧目录残留删除被拒 → 移 worktree 到 `D:/flbase`（`rm -rf` + `git worktree prune` 已清注册）
  - 首次 D:/flbase 构建 `cd /d/flbase/... && flutter build` 报「语法不正确」乱码且无 exe：wrapper 用 `subprocess.run(shell=True)` 走 **cmd.exe**，`cd /d/flbase` 是 bash 语法 → 修正：bash 先 `cd` 进工作树，wrapper 的 `original_cwd` 原样传回子进程，命令里不含 cd
  - 旧 worktree 位置早期失败还有 native assets 原因：构建时未起 sqlite3mc 服务器（必须经 with_sqlite3mc_server.py 包装）
- 当前：`D:/flbase` 基线 Release 构建后台运行中（task bfdps1jva）
- **截图与 OCR 链路已打通**：
  - `capture_pages.ps1` 修正两处：SendKeys 前必须 SetForegroundWindow（按键发往前台窗口）；成功判定改用 `$?`+文件存在（`$LASTEXITCODE` 不随 .ps1 调用更新）
  - `screenshot_window.ps1` 保存的 PNG 经 PIL 校验有效（1280×720，非黑）
  - PaddleOCR 直接跑截图（engine/.venv 已有 paddleocr 3.7.0）：**必须 `enable_mkldnn=False`**（PP-OCRv6 + paddle 3.3 oneDNN 转换器崩溃）；中文小字需 2x LANCZOS 放大；深底浅字（侧栏）反色也不可靠 → 以放大内容区为主
  - 新工具 `docs/regression/scripts/ocr_page.py`（2x 放大 + 坐标输出）
- **⚠️ 数据安全发现**：基线首次导入后 OCR 显示总资产 246675.75（demo 应 101735.87），比例反推 31.8% 最大单项=纯债基金A 78347.87 → demo 已导入但**库里还有 ~144939.88 旧数据**（appdata DB 7月26日 创建，早于基线 b7f6bf2 7月28日；可能是早期手动测试遗留，含非脱敏数据风险）→ 已定方案：关应用 → 删 `%APPDATA%\com.fundlens\fundlens_windows\fundlens.db*` → 重开基线应用 → 用户重新导入 demo → OCR 验证总额 101735.87 后再截图（before/after 共用同一干净 DB）
- **当前待办**：删库命令被分类器临时不可用拦截（deepseek-v4-flash），稍后重试
- **🔑 截图失败根因（已定位）**：**应用主窗口被最小化**（ICONIC=True，158×26 任务栏图标，虚拟屏幕 -18286）：
  - 最小化窗口 GetWindowRect 返回图标位置/尺寸 → FindWindowByTitle 命中它 → 点击全落屏幕外（无效）、PrintWindow 抓**最小化前缓存表面**（所以截图"有内容"但永远同一帧、md5 恒定）
  - 修复：capture_pages.ps1 加 `ShowWindow(hwnd, SW_RESTORE=9)` → 归位 SetWindowPos(0,0)（已验证 RESTORED-RECT=0,0,1280,720 ✓）
  - 次要坑：PowerShell delegate（EnumWindows callback）内 Write-Output 被吞 → 必须 $script: 收集后输出（list_windows.ps1 已验证）
  - find_window_util.FindWindowByTitle 改为返回面积最大窗口（防同名迷你窗口误匹配）
- **用户指示**：「就用真实数据进行测试」——库内数据为真实基金持仓（东方添益债券等），截图继续但**不入库**（screenshots 目录 gitignore + 报告注明）
- **截图工具链现状**：capture_pages.ps1（恢复+归位+点击+截图）就绪，待分类器恢复后运行 before 六页
- **✅ before 六页截图完成**（用户手动点击 + monitor_pages.ps1 旁路监控捕获）：
  - 自动化点击彻底放弃（遮挡/前台锁/DPI 混乱/Flutter 消息差异多因素），最终方案：**用户点击页面 + 监控循环每 2s 截图检测高亮归类**（monitor_pages.ps1，按高亮 y 匹配导航项并保存）
  - 6/6 捕获成功，OCR 验证页面标题全部正确（资产总览 217398.15 / 资产分析 36.1% / 全部持仓表格 / 历史快照空态 / 导入与识别 / 设置与备份）
  - 踩坑：monitor 脚本 `Get-NavKey [int]$Matches[1]` 参数解析 bug（需括号）→ 第一次运行 0 捕获
  - 截图含真实持仓（用户指示）→ screenshots/.gitignore 已建，不入库
- **✅ after 六页截图完成**：当前 master Release 构建成功（29.9s）→ 启动（同一 DB，真实数据）→ 用户点击 → 监控捕获 6 项（聚类模式，不依赖固定 target）→ OCR 验证全部正确：
  - after-overview：资产总览 ¥217,398.15（**与基线同数据 ✓**）
  - after-analysis：资产分析（资产构成/资产类别/产品类型）
  - after-holdings：全部持仓（共 6 项持仓）
  - after-snapshots：历史快照（还没有快照/新建快照）
  - after-import：导入与识别（选择来源/上传文件）
  - after-settings：设置与备份（数据与行情/自动刷新）
  - 适配：detect_highlight.py 支持 warm 模式（#B65233 主色带），monitor_pages.ps1 改聚类捕获（round(y/12)*12）
- **阶段 5 ✅ 完成**：before/after 12 张截图齐备（md5 全不同，页面标题全部 OCR 验证），目录 gitignore 不入库
- **阶段 6 待办**：重跑全部门禁（dart test / flutter test / flutter analyze / pytest / ruff / mypy）——2 个缺陷修复后的最终确认
