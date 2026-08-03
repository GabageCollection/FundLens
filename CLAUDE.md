# FundLens — 长期架构与开发约束

## 产品定位
FundLens Windows V1 是一款面向个人投资者的本地资产快照分析工具。它只描述资产事实，不替用户做投资决策。

## 核心架构

- **Flutter Windows 界面层**：负责 Windows 桌面页面、Asset Spectrum 视觉组件、表格、表单和用户反馈；不直接计算金融指标，不直接访问数据库或 Python。
- **纯 Dart 领域层**：资产分类、估值、成本、浮动盈亏、收益覆盖率、集中度、快照差异全部在 `packages/fundlens_core` 中实现，不依赖 Flutter、数据库或网络。
- **应用层**：用 Riverpod 组织导入、快照、行情、分析等完整用例，所有写操作通过明确事务边界执行。
- **能力接口层 / Ports**：`HoldingRepository`、`SnapshotRepository`、`DataEngineClient` 等抽象接口，连接 Flutter 与底层实现。
- **加密本地存储**：Drift + sqlite3mc（SQLCipher 兼容）加密 SQLite；数据库密钥由 Windows Credential Manager（flutter_secure_storage）保护。
- **内置 Python 数据引擎**：仅负责本地 PaddleOCR 中文识别、产品名称匹配、行情获取和字段标准化。通过 stdin/stdout 逐行 JSON-RPC 2.0 通信，`schema_version = 1`。不计算总资产、收益、风险，不写入正式持仓。
- **引擎协议契约**：`schemas/engine_protocol_v1.schema.json` 定义请求/成功/失败信封（`schema_version = 1`）；引擎只暴露 `health.check`、`ocr.parse_screenshots`、`product.match_candidates`、`market.fetch_quotes` 四个方法。
- **数据库 schema**：当前 `schemaVersion = 1`，尚无 Drift 迁移机制；改表前需先设计版本迁移与旧备份升级路径。

## 不可变数据原则

- **当前持仓可变**：可通过导入、OCR、手动编辑和行情刷新更新。
- **历史快照不可变**：保存后冻结所有字段，行情刷新和后续持仓修改均不得修改快照。
- 快照间差额只能称为“资产金额变化”，不能称为投资收益。
- `cumulativeProfit`（累计收益）只展示，不加入当前浮动盈亏汇总。

## 计算口径

- 所有金额、价格、份额、比例使用 `Decimal`（Dart）或十进制字符串（SQLite），不得用二进制浮点。
- 浮动盈亏 = 当前金额 − 持有成本。
- 持有收益率 = 浮动盈亏 ÷ 持有成本（成本为空或 0 时不计算）。
- 总收益率 = 有成本资产的浮动盈亏之和 ÷ 有成本资产的成本之和。
- 收益统计覆盖率 = 有成本资产当前金额之和 ÷ 总资产。
- 占比和集中度由 FundLens 基于统一组合重新计算，不采信平台原始占比。

## 平台与范围约束

- V1 只开发、测试和交付 Windows 桌面应用；最低窗口 `1280 × 720`，重点验证 `1440 × 900` 和 `1920 × 1080`，支持 Windows 高 DPI 缩放。
- 不实现 Android 页面、构建或平台适配；但领域层和接口不得依赖 Windows UI，以保留未来扩展能力。
- 不实现登录、云同步、多用户、自动交易、买卖建议、再平衡建议、交易流水、VaR/最大回撤/波动率/夏普等量化指标。
- Python 不处理正式持仓写入、快照管理、总资产、核心收益或备份加密。
- OCR 必须在本地执行；截图导入必须预览、校验并经人工确认后才能写入；默认导入模式为“部分持仓”。
- 行情失败时保留上次有效值，不使用零值替代；支付宝等无份额来源不反推当前金额。

## 安全与隐私

- 所有持仓、截图、备份本地处理，不上传云端。
- 备份使用 Argon2id + AES-256-GCM，每份备份使用独立随机盐和 nonce。
- 恢复备份时先解密到临时区域、验证结构版本和校验值，再原子替换当前数据库；替换前保留当前库的可恢复副本。
- 日志和仓库中不得写入真实持仓、账户截图、密码、Token、数据库密钥或备份密码。
- 原始用户截图不得进入代码仓库；OCR 测试只使用脱敏合成图。

## 视觉约定

- 设计系统：Open Design 暖墨体系（2026-07 全局设计变量统一，替代旧 Graphite/Indigo 约定）。语义变量：画布 `--color-canvas #F6F3EC`、表面 `#FFFDF8`、侧栏 `#27231D`、主色 `#B65233`、正文 `#292722`、辅助文字 `#736E64`、边框 `#E4DED1`、盈利 `#B84B34`、亏损 `#19705D`、数据异常 `#A66A16`、禁用 `#C9C5BC`；资产类别段色与 soft 底色以 `apps/fundlens_windows/lib/theme/fundlens_tokens.dart` 为唯一准绳，组件中不得硬编码颜色。
- 字体层级：页面标题 24/32 w600、区块标题 18/26 w600、正文 14/22、辅助 12/18（说明文字不得小于 12）、KPI 数字 20–24、表格金额 14px tabular-nums。标题用宋体（Noto Serif SC），正文用黑体（Noto Sans SC），金额比例用 IBM Plex Mono。
- 间距体系：只允许 4/8/12/16/24/32/40/48；标题与内容间距 20–24、卡片内边距 20/24、卡片间距 16、表单项纵向间距 16、表格行高 48–56。
- 组件规范：卡片圆角 12、1px 浅色边框、无阴影；主按钮高 40、次按钮 36–40、输入框高 40；点击区域 ≥40×40；键盘 Focus 为 2px 主色轮廓；Hover/Focus/Active/Disabled 状态必须完整。
- 国内颜色习惯：红盈利、绿亏损；颜色之外必须提供符号和文字语义。
- 禁止用渐变、发光、玻璃拟态或大量阴影制造高级感；辨识度来自账本式排版、精确的数据对齐和资产结构信息。

## 开发工作流

- 每个阶段使用 Git 工作树隔离，分支名为 `feat/phase-N-*`；不在 main/master 直接开发。
- 每个任务遵循 TDD：先写失败测试，再最小实现，再运行完整回归，最后小而清晰的提交。
- 阶段完成后通过独立验收门禁；未通过门禁不进入下一阶段。
- 依赖版本在阶段 1 固定并提交 lockfile；后续阶段未经评审不得升级。
- 任务完成、质量门禁全绿后直接合并回 master（非 fast-forward 用 `git merge --no-ff`），并按 `tools/build_windows_release.ps1` 产出 Windows exe；不留在分支上等验收。

## 常用命令

### 质量门禁（提交前全绿）

```bash
# 领域层——dart test 必须在包目录内运行，否则报 “No pubspec.yaml”
cd packages/fundlens_core && dart test

# Flutter 应用——Windows 上须经 sqlite3mc 本地服务器包装以提供 SQLCipher DLL
python tools/with_sqlite3mc_server.py 8765 flutter test apps/fundlens_windows
flutter analyze apps/fundlens_windows

# Python 引擎——pyproject.toml 已默认 `addopts = "-m 'not live'"` 跳过联网测试
python -m pytest engine/tests -q
python -m ruff check engine
python -m mypy engine/src
```

### 运行单个测试

```bash
cd packages/fundlens_core && dart test test/model/decimal_value_test.dart
cd packages/fundlens_core && dart test --plain-name 'DecimalValue 精确相等'

python tools/with_sqlite3mc_server.py 8765 \
  flutter test apps/fundlens_windows/test/storage/app_database_test.dart
python tools/with_sqlite3mc_server.py 8765 \
  flutter test apps/fundlens_windows/integration_test/performance_test.dart

python -m pytest engine/tests/test_server.py -q
python -m pytest engine/tests/test_server.py -k 'utf8' -q
```

### 构建与打包

```bash
# 数据引擎（PyInstaller → dist/engine/fundlens_engine）
powershell -File tools/build_engine.ps1

# 全量发布流水线：工具链验证 → 引擎打包 → Dart/Flutter 测试 → analyze
# → flutter build windows --release → 内嵌引擎 → bundle 校验 → Inno Setup 安装包
powershell -File tools/build_windows_release.ps1

# 发布验收
powershell -File tests/release/verify_bundle.ps1
powershell -File tests/release/clean_vm_acceptance.ps1 dist/installer/FundLens-Setup.exe
```

### 环境注意

- 本机 Flutter 在 `D:\flutter`；构建脚本硬编码 `D:\flutter\bin\flutter.bat` 与 `dart.exe`，并设置 pub 镜像 `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL`（`https://pub.flutter-io.cn`）。手动执行前确认 `D:\flutter\bin` 在 PATH。
- `flutter test` / `flutter build` 在 Windows 上依赖 sqlite3mc DLL，必须经 `tools/with_sqlite3mc_server.py <端口> <命令>` 包装。
- 关键场景回归：空成本/负收益、六类资产、行情过期/失败、OCR 低置信度、事务回滚、错误/损坏备份、Python 引擎崩溃恢复。
