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
    ignored = ("08:04", "100%", "首页", "我的", "占比", "+0.67%", "金额/占比排序", "全部持有", "全部")
    for text in ignored:
        assert text not in all_text, text
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


def test_alipay_truncated_fragment_with_garbled_name_is_dropped(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    """截图底部截断的持仓只剩乱码名称（低置信度）、数值全缺，是 OCR 碎块而非可读持仓。"""
    tokens = fake_ocr_tokens.alipay_page() + [
        tok("出会术生业", 0.29, 40, 590, 200, 32),
    ]
    rows = parse_alipay(tokens)
    assert [r.fields["product_name"].raw_text for r in rows] == [
        "脱敏安心债券A",
        "脱敏远山混合C",
    ]


def test_alipay_truncated_fragment_with_tags_line_is_dropped(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    """截断持仓的标签行可读但名称乱码、数值全缺时，同样是碎块，不得生成阻断行。"""
    tokens = fake_ocr_tokens.alipay_page() + [
        tok("出会术生业", 0.29, 40, 590, 200, 32),
        tok("基金", 0.92, 40, 640, 60, 24),
        tok("稳健理财", 0.92, 120, 640, 110, 24),
    ]
    rows = parse_alipay(tokens)
    assert [r.fields["product_name"].raw_text for r in rows] == [
        "脱敏安心债券A",
        "脱敏远山混合C",
    ]


def test_alipay_clear_name_without_numbers_stays_blocking(
    fake_ocr_tokens: FakeOcrTokens,
) -> None:
    """名称清晰但数值缺失（可能真被截断）仍保留阻断行，由人工确认处理。"""
    tokens = fake_ocr_tokens.alipay_page() + [
        tok("脱敏截断债券C", 0.97, 40, 590, 200, 32),
    ]
    rows = parse_alipay(tokens)
    assert len(rows) == 3
    assert any(
        i.code == "ocr.field_missing" and i.field == "current_value" and i.severity == "blocking"
        for i in rows[2].issues
    )
