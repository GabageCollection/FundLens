import json

import pytest

from fundlens_engine import server
from fundlens_engine.ocr.alipay_parser import parse_alipay
from fundlens_engine.ocr.backend import OcrBackend, OcrToken
from fundlens_engine.ocr.service import normalize_rows, parse_screenshots
from fundlens_engine.ocr.ths_parser import parse_ths

from conftest import FIXTURE_DIR, FakeOcrTokens, tok


def test_alipay_normalization_derives_cost_and_keeps_cumulative_separate(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    normalize_rows(rows, "alipay")
    n0 = rows[0].normalized
    # 支付宝推算成本 = 当前金额 − 持有收益
    assert n0["current_value"] == "78347.87"
    assert n0["holding_profit"] == "428.96"
    assert n0["cumulative_profit"] == "888.88"
    assert n0["derived_cost"] == "77918.91"
    assert "derived_cost" not in rows[0].fields
    assert rows[0].issues == []


def test_ths_normalization_checks_cost_within_tolerance(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    normalize_rows(rows, "ths")
    # 同花顺推算成本 = 市值 − 盈亏金额 = 56000 − 2300 = 53700 = 53.700 × 1000
    assert rows[0].normalized["derived_cost"] == "53700.00"
    assert rows[0].normalized["reference_cost"] == "53700.000"
    assert not [i for i in rows[0].issues if i.code == "import.cost_mismatch"]


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
    # Both candidate costs stay in the normalized output; neither is dropped.
    assert rows[0].normalized["derived_cost"] == "53700.00"
    assert rows[0].normalized["reference_cost"] == "60000.000"


def test_ths_corroborated_low_confidence_cost_price_is_warning_not_blocking(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    """成本恒等式成立时，cost_price/quantity 低置信阻断降级为警告。

    cost_price × quantity ≈ 市值 − 盈亏 由三个独立字段交叉验证；真实截图中
    HS300ETF 成本价 4.677 置信度 0.897 卡 0.90 阈值刀锋，但恒等式已数学
    corroborate 读数正确，不应再阻断导入。
    """
    tokens = fake_ocr_tokens.ths_page()
    index = next(i for i, t in enumerate(tokens) if t.text == "2.3570")
    tokens[index] = tok("2.3570", 0.89, *tokens[index].box)
    rows = parse_ths(tokens)
    normalize_rows(rows, "ths")
    cost_issues = [
        i for i in rows[1].issues if i.code == "ocr.low_confidence" and i.field == "cost_price"
    ]
    assert len(cost_issues) == 1
    assert cost_issues[0].severity == "warning"
    assert "交叉验证" in cost_issues[0].message
    assert not [i for i in rows[1].issues if i.severity == "blocking"]


def test_ths_mismatched_low_confidence_cost_price_stays_blocking(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    """恒等式不成立时低置信阻断不得降级——两个独立证据互相矛盾。"""
    tokens = fake_ocr_tokens.ths_page()
    index = next(i for i, t in enumerate(tokens) if t.text == "53.700")
    tokens[index] = tok("60.000", 0.89, 730, 290, 90, 28)
    rows = parse_ths(tokens)
    normalize_rows(rows, "ths")
    blocking = [i for i in rows[0].issues if i.severity == "blocking"]
    assert {i.code for i in blocking} == {"ocr.low_confidence", "import.cost_mismatch"}


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


class FakeBackend(OcrBackend):
    def __init__(self, tokens: list[OcrToken]) -> None:
        self._tokens = tokens
        self.calls: list[str] = []

    def recognize(self, image_path: str) -> list[OcrToken]:
        self.calls.append(image_path)
        return self._tokens


def test_parse_screenshots_validates_paths_and_returns_page_indices(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    backend = FakeBackend(fake_ocr_tokens.alipay_page())
    params = {
        "template": "alipay",
        "paths": [str(FIXTURE_DIR / "alipay_synthetic.png"), str(FIXTURE_DIR / "ths_synthetic.png")],
    }
    result = parse_screenshots(params, backend)
    assert len(backend.calls) == 2
    assert len(result["rows"]) == 4
    page_zero = [r for r in result["rows"] if r["page_index"] == 0]
    page_one = [r for r in result["rows"] if r["page_index"] == 1]
    assert len(page_zero) == 2 and len(page_one) == 2
    for row in result["rows"]:
        for field in row["fields"].values():
            assert field["page_index"] == row["page_index"]
            assert len(field["crop"]) == 4


def test_parse_screenshots_rejects_missing_file(fake_ocr_tokens: FakeOcrTokens) -> None:
    backend = FakeBackend(fake_ocr_tokens.alipay_page())
    with pytest.raises(ValueError, match="ocr.invalid_image_path"):
        parse_screenshots(
            {"template": "alipay", "paths": [str(FIXTURE_DIR / "does_not_exist.png")]}, backend
        )
    assert backend.calls == []


def test_parse_screenshots_rejects_non_image(fake_ocr_tokens: FakeOcrTokens) -> None:
    note = FIXTURE_DIR / "notes.tmp.txt"
    note.write_text("not an image", encoding="utf-8")
    try:
        backend = FakeBackend(fake_ocr_tokens.alipay_page())
        with pytest.raises(ValueError, match="ocr.invalid_image_path"):
            parse_screenshots({"template": "alipay", "paths": [str(note)]}, backend)
    finally:
        note.unlink(missing_ok=True)


def test_parse_screenshots_rejects_unknown_template(fake_ocr_tokens: FakeOcrTokens) -> None:
    backend = FakeBackend(fake_ocr_tokens.alipay_page())
    with pytest.raises(ValueError, match="ocr.unknown_template"):
        parse_screenshots(
            {"template": "wechat", "paths": [str(FIXTURE_DIR / "alipay_synthetic.png")]}, backend
        )


def test_rpc_handler_parses_and_never_deletes_source(fake_ocr_tokens: FakeOcrTokens) -> None:
    backend = FakeBackend(fake_ocr_tokens.ths_page())
    server.set_ocr_backend(backend)
    fixture = FIXTURE_DIR / "ths_synthetic.png"
    try:
        response = server.handle_line(
            json.dumps(
                {
                    "jsonrpc": "2.0",
                    "id": "ocr-1",
                    "method": "ocr.parse_screenshots",
                    "params": {"template": "ths", "paths": [str(fixture)]},
                    "schema_version": 1,
                }
            )
        )
    finally:
        server.set_ocr_backend(None)
    assert "error" not in response, response
    rows = response["result"]["rows"]
    assert len(rows) == 3
    assert rows[0]["fields"]["product_name"]["raw_text"] == "脱敏先锋股票"
    assert rows[0]["fields"]["product_name"]["page_index"] == 0
    assert fixture.is_file()


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


def test_rpc_handler_rejects_bad_path_as_structured_error() -> None:
    server.set_ocr_backend(FakeBackend([]))
    try:
        response = server.handle_line(
            json.dumps(
                {
                    "jsonrpc": "2.0",
                    "id": "ocr-2",
                    "method": "ocr.parse_screenshots",
                    "params": {"template": "alipay", "paths": ["C:/no/such/file.png"]},
                    "schema_version": 1,
                }
            )
        )
    finally:
        server.set_ocr_backend(None)
    assert response["error"]["code"] == "protocol.invalid_request"
    assert response["error"]["retryable"] is False
    assert response["id"] == "ocr-2"
