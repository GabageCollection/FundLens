"""Deterministic product candidate matcher.

Ranking: exact code > exact normalized name > token similarity. At most
five candidates are returned and ``selected`` is always False — the engine
proposes, the user decides.
"""

from difflib import SequenceMatcher
from typing import Literal

from pydantic import BaseModel, Field

from .normalization import normalize_name

MAX_CANDIDATES = 5
_SIMILARITY_THRESHOLD = 0.3


class CatalogEntry(BaseModel):
    product_code: str
    name: str
    product_type: str
    share_class: str = ""


class MatchCandidate(BaseModel):
    product_code: str
    name: str
    product_type: str
    share_class: str = ""
    confidence: float = Field(ge=0, le=1)
    reason: Literal["exact_code", "exact_name", "token_similarity"]
    selected: bool = False


def match_candidates(query: str, catalog: list[CatalogEntry]) -> list[MatchCandidate]:
    """Rank catalog entries against a free-text query. Never auto-selects."""
    normalized_query = normalize_name(query)
    scored: list[tuple[int, float, int, MatchCandidate]] = []
    for index, entry in enumerate(catalog):
        if query.strip() and query.strip() == entry.product_code:
            rank, confidence, reason = 0, 1.0, "exact_code"
        elif normalized_query and normalized_query == normalize_name(entry.name):
            rank, confidence, reason = 1, 0.95, "exact_name"
        else:
            confidence = SequenceMatcher(
                None, normalized_query, normalize_name(entry.name)
            ).ratio()
            if not normalized_query or confidence < _SIMILARITY_THRESHOLD:
                continue
            rank, reason = 2, "token_similarity"
        candidate = MatchCandidate(
            product_code=entry.product_code,
            name=entry.name,
            product_type=entry.product_type,
            share_class=entry.share_class,
            confidence=round(confidence, 4),
            reason=reason,  # type: ignore[arg-type]
            selected=False,
        )
        scored.append((rank, -confidence, index, candidate))
    scored.sort(key=lambda item: (item[0], item[1], item[2]))
    return [item[3] for item in scored[:MAX_CANDIDATES]]
