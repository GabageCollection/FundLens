# FundLens

FundLens 是一款面向个人投资者的**本地资产快照分析工具**（Windows 桌面端）。它把来自支付宝、同花顺和手动录入的持仓统一汇总，展示总资产、资产结构、当前浮动盈亏和历史快照变化。

**它只描述资产事实，不提供任何投资建议；全部数据在本机处理和保存，不上传云端。**

## 功能特性

- **多来源持仓汇总**：支付宝 / 同花顺 CSV、Excel 导入，截图 OCR 识别（本地 PaddleOCR 中文引擎，识别结果须人工确认后入库），以及手动录入。
- **资产结构分析**：六类资产分类、Asset Spectrum 结构可视化、占比与集中度由统一组合口径重新计算，不采信平台原始占比。
- **盈亏与覆盖率**：浮动盈亏、持有收益率、总收益率、收益统计覆盖率，全部按十进制精度（`Decimal`）计算。
- **历史快照**：一键冻结当前组合为不可变快照，对比快照间的资产金额变化。
- **行情刷新**：内置 Python 数据引擎获取行情；刷新失败时保留最近一次有效估值，绝不用零值替代。
- **本地加密存储**：SQLCipher 加密 SQLite，数据库密钥由 Windows Credential Manager 保护；备份采用 Argon2id + AES-256-GCM。

## 安装

从 [Releases](../../releases) 页面下载最新的 `FundLens-Setup.exe`，运行安装程序即可。

- 系统要求：Windows 10 / 11（64 位）
- 最低窗口尺寸 1280 × 720，推荐 1440 × 900 及以上；支持高 DPI 缩放

## 使用文档

- 用户指南：[docs/user-guide.md](docs/user-guide.md)
- 已知限制（无直接债券、无交易流水、无实时行情、无云同步、无投资建议）：[docs/known-limitations.md](docs/known-limitations.md)
- 隐私与安全：[docs/privacy-and-security.md](docs/privacy-and-security.md)

## 技术架构

```
Flutter Windows 界面层（Riverpod 应用层）
        │   Ports（HoldingRepository / SnapshotRepository / DataEngineClient）
        ▼
纯 Dart 领域层 packages/fundlens_core     内置 Python 数据引擎 engine/
（分类 / 估值 / 盈亏 / 集中度 / 快照差异）   （本地 OCR / 名称匹配 / 行情获取）
        │                                       │ stdin/stdout JSON-RPC 2.0（schema v1）
        ▼
Drift + sqlite3mc（SQLCipher）加密 SQLite
```

- 界面层不直接计算金融指标，不直接访问数据库或 Python。
- 领域层不依赖 Flutter、数据库或网络，可独立测试与未来跨平台复用。
- Python 引擎只做识别与数据获取，不计算总资产、收益、风险，不写入正式持仓。

## 仓库结构

- `apps/fundlens_windows/` — Flutter Windows 应用
- `packages/fundlens_core/` — 纯 Dart 领域层（分类、估值、快照差异）
- `engine/` — 内置 Python 数据引擎（本地 OCR、名称匹配、行情）
- `installer/` — Inno Setup 安装脚本
- `tools/` — 构建与发布脚本

## 从源码构建

前置条件：Flutter SDK（Windows 桌面支持）、Python 3.11+、Inno Setup 6。

```powershell
# 全量发布流水线：工具链验证 → 引擎打包 → Dart/Flutter 测试 → analyze
# → flutter build windows --release → 内嵌引擎 → bundle 校验 → Inno Setup 安装包
powershell -File tools/build_windows_release.ps1

# 发布验收
powershell -File tests/release/verify_bundle.ps1
```

产出：`dist/installer/FundLens-Setup.exe`

## 测试

```bash
# 领域层（须在包目录内运行）
cd packages/fundlens_core && dart test

# Flutter 应用（Windows 上须经 sqlite3mc 本地服务器包装以提供 SQLCipher DLL）
python tools/with_sqlite3mc_server.py 8765 flutter test apps/fundlens_windows
flutter analyze apps/fundlens_windows

# Python 引擎（默认跳过联网测试）
python -m pytest engine/tests -q
python -m ruff check engine
python -m mypy engine/src
```

性能预算测试（2,000 持仓 / 500 快照）：

```bash
python tools/with_sqlite3mc_server.py 8765 \
  flutter test apps/fundlens_windows/integration_test/performance_test.dart
```

发布测试报告见 [docs/releases/](docs/releases/)，模板见 [docs/test-report-template.md](docs/test-report-template.md)。
