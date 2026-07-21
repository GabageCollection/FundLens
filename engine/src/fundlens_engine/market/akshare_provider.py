"""AKShare adapter: public fund NAV and metadata.

Per-item failure isolation; NAV values stay decimal strings and dates are
normalized to ISO ``YYYY-MM-DD``. Upstream errors map to
``market.provider_unavailable``.
"""

import logging
import time
from typing import Any

from ..models import QuoteResult

logger = logging.getLogger("fundlens_engine.market")

_PROVIDER_NAME = "akshare"
_RATE_LIMIT_SECONDS = 0.2


def _failed(code: str, error_code: str) -> QuoteResult:
    return QuoteResult(
        product_code=code,
        value=None,
        valuation_date=None,
        provider=_PROVIDER_NAME,
        status="failed",
        error_code=error_code,
    )


def _iso_date(raw: Any) -> str | None:
    if raw is None:
        return None
    text = str(raw).strip()
    return text[:10] if len(text) >= 10 else None


class AkShareProvider:
    name: str = _PROVIDER_NAME

    def fetch(self, items: list[dict[str, str]]) -> list[QuoteResult]:
        results = []
        for item in items:
            code = item["code"]
            try:
                results.append(self._fetch_one(code))
            except Exception:
                logger.warning("akshare NAV failed for %s", code, exc_info=True)
                results.append(_failed(code, "market.provider_unavailable"))
            time.sleep(_RATE_LIMIT_SECONDS)
        return results

    def _fetch_one(self, code: str) -> QuoteResult:
        import akshare as ak  # type: ignore[import-untyped]

        df = ak.fund_open_fund_info_em(symbol=code, indicator="单位净值走势")
        if df is None or df.empty:
            return _failed(code, "market.quote_not_found")
        row = df.iloc[-1]
        nav = row.get("单位净值")
        if nav is None or str(nav) == "":
            return _failed(code, "market.quote_not_found")
        valuation_date = _iso_date(row.get("净值日期"))
        if valuation_date is None:
            return _failed(code, "market.quote_not_found")
        return QuoteResult(
            product_code=code,
            value=str(nav),
            valuation_date=valuation_date,
            provider=self.name,
            status="fresh",
        )
