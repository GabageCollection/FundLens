# FundLens Windows V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this roadmap phase-by-phase. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付一个只在本地运行、可统一统计支付宝/同花顺/手工资产、支持截图 OCR、免费日线行情、历史快照和加密备份的 FundLens Windows V1。

**Architecture:** 项目采用 Flutter Windows 主应用、纯 Dart 领域包、Drift + SQLite3MultipleCiphers 加密数据库，以及通过 stdin/stdout JSON-RPC 2.0 通信的内置 Python 数据引擎。实施按四个可独立验收的阶段推进，每一阶段必须通过自己的测试门禁后才能进入下一阶段。

**Tech Stack:** Flutter + Dart、Riverpod、Drift、sqlite3/sqlite3mc、PointyCastle、Windows Credential Manager（通过 flutter_secure_storage）、Python 3.11+、PaddleOCR、AKShare、BaoStock、PyInstaller、Inno Setup。

## Global Constraints

- 首版只开发、测试和交付 Windows，不创建 Android 页面、适配或构建配置。
- 最低窗口尺寸为 `1280 × 720`，重点验证 `1440 × 900` 和 `1920 × 1080`，支持 Windows 高 DPI。
- 金额、价格、份额和比例不得用二进制浮点参与领域计算；Dart 使用十进制定点值，SQLite 使用十进制字符串。
- 当前持仓可变，历史快照不可变；行情刷新不得创建或修改历史快照。
- 快照差额一律称为“资产金额变化”，不得称为投资收益。
- 不实现交易、交易流水、VaR、回撤、波动率、自动登录、云同步或任何买卖/再平衡建议。
- OCR、行情和产品匹配只在 Python 引擎执行；总资产、收益、风险、数据库写入、快照和备份只在 Dart 执行。
- Python 通信使用逐行 JSON-RPC 2.0，所有消息携带 `schema_version = 1`，不开放 localhost 端口。
- 数据库使用 SQLite3MultipleCiphers 的 SQLCipher 兼容模式，密钥由 Windows Credential Manager 保护。
- 备份使用 Argon2id + AES-256-GCM；每份备份必须有独立随机盐和 nonce。
- 原始支付宝、同花顺截图不得进入仓库；OCR 测试只用脱敏合成图。
- 默认截图导入模式为“部分持仓”；模糊匹配和关键低置信度字段必须人工确认。
- 支付宝只有金额、没有份额时，行情不得反推当前金额。
- 盈利用 `#C54B40`，亏损用 `#2E8162`；颜色之外必须提供符号和文字语义。
- 所有依赖在阶段 1 执行时选择稳定版本并提交 lockfile；后续阶段不得无评审升级。
- 每个任务都遵循 TDD：先失败测试，再最小实现，再完整回归，再提交。

## Phase Order

| 阶段 | 计划文件 | 可独立验收的结果 | 进入下一阶段的门禁 |
|---|---|---|---|
| 1 | [核心领域与加密存储](2026-07-19-fundlens-phase-1-core-storage.md) | 纯 Dart 组合计算、加密数据库、当前持仓与不可变快照服务 | Dart/Flutter 测试通过；Windows 上 cipher 烟雾测试通过 |
| 2 | [导入、OCR、行情与进程协议](2026-07-19-fundlens-phase-2-data-engine.md) | 可独立运行的 Python JSON-RPC 引擎，以及 Dart 导入/行情应用服务 | Python、协议契约、导入事务和行情降级测试通过 |
| 3 | [Asset Spectrum Windows 界面](2026-07-19-fundlens-phase-3-windows-ui.md) | 六页 Windows 应用，完成手工持仓、分析、快照和 OCR 确认工作流 | Widget、golden、键盘和 1280×720 布局测试通过 |
| 4 | [备份、安全、打包与验收](2026-07-19-fundlens-phase-4-release.md) | 加密备份、隐私控制、内置引擎、安装程序、说明和验收报告 | 干净 Windows VM 安装/升级/卸载与全量测试通过 |

## Cross-Phase Interfaces

阶段之间只通过以下稳定接口连接：

```dart
abstract interface class HoldingRepository {
  Stream<List<Holding>> watchAll();
  Future<void> upsert(Holding holding);
  Future<void> deleteById(String id);
  Future<void> replacePlatform(SourcePlatform platform, List<Holding> holdings);
  Future<T> transaction<T>(Future<T> Function(HoldingRepository tx) action);
}

abstract interface class SnapshotRepository {
  Stream<List<PortfolioSnapshot>> watchAll();
  Future<PortfolioSnapshot?> getById(String id);
  Future<String> createFromCurrent({required String label});
  Future<void> deleteById(String id);
}

abstract interface class DataEngineClient {
  Future<Map<String, Object?>> call(String method, Map<String, Object?> params, {Duration timeout = const Duration(seconds: 30)});
  Future<void> cancel(String requestId);
  Future<void> close();
}
```

Python 引擎对 Dart 只暴露四个方法：

```text
health.check
ocr.parse_screenshots
product.match_candidates
market.fetch_quotes
```

## Whole-Product Acceptance Gate

- [ ] `dart test packages/fundlens_core` 全部通过。
- [ ] `flutter test apps/fundlens_windows` 全部通过。
- [ ] `python -m pytest engine/tests -q` 全部通过。
- [ ] `flutter analyze apps/fundlens_windows` 无 error/warning。
- [ ] `python -m ruff check engine` 与 `python -m mypy engine/src` 通过。
- [ ] 2,000 条当前持仓、500 份快照基准测试达到设计目标，切换页面不重复查询数据库或启动 Python 任务。
- [ ] 支付宝/同花顺脱敏合成图字段、正负号、多行边界和忽略区域验收通过。
- [ ] 错误备份密码、损坏备份、行情失败、OCR 低置信度、Python 崩溃和数据库事务回滚均有自动化测试。
- [ ] 干净 Windows VM 上完成安装、首次启动、导入、保存快照、备份、恢复、升级和卸载数据保留测试。
- [ ] UI 和文案扫描确认没有买卖、调仓、再平衡或“快照收益”等越界表述。

## Spec Coverage Map

| 规格章节 | 实施位置 |
|---|---|
| 产品边界与资产范围 | Phase 1 Tasks 2–4；Phase 3 Tasks 3–5；Phase 4 用户说明 |
| Flutter/Dart/Python 架构 | Phase 1 Task 1；Phase 2 Tasks 1–2 |
| Asset Spectrum 视觉 | Phase 3 Tasks 1、4 |
| 六页信息架构 | Phase 3 Tasks 1、3–7 |
| 当前持仓、快照及其他数据对象 | Phase 1 Tasks 2、4、5；Phase 2 Task 3 |
| 支付宝/同花顺映射与计算 | Phase 2 Tasks 3–4；Phase 1 Task 3 |
| 当前持仓与快照流程 | Phase 1 Tasks 4–5；Phase 3 Task 5 |
| CSV/Excel/OCR/部分与完整导入 | Phase 2 Tasks 3–4；Phase 3 Task 6 |
| 持仓表三种列预设 | Phase 3 Task 3 |
| BaoStock/AKShare 行情与降级 | Phase 2 Tasks 5–6 |
| 结构分析与数据质量 | Phase 1 Task 3；Phase 3 Tasks 4–5 |
| 异常、隐私、安全和备份 | Phase 2 Tasks 2、6；Phase 4 Tasks 1–3 |
| 性能、安装、文档和最终验收 | Phase 4 Tasks 4–5 |

## Reference Baseline

- 产品规格：`docs/superpowers/specs/2026-07-19-fundlens-windows-design.md`
- 视觉板：`docs/superpowers/specs/assets/fundlens-asset-spectrum-design.svg`
- Flutter Windows 构建：[Flutter 官方文档](https://docs.flutter.dev/platform-integration/windows/building)
- Drift 加密数据库：[Drift 官方加密文档](https://drift.simonbinder.eu/platforms/encryption/)
- Drift 后台 isolate：[Drift Native 官方文档](https://drift.simonbinder.eu/platforms/vm/)
- Windows 凭据保护：[flutter_secure_storage Windows 文档](https://pub.dev/documentation/flutter_secure_storage_windows/latest/)
- Argon2id 与 AES-GCM：[PointyCastle API](https://pub.dev/packages/pointycastle)
