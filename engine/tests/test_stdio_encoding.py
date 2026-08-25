"""Wire-encoding contract: the engine must speak UTF-8 on stdio.

The Flutter client decodes child stdout/stdin as UTF-8, but a Python child
on a Chinese-Windows host defaults its pipes to GBK. Any response containing
Chinese text (every OCR parse and product match) then fails UTF-8 decoding
in the app, the response line is silently dropped and the request hangs
until it times out — the "screenshot import always times out" bug.

These tests drive the real engine subprocess with PYTHONIOENCODING forced
to GBK to simulate that host regardless of the developer machine's locale.
"""

import json
import os
import subprocess
import sys
from pathlib import Path

ENGINE_DIR = Path(__file__).resolve().parent.parent

# product.match_candidates needs no OCR models, so the round trip is fast
# while still guaranteeing Chinese text in the response.
_REQUEST = {
    "jsonrpc": "2.0",
    "id": "encoding-1",
    "method": "product.match_candidates",
    "params": {
        "query": "东方添益债券",
        "catalog": [
            {"product_code": "000001", "name": "东方添益债券", "product_type": "fund"},
        ],
    },
    "schema_version": 1,
}


def _run_engine_raw(request: dict[str, object]) -> bytes:
    env = dict(os.environ)
    env["PYTHONPATH"] = str(ENGINE_DIR / "src")
    # Simulate a Chinese-Windows host: without an explicit UTF-8 override in
    # the engine, its pipes encode as GBK and the app cannot decode them.
    env["PYTHONIOENCODING"] = "gbk"
    proc = subprocess.Popen(
        [sys.executable, "-m", "fundlens_engine"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        cwd=ENGINE_DIR,
        env=env,
    )
    try:
        assert proc.stdin is not None and proc.stdout is not None
        proc.stdin.write(json.dumps(request, ensure_ascii=False).encode("utf-8") + b"\n")
        proc.stdin.flush()
        return proc.stdout.readline()
    finally:
        proc.kill()


def test_engine_accepts_utf8_stdin_with_chinese_params() -> None:
    # The app UTF-8-encodes request lines; Chinese screenshot paths and
    # product names must survive the trip into the engine.
    line = _run_engine_raw(_REQUEST)
    assert line, "engine produced no response"
    assert json.loads(line.decode("utf-8"))["id"] == "encoding-1"


def test_engine_stdout_is_valid_utf8_with_chinese_payload() -> None:
    line = _run_engine_raw(_REQUEST)
    assert line, "engine produced no response"
    # Strict decode: GBK-encoded Chinese raises UnicodeDecodeError here.
    response = json.loads(line.decode("utf-8", errors="strict"))
    assert "error" not in response
    candidates = response["result"]["candidates"]
    assert candidates, "expected at least one match candidate"

def test_request_line_with_bom_is_accepted() -> None:
    """PowerShell on some hosts prefixes the first piped stdin line with a
    UTF-8 BOM; the server must strip it before json.loads."""
    from fundlens_engine.server import main
    import io

    request = '{"jsonrpc":"2.0","id":"b1","method":"health.check","params":{},"schema_version":1}'
    stdin = io.StringIO("\ufeff" + request + "\n")
    stdout = io.StringIO()
    import sys as _sys

    old_in, old_out = _sys.stdin, _sys.stdout
    _sys.stdin, _sys.stdout = stdin, stdout
    try:
        main()
    finally:
        _sys.stdin, _sys.stdout = old_in, old_out
    response = json.loads(stdout.getvalue().strip())
    assert response["id"] == "b1"
    assert response["result"]["status"] == "ok"

