# FundLens 发布测试报告模板

> 每次发布候选（RC）复制本模板到 `docs/releases/v<版本号>-test-report.md`，
> 只填写**实际观察到**的证据，不得预填预期结果。无法在本机执行的项目
> 标注“待发布机器执行”。

## 基本信息

| 项目 | 值 |
|---|---|
| 版本 | |
| 报告日期 | |
| 执行机器 | （开发机 / 干净 VM，注明 Windows 版本与 build） |
| 安装包路径 | |
| 安装包 SHA-256 | |
| 依赖锁定哈希 | （pubspec.lock × 2、engine/requirements.lock 的 SHA-256） |

## 自动化测试证据

| 命令 | 结果（实际数字） | 通过? |
|---|---|---|
| `dart test packages/fundlens_core` | | |
| `flutter test apps/fundlens_windows`（经 sqlite3mc 包装器） | | |
| `flutter analyze apps/fundlens_windows` | | |
| `python -m pytest engine/tests -m "not live" -q` | | |
| `python -m ruff check engine` | | |
| `python -m mypy engine/src` | | |
| `flutter test apps/fundlens_windows/integration_test` | | |
| `powershell -File tools/build_windows_release.ps1` | | |
| `powershell -File tests/release/clean_vm_acceptance.ps1 <安装包>` | | |

## 性能实测（2,000 持仓 / 500 快照）

| 指标 | 预算 | 实测 | 通过? |
|---|---|---|---|
| 首次渲染并稳定 | < 3000 ms | | |
| 切换到“资产分析”并稳定 | < 500 ms | | |
| 持仓仓库全量读取次数 | = 1 | | |
| 引擎启动次数 | = 1 | | |

## 干净 VM 验收清单（8 项，全部使用合成数据）

1. [ ] 手动添加现金、存款和实物黄金
2. [ ] 支付宝截图部分导入并修正一处低置信度字段
3. [ ] 同花顺截图导入，核对名称/金额/份额/成本/正负号
4. [ ] 行情刷新；支付宝纯金额持仓金额不变，失败保留上次有效值
5. [ ] 保存两个快照并对比“资产金额变化”
6. [ ] 加密备份；错误密码被拒绝；正确密码恢复成功
7. [ ] 杀掉数据引擎后进入降级模式，手动/缓存数据可用
8. [ ] 全应用无投资建议措辞；安装目录无日志/备份/用户文件

## 升级与卸载

| 项目 | 结果 |
|---|---|
| 旧版本覆盖安装后数据库保留 | |
| 覆盖安装后持仓与快照可见 | |
| 静默卸载后 `%APPDATA%\FundLens` 保留 | |

## 未解决的发布阻断缺陷

（无则写“无”。）

## 结论

（通过 / 不通过，附执行人签名与日期。）
