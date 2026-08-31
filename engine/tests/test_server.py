import json
from collections.abc import Callable
from typing import Any

import pytest

from fundlens_engine.server import handle_line


@pytest.fixture
def run_rpc() -> Callable[[dict[str, Any] | str], dict[str, Any]]:
    def _run(payload: dict[str, Any] | str) -> dict[str, Any]:
        line = payload if isinstance(payload, str) else json.dumps(payload)
        response = handle_line(line)
        # Round-trip through compact JSON exactly as the line server emits it.
        return json.loads(json.dumps(response, ensure_ascii=False, separators=(",", ":")))  # type: ignore[no-any-return]

    return _run


def test_health_check_returns_version_one(run_rpc: Callable[[dict[str, Any]], dict[str, Any]]) -> None:
    response = run_rpc(
        {"jsonrpc": "2.0", "id": "1", "method": "health.check", "params": {}, "schema_version": 1}
    )
    assert response["result"] == {"status": "ok", "engine_version": "1.3.0"}
    assert response["schema_version"] == 1
    assert response["id"] == "1"
    assert "error" not in response


def test_unknown_version_is_structured_error(
    run_rpc: Callable[[dict[str, Any]], dict[str, Any]],
) -> None:
    response = run_rpc(
        {"jsonrpc": "2.0", "id": "2", "method": "health.check", "params": {}, "schema_version": 99}
    )
    assert response["error"]["code"] == "protocol.version_unsupported"
    assert response["error"]["retryable"] is False
    assert response["id"] == "2"
    assert "result" not in response


def test_unknown_method_is_structured_error(
    run_rpc: Callable[[dict[str, Any]], dict[str, Any]],
) -> None:
    response = run_rpc(
        {"jsonrpc": "2.0", "id": "3", "method": "nope.missing", "params": {}, "schema_version": 1}
    )
    assert response["error"]["code"] == "protocol.method_not_found"
    assert response["error"]["retryable"] is False
    assert response["id"] == "3"


def test_malformed_json_is_invalid_request(
    run_rpc: Callable[[dict[str, Any] | str], dict[str, Any]],
) -> None:
    response = run_rpc("{not json")
    assert response["error"]["code"] == "protocol.invalid_request"
    assert response["error"]["retryable"] is False


def test_response_matches_schema(run_rpc: Callable[[dict[str, Any]], dict[str, Any]]) -> None:
    import jsonschema
    from pathlib import Path

    root = Path(__file__).parents[2]
    schema = json.loads((root / "schemas/engine_protocol_v1.schema.json").read_text("utf-8"))
    for payload in (
        {"jsonrpc": "2.0", "id": "1", "method": "health.check", "params": {}, "schema_version": 1},
        {"jsonrpc": "2.0", "id": "2", "method": "health.check", "params": {}, "schema_version": 99},
        {"jsonrpc": "2.0", "id": "3", "method": "nope", "params": {}, "schema_version": 1},
    ):
        jsonschema.validate(run_rpc(payload), schema)
