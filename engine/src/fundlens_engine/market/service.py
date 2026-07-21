"""Batch quote orchestration.

Routes items to the right provider by kind, isolates per-provider failures
(a raising provider degrades only its own items to ``failed`` results with
a stable code) and preserves request order in the response.
"""

import logging

from ..models import QuoteResult
from .provider import MarketDataProvider

logger = logging.getLogger("fundlens_engine.market")

_EXCHANGE_KINDS = {"stock", "etf", "lof", "reit"}
_FUND_KINDS = {"fund"}


def _failed(item: dict[str, str], provider: str, error_code: str) -> QuoteResult:
    return QuoteResult(
        product_code=item["code"],
        value=None,
        valuation_date=None,
        provider=provider,
        status="failed",
        error_code=error_code,
    )


class MarketService:
    def __init__(
        self, exchange_provider: MarketDataProvider, fund_provider: MarketDataProvider
    ) -> None:
        self._exchange = exchange_provider
        self._fund = fund_provider

    def fetch(self, items: list[dict[str, str]]) -> list[QuoteResult]:
        results: list[QuoteResult | None] = [None] * len(items)
        groups: list[tuple[MarketDataProvider, list[tuple[int, dict[str, str]]]]] = [
            (self._exchange, []),
            (self._fund, []),
        ]
        for index, item in enumerate(items):
            kind = item.get("kind", "")
            if kind in _EXCHANGE_KINDS:
                groups[0][1].append((index, item))
            elif kind in _FUND_KINDS:
                groups[1][1].append((index, item))
            else:
                results[index] = _failed(item, "none", "market.unsupported_product")
        for provider, group in groups:
            if not group:
                continue
            try:
                quotes = provider.fetch([item for _, item in group])
            except Exception:
                logger.warning(
                    "provider %s batch failed", provider.name, exc_info=True
                )
                quotes = [
                    _failed(item, provider.name, "market.provider_unavailable")
                    for _, item in group
                ]
            for (index, item), quote in zip(group, quotes, strict=True):
                if quote.product_code != item["code"]:
                    quote = _failed(item, provider.name, "market.provider_unavailable")
                results[index] = quote
        return [quote for quote in results if quote is not None]
