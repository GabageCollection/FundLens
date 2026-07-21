"""Candidate generation for OCR-extracted product names.

Fuzzy matching only ever proposes candidates; it never merges or selects.
"""

from .matcher import CatalogEntry, MatchCandidate, match_candidates

__all__ = ["CatalogEntry", "MatchCandidate", "match_candidates"]
