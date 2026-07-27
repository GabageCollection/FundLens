"""Tests for header-anchored column layout and noise filtering."""

from fundlens_engine.ocr.layout import (
    anchor_columns,
    group_into_lines,
    is_money,
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
    assert layout.column_of(tok("x", 0.9, 40, 500, 180, 30)) == "value"  # center 130
    assert layout.column_of(tok("x", 0.9, 300, 500, 80, 30)) == "daily"  # center 340
    assert layout.column_of(tok("x", 0.9, 460, 500, 110, 30)) == "holding"  # center 515
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
    noisy = (
        "08:04",
        "9:41",
        "09:30",
        "15:00",
        "最新:2.223",
        "最新：2.223 额:1.90亿",
        "额:1.90亿",
        "换:1.90%",
        "买入",
        "卖出",
        "撤单",
        "查询",
        "持仓股",
        "全部",
        "全部持有",
        "金额/占比排序",
        "资讯",
    )
    for text in noisy:
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


def test_group_into_lines_scales_tolerance_with_token_height() -> None:
    """真实支付宝截图坐标：60px 高的表头 token，y 中心最大相差 22，必须同一行。"""
    header = [
        tok("累计收益", 1.0, 1034, 330, 190, 66),  # center 363
        tok("日收益", 1.0, 465, 335, 150, 80),  # center 375
        tok("持有收益", 1.0, 726, 342, 188, 61),  # center 372
        tok("名称/金额", 0.99, 35, 355, 200, 60),  # center 385
    ]
    lines = group_into_lines(header)
    assert len(lines) == 1
    assert {t.text for t in lines[0]} == {"名称/金额", "日收益", "持有收益", "累计收益"}


def test_group_into_lines_keeps_distinct_rows_separate() -> None:
    """60px 高 token、行心距 65 的两行不得合并。"""
    tokens = [
        tok("纳指", 1.0, 0, 644, 116, 72),  # center 680
        tok("12,893.40", 0.99, 0, 714, 217, 62),  # center 745
    ]
    assert len(group_into_lines(tokens)) == 2


def test_is_money_tolerates_trailing_dot_from_dashed_gridlines() -> None:
    """分时图虚线贴着坐标轴数字时 OCR 会带出尾点（'2.255.'），仍按数字分类。"""
    assert is_money("2.255.")
    assert is_money("4.647．")
    assert not is_money("2.255..")
    assert not is_money(".")


def test_is_noise_drops_empty_tokens() -> None:
    assert is_noise(tok("", 0.0, 0, 2086, 213, 73))
    assert is_noise(tok("  ", 0.1, 0, 500, 100, 30))
