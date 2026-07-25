# FundLens

FundLens 是一款面向个人投资者的本地资产快照分析工具（Windows 桌面端）。它把来自支付宝、同花顺和手动录入的持仓统一汇总，展示总资产、资产结构、当前浮动盈亏和历史快照变化。它只描述资产事实，不提供任何投资建议；全部数据在本机处理和保存。

## V1 范围与限制

- 用户文档：[docs/user-guide.md](docs/user-guide.md)
- 已知限制（无直接债券、无交易流水、无实时行情、无云同步、无 Android、无投资建议）：[docs/known-limitations.md](docs/known-limitations.md)
- 隐私与安全：[docs/privacy-and-security.md](docs/privacy-and-security.md)

## 仓库结构

- `apps/fundlens_windows/` — Flutter Windows 应用
- `packages/fundlens_core/` — 纯 Dart 领域层（分类、估值、快照差异）
- `engine/` — 内置 Python 数据引擎（本地 OCR、名称匹配、行情）
- `installer/` — Inno Setup 安装脚本
- `tools/` — 构建与发布脚本

## 构建与测试

```bash
dart test packages/fundlens_core
flutter test apps/fundlens_windows        # Windows 上需经 tools/with_sqlite3mc_server.py 包装
flutter analyze apps/fundlens_windows
python -m pytest engine/tests -m "not live" -q
python -m ruff check engine
python -m mypy engine/src
```

性能预算测试（2,000 持仓 / 500 快照）：

```bash
flutter test apps/fundlens_windows/integration_test/performance_test.dart
```

## 发布打包

```powershell
powershell -File tools/build_windows_release.ps1   # 构建并校验 release bundle 和安装包
powershell -File tests/release/clean_vm_acceptance.ps1 dist/installer/FundLens-Setup.exe
```

发布测试报告见 `docs/releases/`，模板见 `docs/test-report-template.md`。
