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
    junk = ("最新", "1.90亿", "2.430", "7.74%", "0.00%", "2.081", "09:30", "11:30", "15:00", "行情")
    for text in junk:
        assert text not in all_text, text


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
    ignored = (
        "08:03",
        "100%",
        "买入",
        "卖出",
        "撤单",
        "查询",
        "持仓股",
        "首页",
        "自选",
        "交易",
        "资讯",
        "**9371",
        "中国银河证券",
    )
    for text in ignored:
        assert text not in all_text, text


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


def test_ths_nav_icon_junk_line_without_numbers_is_dropped() -> None:
    """底部导航图标误识别行（'炉'/'目' 等汉字碎块、无数字）不得生成幻影持仓。"""
    header = [
        tok("市值", 0.97, 0, 530, 141, 63),
        tok("盈亏", 0.97, 482, 531, 114, 65),
        tok("持仓/可用", 0.97, 716, 535, 221, 60),
        tok("成本/现价", 0.97, 1056, 530, 204, 61),
    ]
    tokens = header + [
        tok("纳指", 1.00, 0, 644, 116, 72),
        tok("-474.80", 1.00, 401, 637, 194, 65),
        tok("5800", 1.00, 810, 636, 130, 63),
        tok("2.305", 1.00, 1138, 632, 122, 63),
        tok("12,893.40", 0.99, 0, 714, 217, 62),
        tok("-3.552%", 1.00, 388, 701, 207, 71),
        tok("5800", 1.00, 810, 702, 130, 65),
        tok("2.223", 1.00, 1142, 699, 118, 65),
        tok("最新:2.223-1.419%额:1.90亿换:1.90%", 0.96, 0, 805, 492, 51),
        # 底部导航图标碎块行：有汉字、零数字。
        tok("炉", 0.18, 0, 2527, 110, 58),
        tok("&", 0.86, 467, 2534, 98, 60),
        tok("目", 0.99, 928, 2544, 78, 60),
        tok("~", 0.78, 258, 2558, 57, 60),
    ]
    rows = parse_ths(tokens)
    assert [r.fields["product_name"].raw_text for r in rows] == ["纳指"]


def test_ths_chart_axis_trailing_dots_and_symbols_never_create_phantom_rows() -> None:
    """坐标轴数字带尾点（'2.255.'）、符号碎块（'-', '•', ''）不得触发新持仓。"""
    header = [
        tok("市值", 0.97, 0, 530, 141, 63),
        tok("盈亏", 0.97, 482, 531, 114, 65),
        tok("持仓/可用", 0.97, 716, 535, 221, 60),
        tok("成本/现价", 0.97, 1056, 530, 204, 61),
    ]
    tokens = header + [
        # 持仓 A 两行齐全。
        tok("纳指", 1.00, 0, 644, 116, 72),
        tok("-474.80", 1.00, 401, 637, 194, 65),
        tok("5800", 1.00, 810, 636, 130, 63),
        tok("2.305", 1.00, 1138, 632, 122, 63),
        tok("12,893.40", 0.99, 0, 714, 217, 62),
        tok("-3.552%", 1.00, 388, 701, 207, 71),
        tok("5800", 1.00, 810, 702, 130, 65),
        tok("2.223", 1.00, 1142, 699, 118, 65),
        # 图表噪声：最新行情行 + 带尾点/符号的坐标轴碎块。
        tok("最新:2.223-1.419%额:1.90亿换:1.90%", 0.96, 0, 805, 492, 51),
        tok("2.430", 1.00, 0, 858, 106, 56),
        tok("7.74%", 1.00, 1142, 839, 118, 65),
        tok("2.255.", 0.90, 0, 1026, 123, 58),
        tok("0.00%", 0.91, 1140, 1005, 120, 65),
        tok("-", 0.19, 607, 1338, 10, 9),
        tok("•", 0.14, 641, 1335, 19, 14),
        tok("", 0.00, 0, 2086, 213, 73),
        tok("2.081", 1.00, 0, 1193, 102, 58),
        tok("-7.74%", 1.00, 1128, 1174, 132, 57),
        # 持仓 B 两行齐全。
        tok("HS300ETF", 0.95, 0, 1376, 259, 63),
        tok("-242.20", 1.00, 403, 1374, 188, 60),
        tok("2100", 1.00, 808, 1368, 129, 64),
        tok("4.677", 0.89, 1147, 1364, 113, 60),
        tok("9,580.20", 0.99, 0, 1439, 191, 70),
        tok("-2.466%", 0.99, 389, 1439, 204, 65),
        tok("2100", 1.00, 807, 1438, 130, 63),
        tok("4.562", 0.99, 1147, 1431, 113, 66),
    ]
    rows = parse_ths(tokens)
    assert [r.fields["product_name"].raw_text for r in rows] == ["纳指", "HS300ETF"]
    assert rows[1].fields["cost_price"].raw_text == "4.677"


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
