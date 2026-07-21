from fundlens_engine.ocr.ths_parser import parse_ths

from conftest import FakeOcrTokens, tok


def test_ths_ignores_chart_and_requires_sign_confidence(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    assert len(rows) == 3
    assert "chart_label" not in rows[0].fields
    assert rows[0].fields["holding_profit"].confidence >= 0.90


def test_ths_maps_all_columns(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    first = rows[0].fields
    assert first["product_name"].raw_text == "脱敏先锋股票"
    assert first["current_value"].raw_text == "56,000.00"
    assert first["holding_profit"].raw_text == "+2,300.00"
    assert first["cost_price"].raw_text == "53.700"
    assert first["quantity"].raw_text == "1000"
    assert rows[1].fields["holding_profit"].raw_text == "-120.50"
    assert rows[2].fields["quantity"].raw_text == "1000"


def test_ths_ignores_status_bar_header_account_and_navigation(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    rows = parse_ths(fake_ocr_tokens.ths_page())
    all_text = " ".join(f.raw_text for r in rows for f in r.fields.values())
    for ignored in ("9:41", "100%", "首页", "行情", "自选", "交易", "我的", "资金账号", "分时", "日K"):
        assert ignored not in all_text
    # The header row must not become a holding.
    assert all(r.fields["product_name"].raw_text != "名称" for r in rows)


def test_ths_low_confidence_sign_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.ths_page()
    tokens[10] = tok("+2,300.00", 0.85, 380, 200, 130, 28)
    rows = parse_ths(tokens)
    assert any(
        i.code == "ocr.low_confidence" and i.field == "holding_profit" and i.severity == "blocking"
        for i in rows[0].issues
    )


def test_ths_missing_quantity_is_blocking() -> None:
    tokens = [
        tok("脱敏先锋股票", 0.95, 40, 200, 130, 28),
        tok("56,000.00", 0.95, 240, 200, 130, 28),
        tok("+2,300.00", 0.95, 380, 200, 130, 28),
        tok("53.700", 0.95, 520, 200, 130, 28),
    ]
    rows = parse_ths(tokens)
    assert any(
        i.code == "ocr.field_missing" and i.field == "quantity" and i.severity == "blocking"
        for i in rows[0].issues
    )
