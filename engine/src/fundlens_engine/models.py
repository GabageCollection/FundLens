from typing import Any, Literal
from pydantic import BaseModel, ConfigDict, Field

class RpcRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    jsonrpc: Literal["2.0"]
    id: str
    method: str
    params: dict[str, Any] = Field(default_factory=dict)
    schema_version: Literal[1]

class RpcError(BaseModel):
    code: str
    message: str
    retryable: bool = False
    details: dict[str, Any] = Field(default_factory=dict)

class OcrField(BaseModel):
    name: str
    raw_text: str
    confidence: float = Field(ge=0, le=1)
    page_index: int = Field(ge=0)
    crop: tuple[int, int, int, int]

class QuoteResult(BaseModel):
    product_code: str
    value: str | None
    valuation_date: str | None
    provider: str
    status: Literal["fresh", "stale", "failed"]
    error_code: str | None = None
