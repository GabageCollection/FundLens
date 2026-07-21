import json
import logging
import sys
from collections.abc import Callable
from typing import Any

from pydantic import ValidationError

from .models import RpcRequest

logger = logging.getLogger("fundlens_engine")

Handler = Callable[[dict[str, Any]], dict[str, Any]]


def health(_: dict[str, Any]) -> dict[str, Any]:
    return {"status": "ok", "engine_version": "0.1.0"}


HANDLERS: dict[str, Handler] = {"health.check": health}


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
