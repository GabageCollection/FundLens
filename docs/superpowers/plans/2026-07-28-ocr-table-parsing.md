# OCR 表格解析重构（表头锚定 + 列归属）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重写支付宝与同花顺截图 parser，用"表头锚定列坐标 + 行状态机"替代逐行顺序解析，修复字段错位/串行与图表噪声混入。

**Architecture:** `layout.py` 新增 `ColumnLayout`/`anchor_columns`（用表头 token 的 x 中心切分列区间）并扩充噪声词表；两个 parser 改为先锚定表头、再按状态机把 token 归入语义列。同花顺每个持仓两行合并；图表噪声通过"整行剔除最新行情行 + 严格的行模式门禁"消除。字段名与 Dart 侧契约不变。

**Tech Stack:** Python 3、`engine/src/fundlens_engine/ocr/`、pytest、ruff、mypy。

**Spec:** `docs/superpowers/specs/2026-07-28-ocr-table-parsing-design.md`

## Global Constraints

- 分支：`feat/phase-2-ocr-table-parsing`（不在 master 直接提交）。
- 测试只用脱敏合成 token，真实用户截图不进仓库。
- 符号只来自显式 +/− 字符；唯一例外：同花顺 `holding_profit`/`profit_ratio` 无符号视为正数 + warning `ocr.sign_assumed_positive`。
- 不识别支付宝日收益/占比、同花顺可用数量；Dart 侧字段契约不变。
- parser 不抛异常，错误一律通过 `DraftRow.issues` 表达。
- 每个任务完成跑 `python -m pytest engine/tests -q`；收尾跑 `python -m ruff check engine` 和 `python -m mypy engine/src`。
- 所有命令在仓库根目录 `D:\cc project\FundLens` 执行；Python 命令前缀 `engine\.venv\Scripts\python.exe -m ...`（Windows venv）。以下简写 `pytest` 等均指该 venv。

## 现有代码要点（执行者须知）

- `engine/src/fundlens_engine/ocr/backend.py`：`OcrToken(text, confidence, box=(x,y,w,h))`、`OcrIssue(code, field, severity, message)`、`DraftRow(page_index, fields, issues, normalized)`。
- `engine/src/fundlens_engine/models.py`：`OcrField(name, raw_text, confidence, page_index, crop)`。
- `engine/src/fundlens_engine/ocr/layout.py`：已有 `normalize_text/is_money/is_signed/is_ratio/is_noise/group_into_lines/union_crop/make_field`，本计划在末尾追加新工具。
- `engine/tests/conftest.py`：`tok(text, conf, x, y, w, h)` 工厂 + `FakeOcrTokens` fixture（`alipay_page()`/`ths_page()`）。
- `engine/src/fundlens_engine/ocr/service.py` 调用 `parse_alipay(tokens, page_index)` / `parse_ths(tokens, page_index)`，签名不变。

---

### Task 1: layout 层扩展（ColumnLayout / anchor_columns / 噪声词）

**Files:**
- Modify: `engine/src/fundlens_engine/ocr/layout.py`
- Test: `engine/tests/test_layout.py`（新建）

**Interfaces:**
- Produces（Task 3/5 依赖）：
  - `ColumnLayout(names: list[str], boundaries: list[tuple[int, int]])`，方法 `column_of(token: OcrToken) -> str | None`
  - `anchor_columns(lines: list[list[OcrToken]], anchors: dict[str, set[str]]) -> tuple[ColumnLayout, int] | None`
  - `layout_unknown_row(page_index: int, detail: str) -> DraftRow`
  - `is_noise` 新增过滤：`HH:MM` 时间戳、`最新` 开头、`额:`/`换:` 模式、新增导航词

- [ ] **Step 1: 写失败测试 `engine/tests/test_layout.py`**

```python
"""Tests for header-anchored column layout and noise filtering."""

from fundlens_engine.ocr.layout import (
    ColumnLayout,
    anchor_columns,
    group_into_lines,
    is_noise,
    layout_unknown_row,
)

from conftest import tok

ANCHORS = {
    "value": {"名称/金额", "名称"},
    "daily": {"日收益"},
    "holding": {"持有收益"},
    "cumulative": {"累计收益"},
}


def _header_lines() -> list[list]:
    tokens = [
        tok("名称/金额", 0.97, 40, 160, 120, 26),
        tok("日收益", 0.97, 300, 160, 90, 26),
        tok("持有收益", 0.97, 460, 160, 110, 26),
        tok("累计收益", 0.97, 650, 160, 110, 26),
    ]
    return group_into_lines(tokens)


def test_anchor_columns_builds_boundaries_from_header_centers() -> None:
    lines = _header_lines()
    anchored = anchor_columns(lines, ANCHORS)
    assert anchored is not None
    layout, header_index = anchored
    assert header_index == 0
    assert layout.names == ["value", "daily", "holding", "cumulative"]
    # 列中心：100 / 345 / 515 / 705；边界为中点
    assert layout.column_of(tok("x", 0.9, 40, 500, 180, 30)) == "value"       # center 130
    assert layout.column_of(tok("x", 0.9, 300, 500, 80, 30)) == "daily"       # center 340
    assert layout.column_of(tok("x", 0.9, 460, 500, 110, 30)) == "holding"    # center 515
    assert layout.column_of(tok("x", 0.9, 650, 500, 110, 30)) == "cumulative"  # center 705


def test_anchor_columns_returns_none_when_header_missing() -> None:
    lines = group_into_lines([tok("一些文字", 0.9, 40, 200, 200, 30)])
    assert anchor_columns(lines, ANCHORS) is None


def test_anchor_columns_accepts_alternative_header_texts() -> None:
    lines = group_into_lines(
        [
            tok("名称", 0.97, 40, 160, 120, 26),
            tok("日收益", 0.97, 300, 160, 90, 26),
            tok("持有收益", 0.97, 460, 160, 110, 26),
            tok("累计收益", 0.97, 650, 160, 110, 26),
        ]
    )
    assert anchor_columns(lines, ANCHORS) is not None


def test_is_noise_filters_timestamps_quote_ticks_and_new_nav_words() -> None:
    for text in ("08:04", "9:41", "09:30", "15:00", "最新:2.223", "最新：2.223 额:1.90亿", "额:1.90亿", "换:1.90%", "买入", "卖出", "撤单", "查询", "持仓股", "全部", "全部持有", "金额/占比排序"):
        assert is_noise(tok(text, 0.95, 40, 500, 120, 26)), text


def test_is_noise_keeps_holding_content() -> None:
    for text in ("脱敏安心债券A", "78,347.87", "+428.96", "持有收益", "HS300ETF", "-3.552%"):
        assert not is_noise(tok(text, 0.95, 40, 500, 120, 26)), text


def test_layout_unknown_row_is_blocking_without_fields() -> None:
    row = layout_unknown_row(0, "测试版式")
    assert row.fields == {}
    assert len(row.issues) == 1
    issue = row.issues[0]
    assert issue.code == "ocr.layout_unknown"
    assert issue.severity == "blocking"
    assert "测试版式" in issue.message
```

- [ ] **Step 2: 运行确认失败**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_layout.py -q`
Expected: FAIL（`ImportError: cannot import name 'ColumnLayout'` 等）

- [ ] **Step 3: 实现 layout.py 扩展**

在 `engine/src/fundlens_engine/ocr/layout.py` 末尾追加（顶部 import 区新增 `from dataclasses import dataclass` 和 `from .backend import DraftRow, OcrIssue`）：

```python
TIME_RE = re.compile(r"^\d{1,2}:\d{2}$")

QUOTE_TICK_RE = re.compile(r"(最新|额|换)[:：]")
```

`NAV_LABELS` 集合追加成员：`"买入", "卖出", "撤单", "查询", "持仓股", "全部", "全部持有", "金额/占比排序", "资讯"`。

`is_noise` 函数在 `text = token.text.strip()` 之后、返回前追加两条规则：

```python
    if TIME_RE.match(normalize_text(text)):
        return True
    if QUOTE_TICK_RE.search(text):
        return True
```

文件末尾追加：

```python
@dataclass
class ColumnLayout:
    """表头锚定的列区间。boundaries[i] = [left, right) 对应 names[i]。"""

    names: list[str]
    boundaries: list[tuple[int, int]]

    def column_of(self, token: OcrToken) -> str | None:
        """按 token 中心 x 返回所属列名；落不进任何列返回 None。"""
        center = token.box[0] + token.box[2] // 2
        for name, (left, right) in zip(self.names, self.boundaries):
            if left <= center < right:
                return name
        return None


def anchor_columns(
    lines: list[list[OcrToken]], anchors: dict[str, set[str]]
) -> tuple[ColumnLayout, int] | None:
    """找到包含全部锚点组的表头行并构建列区间。

    anchors: 列语义名 -> 可接受的表头文本集合（任取其一）。
    返回 (列布局, 表头行下标)；找不到返回 None。
    """
    for index, line in enumerate(lines):
        texts = {t.text.strip() for t in line}
        if not all(texts & accepted for accepted in anchors.values()):
            continue
        centers: list[tuple[str, int]] = []
        for name, accepted in anchors.items():
            token = next(t for t in line if t.text.strip() in accepted)
            centers.append((name, token.box[0] + token.box[2] // 2))
        centers.sort(key=lambda item: item[1])
        names = [name for name, _ in centers]
        xs = [x for _, x in centers]
        boundaries: list[tuple[int, int]] = []
        for i, x in enumerate(xs):
            left = 0 if i == 0 else (xs[i - 1] + x) // 2
            right = 1 << 30 if i == len(xs) - 1 else (x + xs[i + 1]) // 2
            boundaries.append((left, right))
        return ColumnLayout(names, boundaries), index
    return None


def layout_unknown_row(page_index: int, detail: str) -> DraftRow:
    """页级 blocking 行：表头缺失时占位，字段为空，只带 layout_unknown issue。"""
    row = DraftRow(page_index=page_index)
    row.issues.append(
        OcrIssue(
            code="ocr.layout_unknown",
            field="",
            severity="blocking",
            message=f"未找到表头锚点，版式不支持：{detail}",
        )
    )
    return row
```

- [ ] **Step 4: 运行确认通过**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_layout.py -q`
Expected: PASS（6 passed）

- [ ] **Step 5: 全量回归确认无破坏**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests -q`
Expected: 全绿（旧 fixture 不受影响）

- [ ] **Step 6: Commit**

```bash
git add engine/src/fundlens_engine/ocr/layout.py engine/tests/test_layout.py
git commit -m "feat(engine): header-anchored column layout and extended OCR noise filter"
```

---

### Task 2: 支付宝合成 fixture 与测试重写（失败测试先行）

**Files:**
- Modify: `engine/tests/conftest.py`（替换 `alipay_page` 方法）
- Modify: `engine/tests/test_alipay_parser.py`（整体重写）
- Modify: `engine/tests/test_ocr_service.py`（重写 `test_normalization_handles_full_width_punctuation`）

**Interfaces:**
- Consumes: Task 1 的 `anchor_columns/is_noise`（fixture 坐标按真实截图版式构造：表头列中心 100/345/515/705）。
- Produces: 新 fixture 布局供 Task 3 实现对照；`parse_alipay` 签名不变。

- [ ] **Step 1: 替换 `conftest.py` 的 `alipay_page` 方法**

```python
    def alipay_page(self) -> list[OcrToken]:
        """镜像支付宝「全部持有」真实版式：表头 + 每持仓四行（名称/标签/数值/占比）。"""
        return [
            # 状态栏（忽略）。
            tok("08:04", 0.99, 20, 12, 60, 24),
            tok("100%", 0.99, 700, 12, 70, 24),
            # 标题与排序控件（忽略）。
            tok("全部持有", 0.99, 120, 60, 130, 30),
            tok("收益明细", 0.99, 330, 60, 110, 30),
            tok("全部", 0.95, 40, 110, 60, 26),
            tok("金额/占比排序", 0.95, 400, 110, 180, 26),
            # 表头（列锚点）：列中心 100 / 345 / 515 / 705。
            tok("名称/金额", 0.97, 40, 160, 120, 26),
            tok("日收益", 0.97, 300, 160, 90, 26),
            tok("持有收益", 0.97, 460, 160, 110, 26),
            tok("累计收益", 0.97, 650, 160, 110, 26),
            # 持仓 1：名称 → 标签 → 数值 → 占比。
            tok("脱敏安心债券A", 0.97, 40, 220, 200, 32),
            tok("基金", 0.92, 40, 270, 60, 24),
            tok("稳健理财", 0.92, 120, 270, 110, 24),
            tok("78,347.87", 0.96, 40, 320, 180, 34),
            tok("0.00", 0.95, 300, 320, 80, 30),
            tok("+428.96", 0.95, 460, 320, 110, 30),
            tok("+888.88", 0.95, 650, 320, 110, 30),
            tok("占比 34.68%", 0.93, 40, 370, 130, 24),
            tok("+0.67%", 0.93, 460, 370, 90, 24),
            # 持仓 2：负收益，无标签行。
            tok("脱敏远山混合C", 0.97, 40, 430, 200, 32),
            tok("12,000.00", 0.96, 40, 480, 180, 34),
            tok("0.00", 0.95, 300, 480, 80, 30),
            tok("-156.20", 0.95, 460, 480, 110, 30),
            tok("+45.00", 0.95, 650, 480, 110, 30),
            tok("占比 5.30%", 0.93, 40, 530, 130, 24),
            # 底部导航（忽略）。
            tok("首页", 0.98, 60, 1200, 70, 26),
            tok("理财", 0.98, 300, 1200, 70, 26),
            tok("我的", 0.98, 560, 1200, 70, 26),
        ]
```

- [ ] **Step 2: 整体重写 `engine/tests/test_alipay_parser.py`**

```python
from fundlens_engine.ocr.alipay_parser import parse_alipay

from conftest import FakeOcrTokens, tok


def test_alipay_maps_columns_by_header_anchor(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    assert len(rows) == 2
    first = rows[0].fields
    assert first["product_name"].raw_text == "脱敏安心债券A"
    assert first["current_value"].raw_text == "78,347.87"
    assert first["holding_profit"].raw_text == "+428.96"
    assert first["cumulative_profit"].raw_text == "+888.88"
    assert "daily_profit" not in first  # 日收益列直接丢弃
    second = rows[1].fields
    assert second["product_name"].raw_text == "脱敏远山混合C"
    assert second["holding_profit"].raw_text == "-156.20"
    assert second["cumulative_profit"].raw_text == "+45.00"
    assert "platform_tags" not in second  # 第二持仓没有标签行


def test_alipay_column_ownership_survives_token_order_shuffle(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    """串行回归：数值行 token 顺序打乱，列坐标不变时字段归属不变。"""
    tokens = fake_ocr_tokens.alipay_page()
    numbers = [t for t in tokens if t.box[1] == 320]
    rest = [t for t in tokens if t.box[1] != 320]
    shuffled = rest + list(reversed(numbers))
    rows = parse_alipay(shuffled)
    first = rows[0].fields
    assert first["current_value"].raw_text == "78,347.87"
    assert first["holding_profit"].raw_text == "+428.96"
    assert first["cumulative_profit"].raw_text == "+888.88"


def test_alipay_ignores_ratio_line_status_bar_controls_and_navigation(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    all_text = " ".join(f.raw_text for r in rows for f in r.fields.values())
    for ignored in ("08:04", "100%", "首页", "我的", "占比", "+0.67%", "金额/占比排序", "全部持有", "全部"):
        assert ignored not in all_text, ignored
    # 日收益列不建模：任何字段都不得叫 daily_profit
    assert all("daily_profit" not in r.fields for r in rows)


def test_alipay_retains_raw_text_tags_and_union_crop(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    tags = rows[0].fields["platform_tags"]
    assert "稳健理财" in tags.raw_text
    assert tags.crop[0] <= 40
    assert rows[0].fields["current_value"].page_index == 0


def test_alipay_missing_header_yields_layout_unknown_blocking() -> None:
    tokens = [
        tok("脱敏安心债券A", 0.97, 40, 220, 200, 32),
        tok("78,347.87", 0.96, 40, 320, 180, 34),
    ]
    rows = parse_alipay(tokens)
    assert len(rows) == 1
    assert rows[0].fields == {}
    assert any(
        i.code == "ocr.layout_unknown" and i.severity == "blocking" for i in rows[0].issues
    )


def test_alipay_extra_money_token_in_column_is_warning_not_misfiled(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens.append(tok("+999.99", 0.95, 470, 320, 110, 30))  # 持有收益列多余碎块
    rows = parse_alipay(tokens)
    assert rows[0].fields["holding_profit"].raw_text == "+428.96"
    assert any(
        i.code == "ocr.extra_token" and i.severity == "warning" for i in rows[0].issues
    )


def test_alipay_low_confidence_name_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[10] = tok("脱敏安心债券A", 0.80, 40, 220, 200, 32)
    rows = parse_alipay(tokens)
    assert any(
        i.code == "ocr.low_confidence" and i.field == "product_name" and i.severity == "blocking"
        for i in rows[0].issues
    )


def test_alipay_low_confidence_amount_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[13] = tok("78,347.87", 0.85, 40, 320, 180, 34)
    rows = parse_alipay(tokens)
    assert any(
        i.code == "ocr.low_confidence" and i.field == "current_value" and i.severity == "blocking"
        for i in rows[0].issues
    )


def test_alipay_low_confidence_tags_are_warning_only(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[12] = tok("稳健理财", 0.60, 120, 270, 110, 24)
    rows = parse_alipay(tokens)
    tag_issues = [i for i in rows[0].issues if i.field == "platform_tags"]
    assert tag_issues and all(i.severity == "warning" for i in tag_issues)


def test_alipay_missing_profit_sign_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[15] = tok("428.96", 0.95, 460, 320, 110, 30)
    rows = parse_alipay(tokens)
    assert any(
        i.code == "ocr.sign_missing" and i.severity == "blocking" for i in rows[0].issues
    )


def test_alipay_missing_current_value_is_blocking() -> None:
    tokens = [
        tok("名称/金额", 0.97, 40, 160, 120, 26),
        tok("日收益", 0.97, 300, 160, 90, 26),
        tok("持有收益", 0.97, 460, 160, 110, 26),
        tok("累计收益", 0.97, 650, 160, 110, 26),
        tok("脱敏安心债券A", 0.97, 40, 220, 200, 32),
        tok("+428.96", 0.95, 460, 320, 110, 30),
        tok("+888.88", 0.95, 650, 320, 110, 30),
    ]
    rows = parse_alipay(tokens)
    assert any(
        i.code == "ocr.field_missing" and i.field == "current_value" and i.severity == "blocking"
        for i in rows[0].issues
    )
```

- [ ] **Step 3: 重写 `test_ocr_service.py` 中的 `test_normalization_handles_full_width_punctuation`**

```python
def test_normalization_handles_full_width_punctuation() -> None:
    tokens = [
        tok("名称/金额", 0.97, 40, 160, 120, 26),
        tok("日收益", 0.97, 300, 160, 90, 26),
        tok("持有收益", 0.97, 460, 160, 110, 26),
        tok("累计收益", 0.97, 650, 160, 110, 26),
        tok("脱敏安心债券A", 0.97, 40, 220, 200, 32),
        tok("７８，３４７．８７", 0.96, 40, 320, 180, 34),
        tok("＋４２８．９６", 0.95, 460, 320, 110, 30),
        tok("＋８８８．８８", 0.95, 650, 320, 110, 30),
    ]
    rows = parse_alipay(tokens)
    normalize_rows(rows, "alipay")
    assert rows[0].normalized["current_value"] == "78347.87"
    assert rows[0].normalized["derived_cost"] == "77918.91"
```

- [ ] **Step 4: 运行确认失败**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_alipay_parser.py engine/tests/test_ocr_service.py -q`
Expected: FAIL（旧 parser 对新版式产出错误结果/空 rows）

- [ ] **Step 5: Commit（测试先行）**

```bash
git add engine/tests/conftest.py engine/tests/test_alipay_parser.py engine/tests/test_ocr_service.py
git commit -m "test(engine): rewrite Alipay fixtures and parser tests for header-anchored layout"
```

---

### Task 3: 支付宝 parser 实现（状态机重写）

**Files:**
- Modify: `engine/src/fundlens_engine/ocr/alipay_parser.py`（整体重写）

**Interfaces:**
- Consumes: Task 1 的 `anchor_columns / ColumnLayout / layout_unknown_row / is_noise / is_money / is_ratio / is_signed / group_into_lines / make_field`。
- Produces: `parse_alipay(tokens: list[OcrToken], page_index: int = 0) -> list[DraftRow]`（签名不变）；模块级 `ANCHORS: dict[str, set[str]]`。

- [ ] **Step 1: 整体重写 `alipay_parser.py`**

```python
"""Alipay holdings parser: header-anchored columns + row state machine.

每个持仓固定四行结构：名称 → 标签（可缺）→ 数值（按列拆分）→ 占比（忽略）。
字段归属只看列区间，与行内 token 顺序无关。符号只来自显式 +/− 字符。
"""

from .backend import DraftRow, OcrIssue, OcrToken
from .layout import (
    ColumnLayout,
    anchor_columns,
    group_into_lines,
    is_money,
    is_noise,
    is_ratio,
    is_signed,
    layout_unknown_row,
    make_field,
)

ANCHORS = {
    "value": {"名称/金额", "名称"},
    "daily": {"日收益"},
    "holding": {"持有收益"},
    "cumulative": {"累计收益"},
}

REQUIRED_FIELDS = ("product_name", "current_value")
NAME_THRESHOLD = 0.85
AMOUNT_THRESHOLD = 0.90
TAG_THRESHOLD = 0.70

_NUMBER_SLOTS = {
    "value": "current_value",
    "holding": "holding_profit",
    "cumulative": "cumulative_profit",
}


def _assign_numbers(
    row: DraftRow, layout: ColumnLayout, line: list[OcrToken], page_index: int
) -> None:
    """把数值行的 money token 按列归入字段；日收益列与列外 token 丢弃。"""
    for token in (t for t in line if is_money(t.text)):
        field_name = _NUMBER_SLOTS.get(layout.column_of(token) or "")
        if field_name is None:
            continue
        if field_name in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.extra_token",
                    field=field_name,
                    severity="warning",
                    message=f"列内多余数字 token {token.text!r} 已忽略",
                )
            )
            continue
        row.fields[field_name] = make_field(field_name, [token], page_index)


def _add_confidence_issues(row: DraftRow) -> None:
    for name, field in row.fields.items():
        if name == "product_name":
            threshold, severity = NAME_THRESHOLD, "blocking"
        elif name == "platform_tags":
            threshold, severity = TAG_THRESHOLD, "warning"
        else:
            threshold, severity = AMOUNT_THRESHOLD, "blocking"
        if field.confidence < threshold:
            row.issues.append(
                OcrIssue(
                    code="ocr.low_confidence",
                    field=name,
                    severity=severity,  # type: ignore[arg-type]
                    message=(
                        f"field {name} confidence {field.confidence:.2f} "
                        f"below threshold {threshold:.2f}"
                    ),
                )
            )


def _finalize(row: DraftRow) -> None:
    for name in REQUIRED_FIELDS:
        if name not in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.field_missing",
                    field=name,
                    severity="blocking",
                    message=f"required field {name} missing",
                )
            )
    for name in ("holding_profit", "cumulative_profit"):
        field = row.fields.get(name)
        if field is not None and not is_signed(field.raw_text):
            row.issues.append(
                OcrIssue(
                    code="ocr.sign_missing",
                    field=name,
                    severity="blocking",
                    message=f"field {name} has no explicit +/− sign",
                )
            )
    _add_confidence_issues(row)


def parse_alipay(tokens: list[OcrToken], page_index: int = 0) -> list[DraftRow]:
    lines = group_into_lines(t for t in tokens if not is_noise(t))
    anchored = anchor_columns(lines, ANCHORS)
    if anchored is None:
        return [layout_unknown_row(page_index, "名称/金额、日收益、持有收益、累计收益")]
    layout, header_index = anchored

    rows: list[DraftRow] = []
    current: DraftRow | None = None
    state = "name"  # name -> tags -> numbers -> ratio -> name ...

    for line in lines[header_index + 1:]:
        money = [t for t in line if is_money(t.text)]
        texts = [t for t in line if not is_money(t.text) and not is_ratio(t.text)]
        ratio_line = any(t.text.strip().startswith("占比") for t in line)

        if state == "tags":
            if texts and not money and not ratio_line:
                assert current is not None
                current.fields["platform_tags"] = make_field("platform_tags", texts, page_index)
                continue
            state = "numbers"  # 标签行可缺

        if state == "numbers":
            if money:
                assert current is not None
                _assign_numbers(current, layout, line, page_index)
            state = "ratio"
            if money:
                continue

        # state 为 name 或 ratio：文本行开启新持仓，占比行与零散数字行忽略
        if texts and not money and not ratio_line:
            current = DraftRow(page_index=page_index)
            rows.append(current)
            current.fields["product_name"] = make_field("product_name", texts, page_index)
            state = "tags"

    for row in rows:
        _finalize(row)
    return rows
```

- [ ] **Step 2: 运行确认通过**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_alipay_parser.py engine/tests/test_ocr_service.py engine/tests/test_layout.py -q`
Expected: PASS

- [ ] **Step 3: 全量回归**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests -q`
Expected: 全绿

- [ ] **Step 4: Commit**

```bash
git add engine/src/fundlens_engine/ocr/alipay_parser.py
git commit -m "feat(engine): rewrite Alipay parser with header-anchored columns and row state machine"
```

---

### Task 4: 同花顺合成 fixture 与测试重写（失败测试先行）

**Files:**
- Modify: `engine/tests/conftest.py`（替换 `ths_page` 方法）
- Modify: `engine/tests/test_ths_parser.py`（整体重写）
- Modify: `engine/tests/test_ocr_service.py`（重写 `test_ths_cost_mismatch_is_blocking_and_never_silently_chosen` 的 token 定位方式）

**Interfaces:**
- Consumes: Task 1 工具；fixture 列中心：市值 75 / 盈亏 365 / 持仓·可用 595 / 成本·现价 785。
- Produces: `parse_ths` 签名不变；fixture 三行持仓的派生成本与参考成本在容差内一致（`derived_cost == cost_price × quantity` ± tolerance），第三持仓盈亏无符号。

- [ ] **Step 1: 替换 `conftest.py` 的 `ths_page` 方法**

```python
    def ths_page(self) -> list[OcrToken]:
        """镜像同花顺「持仓」真实版式：表头 + 每持仓两行 + 内嵌分时图噪声。"""
        tokens = [
            tok("08:03", 0.99, 20, 12, 60, 24),
            tok("100%", 0.99, 700, 12, 70, 24),
            tok("中国银河证券", 0.95, 300, 60, 160, 30),
            tok("**9371", 0.95, 340, 95, 90, 24),
            # 交易标签页（忽略）。
            tok("买入", 0.95, 60, 140, 60, 26),
            tok("卖出", 0.95, 200, 140, 60, 26),
            tok("撤单", 0.95, 340, 140, 60, 26),
            tok("持仓", 0.95, 480, 140, 60, 26),
            tok("查询", 0.95, 620, 140, 60, 26),
            tok("持仓股", 0.95, 40, 185, 90, 28),
            # 表头（列锚点）：列中心 75 / 365 / 595 / 785。
            tok("市值", 0.97, 40, 230, 70, 26),
            tok("盈亏", 0.97, 310, 230, 110, 26),
            tok("持仓/可用", 0.97, 540, 230, 110, 26),
            tok("成本/现价", 0.97, 730, 230, 110, 26),
        ]
        # (名称, 盈亏, 持仓, 成本, 市值, 盈亏%, 可用, 现价)
        # 数字自洽：derived_cost = 市值 − 盈亏 ≈ 成本 × 持仓
        holdings = [
            ("脱敏先锋股票", "+2,300.00", "1000", "53.700", "56,000.00", "+4.107%", "1000", "56.000"),
            ("脱敏稳利ETF", "-120.50", "10000", "2.3570", "23,450.00", "-0.511%", "10000", "2.3450"),
            ("脱敏标普ETF", "40.70", "3600", "1.879", "6,804.00", "0.602%", "3600", "1.890"),
        ]
        y = 290
        for name, profit, qty, cost, value, ratio, avail, last in holdings:
            # 第一行：名称 / 盈亏 / 持仓 / 成本。
            tokens += [
                tok(name, 0.96, 40, y, 160, 30),
                tok(profit, 0.95, 310, y, 110, 28),
                tok(qty, 0.95, 540, y, 90, 28),
                tok(cost, 0.95, 730, y, 90, 28),
            ]
            # 第二行：市值 / 盈亏% / 可用 / 现价。
            tokens += [
                tok(value, 0.96, 40, y + 40, 140, 30),
                tok(ratio, 0.93, 310, y + 40, 100, 26),
                tok(avail, 0.95, 540, y + 40, 90, 26),
                tok(last, 0.95, 730, y + 40, 90, 26),
            ]
            # 内嵌分时图噪声（必须整体剔除，不得进入任何字段）。
            tokens += [
                tok(f"最新:{last} {ratio} 额:1.90亿 换:1.90%", 0.90, 40, y + 85, 420, 22),
                tok("行情", 0.90, 500, y + 85, 60, 22),
                tok("2.430", 0.88, 40, y + 120, 70, 22),
                tok("7.74%", 0.88, 790, y + 120, 70, 22),
                tok("0.00%", 0.88, 790, y + 170, 70, 22),
                tok("2.081", 0.88, 40, y + 220, 70, 22),
                tok("-7.74%", 0.88, 790, y + 220, 80, 22),
                tok("09:30", 0.90, 40, y + 250, 60, 20),
                tok("11:30", 0.90, 380, y + 250, 60, 20),
                tok("15:00", 0.90, 750, y + 250, 60, 20),
            ]
            y += 330
        # 底部导航（忽略）。
        for j, label in enumerate(["首页", "行情", "自选", "交易", "资讯", "理财"]):
            tokens.append(tok(label, 0.98, 40 + j * 140, y + 20, 70, 26))
        return tokens
```

- [ ] **Step 2: 整体重写 `engine/tests/test_ths_parser.py`**

```python
from fundlens_engine.ocr.ths_parser import parse_ths

from conftest import FakeOcrTokens, tok


def test_ths_merges_two_lines_into_one_holding(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    assert len(rows) == 3
    first = rows[0].fields
    assert first["product_name"].raw_text == "脱敏先锋股票"
    assert first["current_value"].raw_text == "56,000.00"
    assert first["holding_profit"].raw_text == "+2,300.00"
    assert first["quantity"].raw_text == "1000"
    assert first["cost_price"].raw_text == "53.700"
    assert first["profit_ratio"].raw_text == "+4.107%"
    assert first["latest_price"].raw_text == "56.000"
    assert rows[1].fields["holding_profit"].raw_text == "-120.50"
    assert rows[2].fields["quantity"].raw_text == "3600"


def test_ths_chart_tokens_never_leak_into_fields(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    all_text = " ".join(f.raw_text for r in rows for f in r.fields.values())
    for junk in ("最新", "1.90亿", "2.430", "7.74%", "0.00%", "2.081", "09:30", "11:30", "15:00", "行情"):
        assert junk not in all_text, junk


def test_ths_unsigned_profit_assumed_positive_with_warning(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    third = rows[2]
    assert third.fields["holding_profit"].raw_text == "40.70"
    assert third.fields["profit_ratio"].raw_text == "0.602%"
    assumed = [i for i in third.issues if i.code == "ocr.sign_assumed_positive"]
    assert assumed and all(i.severity == "warning" for i in assumed)
    assert {i.field for i in assumed} == {"holding_profit", "profit_ratio"}
    # 带显式符号的持仓不产生该 warning
    assert not [i for i in rows[0].issues if i.code == "ocr.sign_assumed_positive"]


def test_ths_ignores_status_bar_tabs_account_and_navigation(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    names = [r.fields["product_name"].raw_text for r in rows]
    assert names == ["脱敏先锋股票", "脱敏稳利ETF", "脱敏标普ETF"]
    all_text = " ".join(f.raw_text for r in rows for f in r.fields.values())
    for ignored in ("08:03", "100%", "买入", "卖出", "撤单", "查询", "持仓股", "首页", "自选", "交易", "资讯", "**9371", "中国银河证券"):
        assert ignored not in all_text, ignored


def test_ths_column_ownership_survives_token_order_shuffle(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    """串行回归：第一行 token 顺序打乱，列坐标不变时字段归属不变。"""
    tokens = fake_ocr_tokens.ths_page()
    line1 = [t for t in tokens if t.box[1] == 290]
    rest = [t for t in tokens if t.box[1] != 290]
    shuffled = rest + list(reversed(line1))
    rows = parse_ths(shuffled)
    first = rows[0].fields
    assert first["product_name"].raw_text == "脱敏先锋股票"
    assert first["holding_profit"].raw_text == "+2,300.00"
    assert first["quantity"].raw_text == "1000"
    assert first["cost_price"].raw_text == "53.700"


def test_ths_missing_second_line_is_blocking_but_keeps_next_holding() -> None:
    header = [
        tok("市值", 0.97, 40, 230, 70, 26),
        tok("盈亏", 0.97, 310, 230, 110, 26),
        tok("持仓/可用", 0.97, 540, 230, 110, 26),
        tok("成本/现价", 0.97, 730, 230, 110, 26),
    ]
    tokens = header + [
        # 持仓 A：只有第一行。
        tok("脱敏先锋股票", 0.96, 40, 290, 160, 30),
        tok("+2,300.00", 0.95, 310, 290, 110, 28),
        tok("1000", 0.95, 540, 290, 90, 28),
        tok("53.700", 0.95, 730, 290, 90, 28),
        # 持仓 B：两行齐全。
        tok("脱敏稳利ETF", 0.96, 40, 400, 160, 30),
        tok("-120.50", 0.95, 310, 400, 110, 28),
        tok("10000", 0.95, 540, 400, 90, 28),
        tok("2.3570", 0.95, 730, 400, 90, 28),
        tok("23,450.00", 0.96, 40, 440, 140, 30),
        tok("-0.511%", 0.93, 310, 440, 100, 26),
        tok("10000", 0.95, 540, 440, 90, 26),
        tok("2.3450", 0.95, 730, 440, 90, 26),
    ]
    rows = parse_ths(tokens)
    assert len(rows) == 2
    assert any(
        i.code == "ocr.field_missing" and i.field == "current_value" and i.severity == "blocking"
        for i in rows[0].issues
    )
    assert rows[1].fields["current_value"].raw_text == "23,450.00"


def test_ths_missing_header_yields_layout_unknown_blocking() -> None:
    tokens = [
        tok("脱敏先锋股票", 0.96, 40, 290, 160, 30),
        tok("56,000.00", 0.96, 40, 330, 140, 30),
    ]
    rows = parse_ths(tokens)
    assert len(rows) == 1
    assert rows[0].fields == {}
    assert any(
        i.code == "ocr.layout_unknown" and i.severity == "blocking" for i in rows[0].issues
    )


def test_ths_low_confidence_profit_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.ths_page()
    tokens[15] = tok("+2,300.00", 0.85, 310, 290, 110, 28)
    rows = parse_ths(tokens)
    assert any(
        i.code == "ocr.low_confidence" and i.field == "holding_profit" and i.severity == "blocking"
        for i in rows[0].issues
    )


def test_ths_low_confidence_ratio_is_warning_only(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.ths_page()
    tokens[19] = tok("+4.107%", 0.60, 310, 330, 100, 26)
    rows = parse_ths(tokens)
    ratio_issues = [i for i in rows[0].issues if i.field == "profit_ratio"]
    assert ratio_issues and all(i.severity == "warning" for i in ratio_issues)


def test_ths_missing_quantity_is_blocking() -> None:
    tokens = [
        tok("市值", 0.97, 40, 230, 70, 26),
        tok("盈亏", 0.97, 310, 230, 110, 26),
        tok("持仓/可用", 0.97, 540, 230, 110, 26),
        tok("成本/现价", 0.97, 730, 230, 110, 26),
        tok("脱敏先锋股票", 0.96, 40, 290, 160, 30),
        tok("+2,300.00", 0.95, 310, 290, 110, 28),
        tok("53.700", 0.95, 730, 290, 90, 28),
        tok("56,000.00", 0.96, 40, 330, 140, 30),
        tok("+4.107%", 0.93, 310, 330, 100, 26),
        tok("1000", 0.95, 540, 330, 90, 26),
        tok("56.000", 0.95, 730, 330, 90, 26),
    ]
    rows = parse_ths(tokens)
    assert any(
        i.code == "ocr.field_missing" and i.field == "quantity" and i.severity == "blocking"
        for i in rows[0].issues
    )
```

- [ ] **Step 3: 重写 `test_ocr_service.py` 的成本不一致测试（按文本定位 token）**

```python
def test_ths_cost_mismatch_is_blocking_and_never_silently_chosen(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    tokens = fake_ocr_tokens.ths_page()
    index = next(i for i, t in enumerate(tokens) if t.text == "53.700")
    tokens[index] = tok("60.000", 0.95, 730, 290, 90, 28)  # 成本价与 市值−盈亏 不一致
    rows = parse_ths(tokens)
    normalize_rows(rows, "ths")
    issues = [i for i in rows[0].issues if i.code == "import.cost_mismatch"]
    assert len(issues) == 1
    assert issues[0].severity == "blocking"
    # 两个候选成本都保留在 normalized 输出中，不静默取舍
    assert rows[0].normalized["derived_cost"] == "53700.00"
    assert rows[0].normalized["reference_cost"] == "60000.000"
```

- [ ] **Step 4: 运行确认失败**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_ths_parser.py engine/tests/test_ocr_service.py -q`
Expected: FAIL（旧 parser 对新版式产出错误结果）

- [ ] **Step 5: Commit（测试先行）**

```bash
git add engine/tests/conftest.py engine/tests/test_ths_parser.py engine/tests/test_ocr_service.py
git commit -m "test(engine): rewrite Tonghuashun fixtures and parser tests for two-line layout with chart noise"
```

---

### Task 5: 同花顺 parser 实现（两行合并状态机）

**Files:**
- Modify: `engine/src/fundlens_engine/ocr/ths_parser.py`（整体重写）

**Interfaces:**
- Consumes: Task 1 工具（`anchor_columns / ColumnLayout / layout_unknown_row / is_noise / is_money / is_ratio / is_signed / group_into_lines / make_field`）。
- Produces: `parse_ths(tokens, page_index=0) -> list[DraftRow]`（签名不变）；字段：`product_name / current_value / holding_profit / profit_ratio / cost_price / quantity / latest_price`；issue 码 `ocr.sign_assumed_positive`（warning）、`ocr.layout_unknown`（blocking）。

**设计要点（图表噪声消除）**：先用 `_drop_quote_lines` 把"最新：..."锚点所在整行剔除；之后状态机门禁保证图表残片不被采信——第一行必须"首列有文本 token"，第二行必须"市值列有 money 且盈亏列有 ratio"。坐标轴价格行（money 在市值列、ratio 在成本列）和行情残行都不满足门禁。

- [ ] **Step 1: 整体重写 `ths_parser.py`**

```python
"""Tonghuashun (同花顺) holdings parser: header-anchored columns + two-line merge.

每个持仓两行：第一行 名称/盈亏/持仓/成本，第二行 市值/盈亏%/可用/现价。
内嵌分时图噪声通过整行剔除「最新」行情行与严格的行模式门禁消除。
无符号的盈亏/盈亏% 按列语义视为正数并附 warning，由人工确认把关。
"""

from .backend import DraftRow, OcrIssue, OcrToken
from .layout import (
    ColumnLayout,
    anchor_columns,
    group_into_lines,
    is_money,
    is_noise,
    is_ratio,
    is_signed,
    layout_unknown_row,
    make_field,
)

ANCHORS = {
    "value": {"市值"},
    "profit": {"盈亏"},
    "quantity": {"持仓/可用", "持仓"},
    "cost": {"成本/现价", "成本"},
}

REQUIRED_FIELDS = ("product_name", "current_value", "holding_profit", "cost_price", "quantity")
OPTIONAL_FIELDS = ("profit_ratio", "latest_price")

NAME_THRESHOLD = 0.85
AMOUNT_THRESHOLD = 0.90
RATIO_THRESHOLD = 0.70

_LINE1_SLOTS = {"profit": "holding_profit", "quantity": "quantity", "cost": "cost_price"}


def _drop_quote_lines(tokens: list[OcrToken], y_tolerance: int = 18) -> list[OcrToken]:
    """剔除「最新:…」行情摘要锚点所在的整行（含同行的 额/换/行情 碎块）。"""
    anchors = [t for t in tokens if t.text.strip().startswith("最新")]
    if not anchors:
        return tokens
    centers = [t.box[1] + t.box[3] // 2 for t in anchors]
    return [
        t
        for t in tokens
        if all(abs(t.box[1] + t.box[3] // 2 - c) > y_tolerance for c in centers)
    ]


def _name_tokens(layout: ColumnLayout, line: list[OcrToken]) -> list[OcrToken]:
    return [
        t
        for t in line
        if layout.column_of(t) == "value" and not is_money(t.text) and not is_ratio(t.text)
    ]


def _assign_line1(
    row: DraftRow, layout: ColumnLayout, line: list[OcrToken], page_index: int
) -> None:
    for token in (t for t in line if is_money(t.text)):
        field_name = _LINE1_SLOTS.get(layout.column_of(token) or "")
        if field_name is None or field_name in row.fields:
            continue
        row.fields[field_name] = make_field(field_name, [token], page_index)


def _assign_line2(
    row: DraftRow, layout: ColumnLayout, line: list[OcrToken], page_index: int
) -> None:
    for token in line:
        column = layout.column_of(token)
        if column == "value" and is_money(token.text) and "current_value" not in row.fields:
            row.fields["current_value"] = make_field("current_value", [token], page_index)
        elif column == "profit" and is_ratio(token.text) and "profit_ratio" not in row.fields:
            row.fields["profit_ratio"] = make_field("profit_ratio", [token], page_index)
        elif column == "cost" and is_money(token.text) and "latest_price" not in row.fields:
            row.fields["latest_price"] = make_field("latest_price", [token], page_index)
        # quantity 列第二行是可用数量，丢弃


def _finalize(row: DraftRow) -> None:
    for name in REQUIRED_FIELDS:
        if name not in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.field_missing",
                    field=name,
                    severity="blocking",
                    message=f"required field {name} missing",
                )
            )
    for name in OPTIONAL_FIELDS:
        if name not in row.fields:
            row.issues.append(
                OcrIssue(
                    code="ocr.field_missing",
                    field=name,
                    severity="warning",
                    message=f"optional field {name} missing",
                )
            )
    for name in ("holding_profit", "profit_ratio"):
        field = row.fields.get(name)
        if field is not None and not is_signed(field.raw_text):
            row.issues.append(
                OcrIssue(
                    code="ocr.sign_assumed_positive",
                    field=name,
                    severity="warning",
                    message=f"field {name} 无显式符号，按列语义视为正数，请人工确认",
                )
            )
    for name, field in row.fields.items():
        if name == "product_name":
            threshold = NAME_THRESHOLD
        elif name == "profit_ratio":
            threshold = RATIO_THRESHOLD
        else:
            threshold = AMOUNT_THRESHOLD
        if field.confidence < threshold:
            severity = "warning" if name in OPTIONAL_FIELDS else "blocking"
            row.issues.append(
                OcrIssue(
                    code="ocr.low_confidence",
                    field=name,
                    severity=severity,  # type: ignore[arg-type]
                    message=(
                        f"field {name} confidence {field.confidence:.2f} "
                        f"below threshold {threshold:.2f}"
                    ),
                )
            )


def parse_ths(tokens: list[OcrToken], page_index: int = 0) -> list[DraftRow]:
    cleaned = _drop_quote_lines([t for t in tokens if not is_noise(t)])
    lines = group_into_lines(cleaned)
    anchored = anchor_columns(lines, ANCHORS)
    if anchored is None:
        return [layout_unknown_row(page_index, "市值、盈亏、持仓/可用、成本/现价")]
    layout, header_index = anchored

    rows: list[DraftRow] = []
    pending: DraftRow | None = None
    index = header_index + 1
    while index < len(lines):
        line = lines[index]
        index += 1
        names = _name_tokens(layout, line)

        if pending is None:
            if not names:
                continue  # 图表残片、空行
            pending = DraftRow(page_index=page_index)
            rows.append(pending)
            pending.fields["product_name"] = make_field("product_name", names, page_index)
            _assign_line1(pending, layout, line, page_index)
            continue

        value_tokens = [
            t for t in line if layout.column_of(t) == "value" and is_money(t.text)
        ]
        ratio_tokens = [
            t for t in line if layout.column_of(t) == "profit" and is_ratio(t.text)
        ]
        if value_tokens and ratio_tokens:
            _assign_line2(pending, layout, line, page_index)
            _finalize(pending)
            pending = None
            continue

        # 第二行缺失：当前行可能是下一个持仓的第一行
        _finalize(pending)
        pending = None
        if names:
            index -= 1  # 重新按第一行处理

    if pending is not None:
        _finalize(pending)
    return rows
```

- [ ] **Step 2: 运行确认通过**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_ths_parser.py engine/tests/test_ocr_service.py -q`
Expected: PASS

- [ ] **Step 3: 全量回归**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests -q`
Expected: 全绿

- [ ] **Step 4: Commit**

```bash
git add engine/src/fundlens_engine/ocr/ths_parser.py
git commit -m "feat(engine): rewrite Tonghuashun parser with two-line merge, chart filtering and unsigned-positive warning"
```

---

### Task 6: 服务层贯通测试与全量门禁

**Files:**
- Modify: `engine/tests/test_ocr_service.py`（追加 layout_unknown 贯通测试）

**Interfaces:**
- Consumes: Task 3/5 的 parser；`parse_screenshots` 顶层 `issues` 汇总行级 blocking issue（现有逻辑，`service.py:171-176`）。

- [ ] **Step 1: 追加贯通测试**

在 `test_ocr_service.py` 末尾追加：

```python
def test_parse_screenshots_surfaces_layout_unknown_as_blocking() -> None:
    backend = FakeBackend([tok("一些无法识别的文字", 0.90, 40, 200, 200, 30)])
    params = {"template": "alipay", "paths": [str(FIXTURE_DIR / "alipay_synthetic.png")]}
    result = parse_screenshots(params, backend)
    assert len(result["rows"]) == 1
    assert result["rows"][0]["fields"] == {}
    assert any(
        issue["code"] == "ocr.layout_unknown" and issue["holding_index"] == 0
        for issue in result["issues"]
    )
```

- [ ] **Step 2: 运行确认通过**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests/test_ocr_service.py -q`
Expected: PASS

- [ ] **Step 3: 全量 Python 门禁**

Run: `engine\.venv\Scripts\python.exe -m pytest engine/tests -q`
Expected: 全绿

Run: `engine\.venv\Scripts\python.exe -m ruff check engine`
Expected: 无输出（0 错误）

Run: `engine\.venv\Scripts\python.exe -m mypy engine/src`
Expected: `Success: no issues found`

若 ruff/mypy 报错，修复后重跑，再继续。

- [ ] **Step 4: Commit**

```bash
git add engine/tests/test_ocr_service.py
git commit -m "test(engine): cover layout_unknown surfacing through parse_screenshots"
```

---

## 自查记录

- **Spec 覆盖**：列锚定（Task 1）、支付宝状态机（Task 2/3）、同花顺两行合并+图表过滤+无符号规则（Task 4/5）、layout_unknown 贯通（Task 6）、串行回归（Task 2/4 的 shuffle 测试）、日收益/占比忽略（Task 2 测试断言）——均有对应任务。
- **图表过滤实现说明**：spec 第 3 节的"图表区间剔除"由等效且更简单的机制实现——`_drop_quote_lines` 整行剔除 + 状态机门禁（第一行需首列文本、第二行需市值列 money + 盈亏列 ratio）。效果一致：图表 token 不进入任何字段，由 `test_ths_chart_tokens_never_leak_into_fields` 验证。
- **类型一致性**：`ColumnLayout.column_of`、`anchor_columns` 返回 `tuple[ColumnLayout, int] | None`、`layout_unknown_row` 在 Task 1 定义，Task 3/5/6 使用的名字与签名一致；`parse_alipay/parse_ths` 签名不变，service.py 无需改动。
- **不变量**：fixture 三行同花顺持仓满足 `derived_cost ≈ cost_price × quantity`（容差内），服务层 cost_mismatch 测试语义不变。
