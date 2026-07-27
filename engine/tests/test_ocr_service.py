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
