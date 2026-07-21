"""Market service tests.

Default tests use fake providers only — no network, no TCP. Batch
orchestration must isolate per-item and per-provider failures: a failed
quote returns status ``failed`` with ``value is None`` (never zero) and a
stable error code, while sibling quotes stay fresh.

An opt-in live smoke test hits the real free providers. It is excluded
from default runs via the ``live`` marker; run it explicitly with:

    python -m pytest engine/tests/test_market_service.py -m live
"""

import json

import pytest

from fundlens_engine import server
from fundlens_engine.market.service import MarketService
from fundlens_engine.models import QuoteResult


def stock(code: str) -> dict[str, str]:
    return {"code": code, "kind": "stock"}


def fund(code: str) -> dict[str, str]:
    return {"code": code, "kind": "fund"}


class FakeProvider:
    """Deterministic provider fake with per-code failure injection."""

    def __init__(self, name: str, value: str = "1.2345", date: str = "2026-07-20") -> None:
        self.name = name
        self._value = value
        self._date = date
        self._fail: set[str] = set()
        self.calls: list[list[dict[str, str]]] = []

    def fail_for(self, code: str) -> None:
        self._fail.add(code)

    def fetch(self, items: list[dict[str, str]]) -> list[QuoteResult]:
        self.calls.append(items)
        results = []
        for item in items:
            if item["code"] in self._fail:
                results.append(
                    QuoteResult(
                        product_code=item["code"],
                        value=None,
                        valuation_date=None,
                        provider=self.name,
                        status="failed",
                        error_code="market.provider_unavailable",
                    )
                )
            else:
                results.append(
                    QuoteResult(
                        product_code=item["code"],
                        value=self._value,
                        valuation_date=self._date,
                        provider=self.name,
                        status="fresh",
                    )
                )
        return results


class ExplodingProvider(FakeProvider):
    def fetch(self, items: list[dict[str, str]]) -> list[QuoteResult]:
        raise ConnectionError("simulated upstream outage")


@pytest.fixture
def fake_baostock() -> FakeProvider:
    return FakeProvider("baostock", value="10.50", date="2026-07-20")


@pytest.fixture
def fake_akshare() -> FakeProvider:
    return FakeProvider("akshare", value="1.2345", date="2026-07-20")


def test_quote_batch_preserves_partial_success(
    fake_baostock: FakeProvider, fake_akshare: FakeProvider
) -> None:
    fake_akshare.fail_for("F0002")
    result = MarketService(fake_baostock, fake_akshare).fetch([stock("600000"), fund("F0002")])
    assert result[0].status == "fresh"
    assert result[1].status == "failed"
    assert result[1].value is None


def test_routes_items_by_kind(fake_baostock: FakeProvider, fake_akshare: FakeProvider) -> None:
    MarketService(fake_baostock, fake_akshare).fetch(
        [stock("600000"), {"code": "510300", "kind": "etf"}, fund("F0002")]
    )
    assert [i["code"] for i in fake_baostock.calls[0]] == ["600000", "510300"]
    assert [i["code"] for i in fake_akshare.calls[0]] == ["F0002"]


def test_result_order_matches_request_order(
    fake_baostock: FakeProvider, fake_akshare: FakeProvider
) -> None:
    result = MarketService(fake_baostock, fake_akshare).fetch([fund("F0002"), stock("600000")])
    assert [r.product_code for r in result] == ["F0002", "600000"]


def test_provider_exception_degrades_to_failed_results(
    fake_baostock: FakeProvider,
) -> None:
    service = MarketService(fake_baostock, ExplodingProvider("akshare"))
    result = service.fetch([stock("600000"), fund("F0002"), fund("F0003")])
    assert result[0].status == "fresh"
    for quote in result[1:]:
        assert quote.status == "failed"
        assert quote.value is None
        assert quote.valuation_date is None
        assert quote.error_code == "market.provider_unavailable"


def test_unknown_kind_fails_without_touching_providers(
    fake_baostock: FakeProvider, fake_akshare: FakeProvider
) -> None:
    result = MarketService(fake_baostock, fake_akshare).fetch(
        [{"code": "X1", "kind": "crypto"}]
    )
    assert result[0].status == "failed"
    assert result[0].value is None
    assert result[0].error_code == "market.unsupported_product"
    assert fake_baostock.calls == []
    assert fake_akshare.calls == []


def test_fetch_quotes_rpc_handler(fake_baostock: FakeProvider, fake_akshare: FakeProvider
                                  ) -> None:
    fake_akshare.fail_for("F0002")
    server.set_market_service(MarketService(fake_baostock, fake_akshare))
    try:
        response = server.handle_line(
            json.dumps(
                {
                    "jsonrpc": "2.0",
                    "id": "req-quotes-1",
                    "method": "market.fetch_quotes",
                    "params": {"items": [stock("600000"), fund("F0002")]},
                    "schema_version": 1,
                }
            )
        )
    finally:
        server.set_market_service(None)
    quotes = response["result"]["quotes"]
    assert quotes[0]["status"] == "fresh"
    assert quotes[0]["value"] == "10.50"
    assert quotes[1] == {
        "product_code": "F0002",
        "value": None,
        "valuation_date": None,
        "provider": "akshare",
        "status": "failed",
        "error_code": "market.provider_unavailable",
    }


def test_match_candidates_rpc_handler() -> None:
    response = server.handle_line(
        json.dumps(
            {
                "jsonrpc": "2.0",
                "id": "req-match-1",
                "method": "product.match_candidates",
                "params": {
                    "query": "脱敏沪深300联接",
                    "catalog": [
                        {
                            "product_code": "000001",
                            "name": "脱敏沪深300联接A",
                            "product_type": "fund",
                            "share_class": "A",
                        }
                    ],
                },
                "schema_version": 1,
            }
        )
    )
    candidates = response["result"]["candidates"]
    assert candidates[0]["product_code"] == "000001"
    assert candidates[0]["selected"] is False


@pytest.mark.live
def test_live_smoke_real_providers() -> None:
    """Opt-in smoke test against real baostock/akshare. Run: pytest -m live."""
    from fundlens_engine.market.akshare_provider import AkShareProvider
    from fundlens_engine.market.baostock_provider import BaoStockProvider

    service: MarketService = MarketService(BaoStockProvider(), AkShareProvider())
    results = service.fetch([{"code": "600000", "kind": "stock"}, {"code": "000001", "kind": "fund"}])
    assert len(results) == 2
    for quote in results:
        assert quote.status in {"fresh", "stale", "failed"}
        if quote.status == "fresh":
            assert quote.value is not None and float(quote.value) > 0


def test_params_validation_rejects_bad_items() -> None:
    response = server.handle_line(
        json.dumps(
            {
                "jsonrpc": "2.0",
                "id": "req-bad-1",
                "method": "market.fetch_quotes",
                "params": {"items": [{"kind": "fund"}]},
                "schema_version": 1,
            }
        )
    )
    assert response["error"]["code"] == "protocol.invalid_request"
