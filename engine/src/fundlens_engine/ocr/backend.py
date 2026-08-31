"""Core OCR types shared by backends, template parsers and the service."""

from dataclasses import dataclass, field
from typing import Literal, Protocol

from ..models import OcrField

Severity = Literal["info", "warning", "blocking"]

FIELD_LABELS = {
    "product_name": "产品名称",
    "current_value": "当前金额",
    "holding_profit": "持有收益",
    "cumulative_profit": "累计收益",
    "cost_price": "成本价",
    "quantity": "持仓数量",
    "profit_ratio": "持仓收益率",
    "latest_price": "最新价",
    "platform_tags": "平台标签",
    "derived_cost": "持有成本",
}


def field_label(name: str) -> str:
    """字段内部名 → 面向用户的中文名；未知名原样返回。"""
    return FIELD_LABELS.get(name, name)


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
