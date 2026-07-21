from fundlens_engine.ocr.alipay_parser import parse_alipay

from conftest import FakeOcrTokens, tok


def test_alipay_maps_holding_and_cumulative_profit(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    assert len(rows) == 2
    assert rows[0].fields["product_name"].raw_text == "脱敏安心债券A"
    assert rows[0].fields["current_value"].raw_text == "78,347.87"
    assert rows[0].fields["holding_profit"].raw_text == "+428.96"
    assert rows[0].fields["cumulative_profit"].raw_text == "+888.88"
    assert rows[1].fields["product_name"].raw_text == "脱敏远山混合C"
    assert rows[1].fields["holding_profit"].raw_text == "-156.20"


def test_alipay_ignores_status_bar_account_suffix_chart_and_navigation(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    all_text = " ".join(f.raw_text for r in rows for f in r.fields.values())
    for ignored in ("9:41", "100%", "首页", "我的", "尾号", "收益曲线"):
        assert ignored not in all_text
    assert all(r.fields["product_name"].raw_text not in ("理财", "基金") for r in rows)


def test_alipay_retains_raw_text_and_union_crop(fake_ocr_tokens: FakeOcrTokens) -> None:
    rows = parse_alipay(fake_ocr_tokens.alipay_page())
    tags = rows[0].fields["platform_tags"]
    assert "稳健理财" in tags.raw_text
    assert "金选" in tags.raw_text
    assert tags.crop[0] <= 40 and tags.crop[2] >= 230 - 40
    assert rows[0].fields["current_value"].page_index == 0


def test_alipay_low_confidence_name_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[3] = tok("脱敏安心债券A", 0.80, 40, 150, 200, 32)
    rows = parse_alipay(tokens)
    blocking = [i for i in rows[0].issues if i.severity == "blocking"]
    assert any(i.code == "ocr.low_confidence" and i.field == "product_name" for i in blocking)


def test_alipay_low_confidence_amount_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[6] = tok("78,347.87", 0.85, 40, 260, 180, 34)
    rows = parse_alipay(tokens)
    assert any(
        i.code == "ocr.low_confidence" and i.field == "current_value" and i.severity == "blocking"
        for i in rows[0].issues
    )


def test_alipay_low_confidence_tags_are_warning_only(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[4] = tok("稳健理财", 0.60, 40, 200, 110, 26)
    rows = parse_alipay(tokens)
    tag_issues = [i for i in rows[0].issues if i.field == "platform_tags"]
    assert tag_issues and all(i.severity == "warning" for i in tag_issues)


def test_alipay_missing_profit_sign_is_blocking(fake_ocr_tokens: FakeOcrTokens) -> None:
    tokens = fake_ocr_tokens.alipay_page()
    tokens[8] = tok("428.96", 0.95, 220, 330, 110, 26)
    rows = parse_alipay(tokens)
    assert any(
        i.code == "ocr.sign_missing" and i.severity == "blocking" for i in rows[0].issues
    )


def test_alipay_missing_required_field_is_blocking() -> None:
    tokens = [
        tok("脱敏安心债券A", 0.97, 40, 150, 200, 32),
        tok("持有收益", 0.95, 40, 330, 110, 26),
        tok("+428.96", 0.95, 220, 330, 110, 26),
    ]
    rows = parse_alipay(tokens)
    assert any(
        i.code == "ocr.field_missing" and i.field == "current_value" and i.severity == "blocking"
        for i in rows[0].issues
    )
