"""Provider port for market data.

Items are dicts with at least ``code`` and ``kind`` (stock/etf/lof/reit go
to the exchange provider, fund to the NAV provider). Implementations must
isolate per-item failures and translate upstream exceptions into stable
error codes such as ``market.provider_unavailable``; a failed quote keeps
``value`` None, never zero.
"""

from typing import Protocol

from ..models import QuoteResult


class MarketDataProvider(Protocol):
    name: str

    def fetch(self, items: list[dict[str, str]]) -> list[QuoteResult]: ...
