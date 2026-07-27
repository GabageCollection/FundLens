import json
import logging
import sys
from collections.abc import Callable
from typing import Any

from pydantic import ValidationError

from .market.service import MarketService
from .models import RpcRequest
from .ocr.backend import OcrBackend

logger = logging.getLogger("fundlens_engine")

Handler = Callable[[dict[str, Any]], dict[str, Any]]

_ocr_backend: OcrBackend | None = None
_market_service: MarketService | None = None


def set_ocr_backend(backend: OcrBackend | None) -> None:
    """Inject an OCR backend (tests pass fakes; None restores PaddleOCR)."""
    global _ocr_backend
    _ocr_backend = backend


def set_market_service(service: MarketService | None) -> None:
    """Inject a market service (tests pass fakes; None restores live providers)."""
    global _market_service
    _market_service = service


def health(_: dict[str, Any]) -> dict[str, Any]:
    return {"status": "ok", "engine_version": "0.1.0"}


def ocr_parse_screenshots(params: dict[str, Any]) -> dict[str, Any]:
    from .ocr.paddle_backend import PaddleBackend
    from .ocr.service import parse_screenshots

    # PaddleOCR construction is expensive; keep one backend per process so
    # back-to-back screenshot requests reuse the loaded models.
    global _ocr_backend
    if _ocr_backend is None:
        _ocr_backend = PaddleBackend()
    return parse_screenshots(params, _ocr_backend)


def product_match_candidates(params: dict[str, Any]) -> dict[str, Any]:
    from .products.matcher import CatalogEntry, match_candidates

    query = params.get("query")
    raw_catalog = params.get("catalog")
    if not isinstance(query, str) or not isinstance(raw_catalog, list):
        raise ValueError("protocol.invalid_request")
    try:
        catalog = [CatalogEntry.model_validate(item) for item in raw_catalog]
    except ValidationError as exc:
        raise ValueError("protocol.invalid_request") from exc
    candidates = match_candidates(query, catalog)
    return {"candidates": [candidate.model_dump() for candidate in candidates]}


def _default_market_service() -> MarketService:
    from .market.akshare_provider import AkShareProvider
    from .market.baostock_provider import BaoStockProvider

    return MarketService(BaoStockProvider(), AkShareProvider())


def market_fetch_quotes(params: dict[str, Any]) -> dict[str, Any]:
    items = params.get("items")
    if not isinstance(items, list) or any(
        not isinstance(item, dict)
        or not isinstance(item.get("code"), str)
        or not isinstance(item.get("kind"), str)
        for item in items
    ):
        raise ValueError("protocol.invalid_request")
    service = _market_service if _market_service is not None else _default_market_service()
    quotes = service.fetch(items)
    return {"quotes": [quote.model_dump() for quote in quotes]}


HANDLERS: dict[str, Handler] = {
    "health.check": health,
    "ocr.parse_screenshots": ocr_parse_screenshots,
    "product.match_candidates": product_match_candidates,
    "market.fetch_quotes": market_fetch_quotes,
}


def handle_line(line: str) -> dict[str, Any]:
    request_id = "unknown"
    try:
        raw = json.loads(line)
        if isinstance(raw, dict):
            request_id = str(raw.get("id", "unknown"))
            if raw.get("schema_version") != 1:
                raise ValueError("protocol.version_unsupported")
        request = RpcRequest.model_validate(raw)
        handler = HANDLERS.get(request.method)
        if handler is None:
            raise ValueError("protocol.method_not_found")
        return {
            "jsonrpc": "2.0",
            "id": request.id,
            "result": handler(request.params),
            "schema_version": 1,
        }
    except (json.JSONDecodeError, ValidationError, ValueError) as exc:
        code = str(exc) if str(exc).startswith("protocol.") else "protocol.invalid_request"
        logger.warning("request rejected: %s", code)
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "error": {"code": code, "message": "Request rejected", "retryable": False, "details": {}},
            "schema_version": 1,
        }


def main() -> None:
    logging.basicConfig(stream=sys.stderr, level=logging.INFO, format="%(levelname)s %(message)s")
    logger.info("fundlens engine ready")
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        response = handle_line(line)
        sys.stdout.write(json.dumps(response, ensure_ascii=False, separators=(",", ":")) + "\n")
        sys.stdout.flush()
