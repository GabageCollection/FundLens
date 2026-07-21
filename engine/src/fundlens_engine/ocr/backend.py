"""Core OCR types shared by backends, template parsers and the service."""

from dataclasses import dataclass, field
from typing import Literal, Protocol

from ..models import OcrField

Severity = Literal["info", "warning", "blocking"]


@dataclass(frozen=True)
class OcrToken:
    text: str
    confidence: float
    box: tuple[int, int, int, int]  # x, y, width, height


class OcrBackend(Protocol):
    def recognize(self, image_path: str) -> list[OcrToken]: ...


@dataclass(frozen=True)
class OcrIssue:
    code: str
    field: str
    severity: Severity
    message: str
    holding_index: int | None = None


@dataclass
class DraftRow:
    page_index: int
    fields: dict[str, OcrField] = field(default_factory=dict)
    issues: list[OcrIssue] = field(default_factory=list)
    normalized: dict[str, str] = field(default_factory=dict)
