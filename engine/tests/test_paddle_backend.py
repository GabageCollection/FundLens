"""Edge-rescue logic for the Paddle backend (pure functions, no models).

检测框左右平移错位时,透视矫正会裁掉首尾字符(实测:1.879 → 1.87,
置信度却仍 1.0)。补救通道只处理贴图像左右边缘的数字/百分比 token:
扩大裁剪框重识别,且仅在旧文本是新文本的严格子串时才采纳——
矫正错位只会「补回被裁的字符」,不会改写已识别的内容。
"""

from fundlens_engine.ocr.backend import OcrToken
from fundlens_engine.ocr.paddle_backend import (
    rescue_edge_tokens,
    should_adopt_rescue,
)


def tok(text: str, conf: float, x: int, y: int, w: int = 120, h: int = 30) -> OcrToken:
    return OcrToken(text=text, confidence=conf, box=(x, y, w, h))


class TestShouldAdoptRescue:
    def test_adopts_when_new_text_extends_old(self) -> None:
        assert should_adopt_rescue("1.87", "1.879", 0.91)
        assert should_adopt_rescue("2.04", "2.045", 0.92)

    def test_rejects_identical_text(self) -> None:
        assert not should_adopt_rescue("1.879", "1.879", 0.99)

    def test_rejects_non_substring_rewrite(self) -> None:
        # 加宽框重识别可能读出完全不同的内容,绝不能采纳
        assert not should_adopt_rescue("2.045", "1.879", 0.996)
        assert not should_adopt_rescue("598.70", "98.70", 0.99)

    def test_rejects_low_score(self) -> None:
        assert not should_adopt_rescue("1.87", "1.879", 0.80)

    def test_rejects_when_new_text_is_not_numeric_like_old(self) -> None:
        assert not should_adopt_rescue("1.87", "1.87万", 0.99)
        assert not should_adopt_rescue("3.34%", "3.341", 0.99)

    def test_full_width_old_text_matches_half_width_new(self) -> None:
        assert should_adopt_rescue("１．８７", "1.879", 0.95)


class TestRescueEdgeTokens:
    IMAGE = (1260, 2736)

    def test_right_edge_money_token_is_rescued(self) -> None:
        clipped = tok("1.87", 1.0, 1154, 1983, 106, 68)  # 右缘 1260 = 图宽
        safe = tok("598.70", 1.0, 433, 1997, 160, 61)
        result = rescue_edge_tokens(
            [clipped, safe], self.IMAGE, lambda box: ("1.879", 0.995)
        )
        assert result[0].text == "1.879"
        assert result[0].confidence == 0.995
        # 未贴边的 token 不触发重识别,原样保留
        assert result[1] is safe

    def test_left_edge_ratio_token_is_rescued(self) -> None:
        clipped = tok(".852%", 0.99, 0, 500, 90, 40)  # 左缘 x=0,首字符被裁
        result = rescue_edge_tokens(
            [clipped], self.IMAGE, lambda box: ("8.852%", 0.96)
        )
        assert result[0].text == "8.852%"

    def test_non_numeric_edge_token_is_not_rescued(self) -> None:
        name = tok("标普ETF", 1.0, 0, 1999, 210, 72)
        calls: list[tuple[int, int, int, int]] = []
        result = rescue_edge_tokens(
            [name], self.IMAGE, lambda box: calls.append(box) or ("x", 0.99)
        )
        assert result[0] is name
        assert calls == []

    def test_recognition_failure_keeps_original(self) -> None:
        clipped = tok("1.87", 1.0, 1154, 1983, 106, 68)
        result = rescue_edge_tokens([clipped], self.IMAGE, lambda box: None)
        assert result[0] is clipped

    def test_rejected_candidate_keeps_original(self) -> None:
        clipped = tok("2.045", 1.0, 1144, 1065, 116, 56)  # 右缘 1260
        result = rescue_edge_tokens(
            [clipped], self.IMAGE, lambda box: ("1.879", 0.996)
        )
        assert result[0] is clipped

    def test_rescue_box_is_padded_and_clamped_to_image(self) -> None:
        seen: list[tuple[int, int, int, int]] = []
        clipped = tok("1.87", 1.0, 1154, 1983, 106, 68)
        rescue_edge_tokens([clipped], self.IMAGE, lambda box: seen.append(box) or None)
        x1, y1, x2, y2 = seen[0]
        assert x1 < 1154 and y1 < 1983  # 向左/上扩大,覆盖被裁的字符
        assert x2 <= self.IMAGE[0] and y2 <= self.IMAGE[1]  # 不越出图像
