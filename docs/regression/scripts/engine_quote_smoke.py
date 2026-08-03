"""阶段 4 冒烟：真实引擎 + 真实网络行情链路。

启动 dist 内置引擎，走 JSON-RPC 2.0 逐行协议：
1. health.check —— 引擎可响应；
2. market.fetch_quotes —— 对脱敏代码（000001 场外基金）请求行情，
   网络可用时返回 fresh 报价；不可用时引擎按供应商降级/超时。

结果以「PASS/降级/FAIL」写 stdout，供回归报告引用。
"""

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ENGINE_EXE = (
    ROOT
    / "dist"
    / "engine"
    / "fundlens_engine"
    / "fundlens_engine.exe"
)
QUOTE_TIMEOUT_SECONDS = 45
DEGRADED_OK = {"missing", "provider_unavailable", "timeout", "unknown"}


def call(proc: subprocess.Popen, request: dict, timeout: float) -> dict:
    line = json.dumps(request, ensure_ascii=False, separators=(",", ":"))
    proc.stdin.write(line + "\n")
    proc.stdin.flush()
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        raw = proc.stdout.readline()
        if not raw:
            raise RuntimeError("engine stdout closed")
        raw = raw.strip()
        if not raw:
            continue
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            # Provider libraries (akshare etc.) may print to stdout; skip
            # non-JSON noise until the actual response line arrives.
            continue
    raise TimeoutError(f"no response within {timeout}s")


def main() -> int:
    if not ENGINE_EXE.exists():
        print(f"FAIL 未找到引擎: {ENGINE_EXE}")
        return 1
    try:
        proc = subprocess.Popen(
            [str(ENGINE_EXE)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            encoding="utf-8",
        )
    except OSError as exc:
        print(f"FAIL 无法启动引擎: {exc}")
        return 1

    failures = 0
    try:
        health = call(
            proc,
            {"jsonrpc": "2.0", "id": "1", "method": "health.check", "params": {}, "schema_version": 1},
            QUOTE_TIMEOUT_SECONDS,
        )
        if health.get("result", {}).get("status") != "ok":
            print(f"FAIL health.check 异常: {health}")
            failures += 1
        else:
            print(
                "PASS health.check "
                f"engine_version={health['result'].get('engine_version')}"
            )

        start = time.monotonic()
        quotes = call(
            proc,
            {
                "jsonrpc": "2.0",
                "id": "2",
                "method": "market.fetch_quotes",
                "params": {
                    "items": [
                        {"code": "000001", "kind": "fund"},
                        {"code": "510300", "kind": "etf"},
                    ]
                },
                "schema_version": 1,
            },
            QUOTE_TIMEOUT_SECONDS,
        )
        elapsed = round(time.monotonic() - start, 1)
        if "error" in quotes:
            code = quotes["error"].get("code", "unknown")
            if code in DEGRADED_OK:
                print(
                    f"降级 行情请求被引擎拒绝/超时（{code}），网络或供应商不可用，{elapsed}s"
                )
            else:
                print(f"FAIL fetch_quotes 错误: {quotes['error']}")
                failures += 1
        else:
            rows = quotes["result"]["quotes"]
            statuses = [q.get("status") for q in rows]
            print(
                f"{'PASS' if all(s == 'fresh' for s in statuses) else '部分降级'}"
                f" fetch_quotes {elapsed}s: {statuses}"
            )
            for q in rows:
                print(
                    f"  {q.get('product_code')} {q.get('status')} "
                    f"value={q.get('value')} provider={q.get('provider')}"
                )
    except (TimeoutError, subprocess.TimeoutExpired):
        print(f"FAIL fetch_quotes 超时（>{QUOTE_TIMEOUT_SECONDS}s）")
        failures += 1
    except Exception as exc:  # noqa: BLE001 - 冒烟脚本汇总所有失败
        print(f"FAIL 引擎通信异常: {exc}")
        failures += 1
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()

    print("== 引擎行情冒烟结束 ==" if failures == 0 else "== 引擎行情冒烟存在失败 ==")
    return failures


if __name__ == "__main__":
    sys.exit(main())
