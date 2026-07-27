"""Tests for header-anchored column layout and noise filtering."""

from fundlens_engine.ocr.layout import (
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
