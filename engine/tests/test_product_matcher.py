"""Product matcher tests.

Covers normalization (whitespace, full-width punctuation, share-class
suffixes, platform decorations) and deterministic candidate ranking. The
engine only ever produces candidates: ``selected`` must always be False so
no fuzzy match can auto-merge a holding.
"""

import pytest

from fundlens_engine.products.matcher import CatalogEntry, match_candidates
from fundlens_engine.products.normalization import normalize_name


def entry(code: str, name: str, product_type: str = "fund", share_class: str = "") -> CatalogEntry:
    return CatalogEntry(
        product_code=code, name=name, product_type=product_type, share_class=share_class
    )


@pytest.fixture
def catalog() -> list[CatalogEntry]:
    return [
        entry("000001", "脱敏沪深300联接A", "fund", "A"),
        entry("000002", "脱敏沪深300联接C", "fund", "C"),
        entry("F0002", "脱敏安心债券A", "fund", "A"),
        entry("600000", "脱敏银行", "stock"),
        entry("510300", "脱敏沪深300ETF", "etf"),
    ]


class TestNormalization:
    def test_strips_whitespace_and_full_width_punctuation(self) -> None:
        assert normalize_name(" 脱敏沪深300联接（Ａ类） ") == "脱敏沪深300联接"

    def test_strips_share_class_suffixes(self) -> None:
        assert normalize_name("脱敏安心债券C") == "脱敏安心债券"
        assert normalize_name("脱敏安心债券（C类）") == "脱敏安心债券"

    def test_strips_platform_decorations(self) -> None:
        assert normalize_name("脱敏远山混合金选") == "脱敏远山混合"
        assert normalize_name("金选脱敏远山混合") == "脱敏远山混合"

    def test_full_width_letters_become_half_width(self) -> None:
        assert normalize_name("脱敏沪深300ＥＴＦ") == "脱敏沪深300ETF"


class TestMatcher:
    def test_matcher_returns_candidates_without_auto_selection(
        self, catalog: list[CatalogEntry]
    ) -> None:
        result = match_candidates("脱敏沪深300联接", catalog)
        assert result[0].product_code == "000001"
        assert all(candidate.selected is False for candidate in result)

    def test_exact_code_ranks_first(self, catalog: list[CatalogEntry]) -> None:
        result = match_candidates("600000", catalog)
        assert result[0].product_code == "600000"
        assert result[0].reason == "exact_code"
        assert result[0].confidence == 1.0

    def test_exact_normalized_name_beats_similarity(self, catalog: list[CatalogEntry]
                                                     ) -> None:
        result = match_candidates("脱敏安心债券A", catalog)
        assert result[0].product_code == "F0002"
        assert result[0].reason == "exact_name"

    def test_candidate_preserves_original_name(self, catalog: list[CatalogEntry]) -> None:
        result = match_candidates("脱敏沪深300联接", catalog)
        assert result[0].name == "脱敏沪深300联接A"
        assert result[0].product_type == "fund"
        assert result[0].share_class == "A"

    def test_returns_at_most_five_candidates(self) -> None:
        big_catalog = [entry(f"90000{i}", f"脱敏相似债券{i}号A") for i in range(8)]
        result = match_candidates("脱敏相似债券", big_catalog)
        assert 1 <= len(result) <= 5

    def test_unrelated_query_returns_no_candidates(self, catalog: list[CatalogEntry]
                                                    ) -> None:
        assert match_candidates("zzz", catalog) == []
