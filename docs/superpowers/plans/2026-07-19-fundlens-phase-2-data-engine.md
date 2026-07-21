# FundLens Phase 2 Data Engine and Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付可独立运行的 Python 数据引擎和 Dart 应用服务，完成 CSV/Excel、支付宝/同花顺截图 OCR、候选匹配、免费行情与安全降级。

**Architecture:** Dart 负责文件选择、导入草稿、问题状态、合并计划和正式数据库事务；Python 只做 OCR、候选匹配、行情获取与 DTO 规范化。双方共享版本 1 JSON Schema fixtures，通过 stdin/stdout 的逐行 JSON-RPC 2.0 交互。

**Tech Stack:** Dart、Python 3.11/3.12、Pydantic、PaddleOCR、Pillow、AKShare、BaoStock、pytest、ruff、mypy、PyInstaller、JSON-RPC 2.0。

## Global Constraints

- Python 不写正式数据库，不计算总资产/收益/结构风险，不创建快照或备份。
- 通信不开放 TCP 端口；stdout 只输出 JSON-RPC，诊断信息只写 stderr。
- 所有请求和响应包含 `schema_version = 1`；未知版本或未知方法返回结构化错误。
- 引擎支持请求超时、取消和一次受控重启；连续失败后停止重启。
- 原始用户截图不得进入仓库；测试只使用脚本生成的脱敏图。
- OCR 每个字段返回文本、置信度、裁剪矩形和来源页；关键字段不确定时不得提交。
- 默认导入模式为部分持仓；完整模式才能移除同平台未出现项。
- 模糊名称匹配只产生候选，不自动合并。
- 行情失败保留旧值且标记过期，不得以零替代。
- 只有代码和数量/份额都已确认时，行情才重算当前金额。

---

### Task 1: Freeze protocol v1 and bootstrap the Python package

**Files:**
- Create: `schemas/engine_protocol_v1.schema.json`
- Create: `schemas/fixtures/health_success.json`
- Create: `schemas/fixtures/ocr_success.json`
- Create: `schemas/fixtures/quotes_partial_success.json`
- Create: `engine/pyproject.toml`
- Create: `engine/src/fundlens_engine/__init__.py`
- Create: `engine/src/fundlens_engine/models.py`
- Create: `engine/tests/test_schema_fixtures.py`

**Interfaces:**
- Produces: JSON-RPC methods `health.check`, `ocr.parse_screenshots`, `product.match_candidates`, `market.fetch_quotes`.
- Produces: `RpcRequest`, `RpcSuccess`, `RpcFailure`, `OcrField`, `QuoteResult` Pydantic models.

- [x] **Step 1: Write failing schema fixture tests**

```python
from pathlib import Path
import json
import jsonschema

ROOT = Path(__file__).parents[2]

def test_all_protocol_fixtures_validate() -> None:
    schema = json.loads((ROOT / "schemas/engine_protocol_v1.schema.json").read_text("utf-8"))
    for fixture in (ROOT / "schemas/fixtures").glob("*.json"):
        jsonschema.validate(json.loads(fixture.read_text("utf-8")), schema)

def test_every_fixture_declares_schema_version_one() -> None:
    for fixture in (ROOT / "schemas/fixtures").glob("*.json"):
        assert json.loads(fixture.read_text("utf-8"))["schema_version"] == 1
```

- [x] **Step 2: Run the test and confirm failure**

Run: `python -m pytest engine/tests/test_schema_fixtures.py -q`

Expected: FAIL because the schema and package are absent.

- [x] **Step 3: Add the package manifest and protocol models**

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "fundlens-engine"
version = "0.1.0"
requires-python = ">=3.11,<3.13"
dependencies = [
  "pydantic>=2.7,<3",
  "paddleocr>=3,<4",
  "paddlepaddle>=3,<4",
  "Pillow>=10,<13",
  "akshare>=1.17,<2",
  "baostock>=0.8.9,<1",
]

[project.optional-dependencies]
dev = ["pytest>=8,<10", "pytest-timeout>=2,<3", "jsonschema>=4,<5", "ruff>=0.12,<1", "mypy>=1.15,<2", "pip-tools>=7,<8", "pyinstaller>=6,<7"]

[tool.pytest.ini_options]
testpaths = ["tests"]
timeout = 30

[tool.ruff]
line-length = 100

[tool.mypy]
python_version = "3.11"
strict = true
```

```python
from typing import Any, Literal
from pydantic import BaseModel, ConfigDict, Field

class RpcRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    jsonrpc: Literal["2.0"]
    id: str
    method: str
    params: dict[str, Any] = Field(default_factory=dict)
    schema_version: Literal[1]

class RpcError(BaseModel):
    code: str
    message: str
    retryable: bool = False
    details: dict[str, Any] = Field(default_factory=dict)

class OcrField(BaseModel):
    name: str
    raw_text: str
    confidence: float = Field(ge=0, le=1)
    page_index: int = Field(ge=0)
    crop: tuple[int, int, int, int]

class QuoteResult(BaseModel):
    product_code: str
    value: str | None
    valuation_date: str | None
    provider: str
    status: Literal["fresh", "stale", "failed"]
    error_code: str | None = None
```

Use this complete Draft 2020-12 schema shape; keep `result` open because each method has its own fixture contract, while request/error envelopes remain strict:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://fundlens.local/schema/engine-protocol-v1.json",
  "oneOf": [
    {"$ref": "#/$defs/request"},
    {"$ref": "#/$defs/success"},
    {"$ref": "#/$defs/failure"}
  ],
  "$defs": {
    "base": {
      "type": "object",
      "required": ["jsonrpc", "id", "schema_version"],
      "properties": {
        "jsonrpc": {"const": "2.0"},
        "id": {"type": "string", "minLength": 1},
        "schema_version": {"const": 1}
      }
    },
    "request": {
      "allOf": [
        {"$ref": "#/$defs/base"},
        {"type": "object", "required": ["method", "params"], "properties": {"method": {"type": "string", "minLength": 1}, "params": {"type": "object"}}, "not": {"anyOf": [{"required": ["result"]}, {"required": ["error"]}]}, "unevaluatedProperties": false}
      ]
    },
    "success": {
      "allOf": [
        {"$ref": "#/$defs/base"},
        {"type": "object", "required": ["result"], "properties": {"result": {"type": "object"}}, "not": {"required": ["error"]}, "unevaluatedProperties": false}
      ]
    },
    "failure": {
      "allOf": [
        {"$ref": "#/$defs/base"},
        {"type": "object", "required": ["error"], "properties": {"error": {"type": "object", "required": ["code", "message", "retryable", "details"], "properties": {"code": {"type": "string"}, "message": {"type": "string"}, "retryable": {"type": "boolean"}, "details": {"type": "object"}}, "additionalProperties": false}}, "not": {"required": ["result"]}, "unevaluatedProperties": false}
      ]
    }
  }
}
```

Fixtures must contain only synthetic product names and amounts.

- [x] **Step 4: Lock dependencies and validate fixtures**

Run:

```powershell
python -m venv engine/.venv
engine/.venv/Scripts/python -m pip install --upgrade pip
engine/.venv/Scripts/python -m pip install -e "engine[dev]"
engine/.venv/Scripts/pip-compile engine/pyproject.toml --extra dev --generate-hashes -o engine/requirements.lock
engine/.venv/Scripts/python -m pytest engine/tests/test_schema_fixtures.py -q
```

Expected: all fixtures validate and `engine/requirements.lock` is created.

- [x] **Step 5: Commit the protocol**

```bash
git add schemas engine/pyproject.toml engine/requirements.lock engine/src engine/tests
git commit -m "feat(engine): define versioned data engine protocol"
```

---

### Task 2: Implement the JSON-RPC server and Dart process supervisor

**Files:**
- Create: `engine/src/fundlens_engine/server.py`
- Create: `engine/src/fundlens_engine/__main__.py`
- Create: `engine/tests/test_server.py`
- Create: `apps/fundlens_windows/lib/data_engine/engine_message.dart`
- Create: `apps/fundlens_windows/lib/data_engine/data_engine_client.dart`
- Create: `apps/fundlens_windows/lib/data_engine/process_data_engine_client.dart`
- Test: `apps/fundlens_windows/test/data_engine/process_data_engine_client_test.dart`

**Interfaces:**
- Produces: `python -m fundlens_engine` line server.
- Produces: `DataEngineClient.call<T>()`, `cancel()`, `close()`.

- [x] **Step 1: Write server failure and protocol tests**

```python
def test_health_check_returns_version_one(run_rpc) -> None:
    response = run_rpc({"jsonrpc":"2.0","id":"1","method":"health.check","params":{},"schema_version":1})
    assert response["result"] == {"status":"ok","engine_version":"0.1.0"}
    assert response["schema_version"] == 1

def test_unknown_version_is_structured_error(run_rpc) -> None:
    response = run_rpc({"jsonrpc":"2.0","id":"2","method":"health.check","params":{},"schema_version":99})
    assert response["error"]["code"] == "protocol.version_unsupported"
    assert response["error"]["retryable"] is False
```

Write a Dart test with a fake `ProcessAdapter` that emits one success line, malformed JSON, then exits. Assert success correlation by id, malformed-line isolation, pending-request failure on exit, and at most one restart.

- [x] **Step 2: Run both tests and confirm failure**

Run: `python -m pytest engine/tests/test_server.py -q && flutter test apps/fundlens_windows/test/data_engine/process_data_engine_client_test.dart`

Expected: FAIL because server and client do not exist.

- [x] **Step 3: Implement the line server**

```python
import json
import sys
from collections.abc import Callable
from typing import Any
from pydantic import ValidationError
from .models import RpcRequest

Handler = Callable[[dict[str, Any]], dict[str, Any]]

def health(_: dict[str, Any]) -> dict[str, Any]:
    return {"status": "ok", "engine_version": "0.1.0"}

HANDLERS: dict[str, Handler] = {"health.check": health}

def handle_line(line: str) -> dict[str, Any]:
    request_id = "unknown"
    try:
        raw = json.loads(line)
        request_id = str(raw.get("id", "unknown"))
        if raw.get("schema_version") != 1:
            raise ValueError("protocol.version_unsupported")
        request = RpcRequest.model_validate(raw)
        handler = HANDLERS.get(request.method)
        if handler is None:
            raise ValueError("protocol.method_not_found")
        return {"jsonrpc":"2.0","id":request.id,"result":handler(request.params),"schema_version":1}
    except (json.JSONDecodeError, ValidationError, ValueError) as exc:
        code = str(exc) if str(exc).startswith("protocol.") else "protocol.invalid_request"
        return {"jsonrpc":"2.0","id":request_id,"error":{"code":code,"message":"Request rejected","retryable":False,"details":{}},"schema_version":1}

def main() -> None:
    for line in sys.stdin:
        response = handle_line(line)
        sys.stdout.write(json.dumps(response, ensure_ascii=False, separators=(",", ":")) + "\n")
        sys.stdout.flush()
```

Write all operational logs to `sys.stderr`; never print logging to stdout.

- [x] **Step 4: Implement the supervised Dart client**

```dart
abstract interface class DataEngineClient {
  Future<Map<String, Object?>> call(String method, Map<String, Object?> params, {Duration timeout = const Duration(seconds: 30)});
  Future<void> cancel(String requestId);
  Future<void> close();
}
```

`ProcessDataEngineClient` must inject a `ProcessAdapter`, serialize calls through one active-request queue, generate UUID ids, write one compact JSON object per line, correlate completers by id, validate `schema_version == 1`, convert engine errors to `DataEngineException`, fail all pending calls on unexpected exit, and restart only once. `cancel(requestId)` removes a queued request immediately; for the active request it terminates the child, completes that request as cancelled, and starts a fresh child on the next call without counting the user cancellation as a crash. Timeout uses the same path. Treat malformed stdout as an engine protocol error; capture stderr only through a redacting logger.

- [x] **Step 5: Run contract tests and commit**

Run: `python -m pytest engine/tests/test_server.py -q && flutter test apps/fundlens_windows/test/data_engine && python -m ruff check engine && python -m mypy engine/src`

Expected: PASS; no test opens a TCP socket.

```bash
git add engine apps/fundlens_windows/lib/data_engine apps/fundlens_windows/test/data_engine
git commit -m "feat(engine): supervise JSON-RPC child process"
```

---

### Task 3: Parse CSV/Excel and build transactional import plans in Dart

**Files:**
- Modify: `apps/fundlens_windows/pubspec.yaml`
- Create: `apps/fundlens_windows/lib/importing/import_models.dart`
- Create: `apps/fundlens_windows/lib/importing/tabular_import_parser.dart`
- Create: `apps/fundlens_windows/lib/importing/import_planner.dart`
- Create: `apps/fundlens_windows/lib/importing/import_commit_service.dart`
- Test: `apps/fundlens_windows/test/importing/tabular_import_parser_test.dart`
- Test: `apps/fundlens_windows/test/importing/import_planner_test.dart`
- Test: `apps/fundlens_windows/test/importing/import_commit_service_test.dart`
- Create: `docs/import-template/fundlens-import-template.csv`

**Interfaces:**
- Produces: `ImportDraft`, `DraftHolding`, `DataIssue`, `ImportMode.partial/full`, `ImportPlan`.
- Consumes: `HoldingRepository.replacePlatform` and `upsert` from Phase 1.

- [x] **Step 1: Add parsers and write failing mapping tests**

Run: `cd apps/fundlens_windows && flutter pub add csv excel`

```dart
test('CSV parser maps decimals and preserves platform tags', () async {
  final draft = await parser.parseCsv('''source_platform,product_name,current_value,holding_profit,platform_tags\n支付宝,脱敏纯债基金A,78347.87,428.96,基金|稳健理财''');
  expect(draft.holdings.single.currentValue.canonical, '78347.87');
  expect(draft.holdings.single.platformTags, ['基金', '稳健理财']);
});

test('full import proposes removals only for the same platform', () {
  final plan = planner.plan(mode: ImportMode.full, platform: SourcePlatform.alipay, current: [alipayOld, thsOld, manualOld], incoming: [alipayNew]);
  expect(plan.removeIds, [alipayOld.id]);
  expect(plan.unchangedIds, containsAll([thsOld.id, manualOld.id]));
});
```

- [x] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/importing`

Expected: FAIL because import types do not exist.

- [x] **Step 3: Implement draft and issue contracts**

```dart
enum ImportMode { partial, full }
enum IssueSeverity { info, warning, blocking }

final class DataIssue {
  const DataIssue({required this.code, required this.field, required this.severity, required this.message, this.holdingIndex});
  final String code;
  final String field;
  final IssueSeverity severity;
  final String message;
  final int? holdingIndex;
}

final class ImportPlan {
  const ImportPlan({required this.inserts, required this.updates, required this.removeIds, required this.unchangedIds, required this.issues});
  final List<Holding> inserts;
  final List<Holding> updates;
  final List<String> removeIds;
  final List<String> unchangedIds;
  final List<DataIssue> issues;
  bool get canCommit => issues.every((i) => i.severity != IssueSeverity.blocking);
}
```

`TabularImportParser` must accept Chinese and canonical English headings, reject duplicate columns, parse comma/space currency formats without `double`, preserve unknown columns in draft metadata, and create blocking issues for missing product name/current amount or invalid signs.

- [x] **Step 4: Implement planning and atomic commit**

Matching order is: same platform + exact product code; otherwise same platform + normalized name + instrument type; otherwise insert. Name-only ambiguity creates a blocking issue. `ImportCommitService.commit(plan)` rejects `!canCommit`, then performs all inserts/updates/removals in one repository transaction. Default constructors and UI state must select `ImportMode.partial`.

Run: `flutter test apps/fundlens_windows/test/importing && flutter test apps/fundlens_windows/test/storage`

Expected: PASS, including an injected mid-commit failure leaving current holdings unchanged.

- [x] **Step 5: Commit tabular import**

```bash
git add apps/fundlens_windows docs/import-template
git commit -m "feat(import): add transactional CSV and Excel imports"
```

---

### Task 4: Implement synthetic-fixture OCR for Alipay and Tonghuashun

**Files:**
- Create: `engine/src/fundlens_engine/ocr/backend.py`
- Create: `engine/src/fundlens_engine/ocr/paddle_backend.py`
- Create: `engine/src/fundlens_engine/ocr/alipay_parser.py`
- Create: `engine/src/fundlens_engine/ocr/ths_parser.py`
- Create: `engine/src/fundlens_engine/ocr/service.py`
- Create: `engine/tools/generate_synthetic_ocr_fixtures.py`
- Create: `engine/tests/fixtures/ocr/alipay_synthetic.png`
- Create: `engine/tests/fixtures/ocr/ths_synthetic.png`
- Create: `engine/tests/test_alipay_parser.py`
- Create: `engine/tests/test_ths_parser.py`
- Create: `engine/tests/test_ocr_service.py`

**Interfaces:**
- Consumes: absolute paths selected by the user and an explicit template hint `alipay|ths`.
- Produces: normalized draft rows plus field-level `OcrField` values and blocking issues.

- [x] **Step 1: Generate redacted fixtures and write failing parser tests**

The generator must create images from blank canvases with `Pillow`, system CJK font lookup, fictional product names and fictional values. It must not read the user's reference images.

```python
def test_alipay_maps_holding_and_cumulative_profit(fake_ocr_tokens) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    assert rows[0].fields["current_value"].raw_text == "78,347.87"
    assert rows[0].fields["holding_profit"].raw_text == "+428.96"
    assert rows[0].fields["cumulative_profit"].raw_text == "+888.88"

def test_ths_ignores_chart_and_requires_sign_confidence(fake_ocr_tokens) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    assert len(rows) == 3
    assert "chart_label" not in rows[0].fields
    assert rows[0].fields["holding_profit"].confidence >= 0.90
```

- [x] **Step 2: Run parser tests and confirm failure**

Run: `python -m pytest engine/tests/test_alipay_parser.py engine/tests/test_ths_parser.py -q`

Expected: FAIL because OCR parsers do not exist.

- [x] **Step 3: Implement an injectable OCR backend and template parsers**

```python
from dataclasses import dataclass
from typing import Protocol

@dataclass(frozen=True)
class OcrToken:
    text: str
    confidence: float
    box: tuple[int, int, int, int]

class OcrBackend(Protocol):
    def recognize(self, image_path: str) -> list[OcrToken]: ...
```

`PaddleBackend` owns a single lazy `PaddleOCR` instance. Template parsers group tokens into holdings by vertical bands, normalize full-width punctuation, retain raw text, and never infer sign from color. Required blocking thresholds are product name `<0.85`, amount/profit/sign `<0.90`; noncritical tags use `<0.70` warning. Crop rectangles are the union of contributing token boxes.

After parsing, the normalization service applies these exact financial checks:

```text
支付宝推算成本 = 当前金额 − 持有收益
同花顺推算成本 = 市值 − 盈亏金额
同花顺参考成本 = 成本价 × 持仓数量
容差 = max(CNY 1.00, abs(同花顺推算成本) × 0.001)
```

If the two Tonghuashun costs differ beyond tolerance, return blocking issue `import.cost_mismatch`; never silently choose one. Keep `cumulative_profit` separate from `holding_profit`.

- [x] **Step 4: Register the RPC method and run OCR acceptance**

`ocr.parse_screenshots` validates every path is a regular image chosen in the request, invokes the selected parser, returns one page index per field, and deletes no source file. Add `HANDLERS["ocr.parse_screenshots"]` in `server.py`.

Run:

```powershell
python engine/tools/generate_synthetic_ocr_fixtures.py
python -m pytest engine/tests/test_alipay_parser.py engine/tests/test_ths_parser.py engine/tests/test_ocr_service.py -q
```

Expected: exact names, values, signs and row counts pass; status bar, account suffix, charts and navigation labels are absent from output.

- [x] **Step 5: Commit OCR without real screenshots**

Run: `git grep -n "9371\|东方添益债券" -- engine || exit 0`

Expected: no match to user reference data.

```bash
git add engine/src/fundlens_engine/ocr engine/tools engine/tests
git commit -m "feat(ocr): parse synthetic Alipay and THS holdings"
```

---

### Task 5: Add product candidates and free quote providers

**Files:**
- Create: `engine/src/fundlens_engine/products/normalization.py`
- Create: `engine/src/fundlens_engine/products/matcher.py`
- Create: `engine/src/fundlens_engine/market/provider.py`
- Create: `engine/src/fundlens_engine/market/baostock_provider.py`
- Create: `engine/src/fundlens_engine/market/akshare_provider.py`
- Create: `engine/src/fundlens_engine/market/service.py`
- Test: `engine/tests/test_product_matcher.py`
- Test: `engine/tests/test_market_service.py`

**Interfaces:**
- Produces: ranked candidates with code/name/type/class/confidence/reason.
- Produces: `QuoteResult` per requested code; partial provider failure does not fail the entire batch.

- [x] **Step 1: Write failing matcher and provider fallback tests**

```python
def test_matcher_returns_candidates_without_auto_selection(catalog) -> None:
    result = match_candidates("脱敏沪深300联接", catalog)
    assert result[0].product_code == "000001"
    assert all(candidate.selected is False for candidate in result)

def test_quote_batch_preserves_partial_success(fake_baostock, fake_akshare) -> None:
    fake_akshare.fail_for("F0002")
    result = MarketService(fake_baostock, fake_akshare).fetch([stock("600000"), fund("F0002")])
    assert result[0].status == "fresh"
    assert result[1].status == "failed"
    assert result[1].value is None
```

- [x] **Step 2: Run tests and confirm failure**

Run: `python -m pytest engine/tests/test_product_matcher.py engine/tests/test_market_service.py -q`

Expected: FAIL because matcher/providers do not exist.

- [x] **Step 3: Implement deterministic candidates and provider ports**

```python
from typing import Protocol
from ..models import QuoteResult

class MarketDataProvider(Protocol):
    name: str
    def fetch(self, items: list[dict[str, str]]) -> list[QuoteResult]: ...
```

Normalize whitespace, full-width punctuation, share-class suffixes and common platform decorations, but preserve the original name. Rank exact code > exact normalized name > token similarity. Return at most five candidates; never set `selected=True` in engine output.

BaoStock handles A-share and exchange ETF/LOF/REIT closing quotes; AKShare handles public fund NAV and metadata. Adapters convert dates to ISO `YYYY-MM-DD` and decimals to strings, impose timeouts/rate limits, and translate upstream exceptions into stable codes such as `market.provider_unavailable`.

- [x] **Step 4: Register RPC methods and test with fakes**

Register `product.match_candidates` and `market.fetch_quotes`. No automated test may call live services. Add an opt-in `@pytest.mark.live` smoke test excluded from default runs and documented as `python -m pytest -m live`.

Run: `python -m pytest engine/tests -m "not live" -q && python -m ruff check engine && python -m mypy engine/src`

Expected: PASS without network access.

- [x] **Step 5: Commit market adapters**

```bash
git add engine/src/fundlens_engine/products engine/src/fundlens_engine/market engine/tests engine/src/fundlens_engine/server.py
git commit -m "feat(engine): add product matching and free quotes"
```

---

### Task 6: Apply quote refresh rules and degradation in Dart

**Files:**
- Create: `apps/fundlens_windows/lib/market/quote.dart`
- Create: `apps/fundlens_windows/lib/market/quote_refresh_service.dart`
- Create: `apps/fundlens_windows/lib/market/daily_refresh_policy.dart`
- Test: `apps/fundlens_windows/test/market/quote_refresh_service_test.dart`
- Test: `apps/fundlens_windows/test/market/daily_refresh_policy_test.dart`

**Interfaces:**
- Consumes: `DataEngineClient.market.fetch_quotes`, `HoldingRepository`, `quote_cache`, clock.
- Produces: `QuoteRefreshReport(updated, retained, failed, issues)`.

- [ ] **Step 1: Write failing valuation rule tests**

```dart
test('quote updates value only when code and quantity are confirmed', () async {
  final report = await service.refresh([holdingWith(code: '510300', quantity: '2100')]);
  expect(report.updated.single.currentValue.canonical, '9355.5');
});

test('Alipay amount-only holding keeps confirmed value', () async {
  final original = holdingWith(code: '000001', quantity: null, value: '78347.87');
  final report = await service.refresh([original]);
  expect(report.retained.single.currentValue.canonical, '78347.87');
  expect(report.retained.single.currentPrice?.canonical, quoteValue);
});

test('failed quote retains last valid value and becomes stale', () async {
  final report = await service.refresh([cachedHolding], engineFailure: true);
  expect(report.failed.single.currentValue, cachedHolding.currentValue);
  expect(report.issues.single.code, 'market.quote_stale');
});
```

- [ ] **Step 2: Run tests and confirm failure**

Run: `flutter test apps/fundlens_windows/test/market`

Expected: FAIL because refresh service does not exist.

- [ ] **Step 3: Implement refresh and daily policy**

`QuoteRefreshService` batches requests by provider, writes quote cache before applying updates, rejects zero/negative or implausibly dated quotes, and updates holdings in one transaction. Recompute `currentValue = quantity × quote` only when both are non-null and field provenance is confirmed. Preserve manual gold, deposits and cash values.

```dart
final class DailyRefreshPolicy {
  const DailyRefreshPolicy(this.clock);
  final DateTime Function() clock;
  bool shouldRun(DateTime? lastAttemptUtc) {
    if (lastAttemptUtc == null) return true;
    final now = clock().toUtc();
    return now.year != lastAttemptUtc.year || now.month != lastAttemptUtc.month || now.day != lastAttemptUtc.day;
  }
}
```

- [ ] **Step 4: Run the full Phase 2 suite**

Run:

```powershell
dart test packages/fundlens_core
flutter test apps/fundlens_windows
python -m pytest engine/tests -m "not live" -q
python -m ruff check engine
python -m mypy engine/src
```

Expected: PASS. Kill the fake engine mid-request and verify the app reports degraded mode after one restart.

- [ ] **Step 5: Commit quote application**

```bash
git add apps/fundlens_windows/lib/market apps/fundlens_windows/test/market
git commit -m "feat(market): refresh daily quotes with safe fallback"
```

## Phase 2 Completion Gate

- [ ] Schema fixtures validate in both Python and Dart contract tests.
- [ ] Engine stdout contains only line-delimited JSON-RPC.
- [ ] Partial/full imports, ambiguous matches and transaction rollback are covered.
- [ ] Synthetic OCR recognizes every specified field and ignores chart/account/navigation regions.
- [ ] Live providers are isolated behind fakes in default tests.
- [ ] Amount-only Alipay holdings never change value from NAV alone.
- [ ] Engine crash, timeout, cancellation and stale quote behaviors are deterministic.
