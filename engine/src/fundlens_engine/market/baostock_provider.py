"""BaoStock adapter: A-share and exchange ETF/LOF/REIT closing quotes.

One login/logout per batch, per-item failure isolation, dates converted to
ISO ``YYYY-MM-DD`` and prices kept as decimal strings. Upstream errors map
to ``market.provider_unavailable``.
"""

import logging
import time
from datetime import date, timedelta

from ..models import QuoteResult

logger = logging.getLogger("fundlens_engine.market")

_PROVIDER_NAME = "baostock"
_RATE_LIMIT_SECONDS = 0.1
_LOOKBACK_DAYS = 14  # tolerate holidays/suspensions when seeking last close


def _to_baostock_code(code: str) -> str:
    """Map a bare 6-digit code to BaoStock's exchange-prefixed form."""
    if "." in code:
        return code
    prefix = "sh" if code.startswith(("5", "6", "9")) else "sz"
    return f"{prefix}.{code}"


def _failed(code: str, error_code: str) -> QuoteResult:
    return QuoteResult(
        product_code=code,
        value=None,
        valuation_date=None,
        provider=_PROVIDER_NAME,
        status="failed",
        error_code=error_code,
    )


class BaoStockProvider:
    name: str = _PROVIDER_NAME

    def fetch(self, items: list[dict[str, str]]) -> list[QuoteResult]:
        import baostock as bs  # type: ignore[import-untyped]

        results: dict[str, QuoteResult] = {}
        login = bs.login()
        if login.error_code != "0":
            logger.warning("baostock login failed: %s", login.error_msg)
            return [_failed(item["code"], "market.provider_unavailable") for item in items]
        try:
            end = date.today()
            start = end - timedelta(days=_LOOKBACK_DAYS)
            for item in items:
                code = item["code"]
                try:
                    results[code] = self._fetch_one(bs, code, start, end)
                except Exception:
                    logger.warning("baostock quote failed for %s", code, exc_info=True)
                    results[code] = _failed(code, "market.provider_unavailable")
                time.sleep(_RATE_LIMIT_SECONDS)
        finally:
            bs.logout()
        return [results[item["code"]] for item in items]

    def _fetch_one(self, bs: object, code: str, start: date, end: date) -> QuoteResult:
        rs = bs.query_history_k_data_plus(  # type: ignore[attr-defined]
            _to_baostock_code(code),
            "date,close",
            start_date=start.isoformat(),
            end_date=end.isoformat(),
            frequency="d",
            adjustflag="3",
        )
        if rs.error_code != "0":
            logger.warning("baostock query failed for %s: %s", code, rs.error_msg)
            return _failed(code, "market.provider_unavailable")
        last_date: str | None = None
        last_close: str | None = None
        while rs.error_code == "0" and rs.next():
            row_date, row_close = rs.get_row_data()
            if row_close:  # skip suspended days with empty close
                last_date, last_close = row_date, row_close
        if last_date is None or last_close is None:
            return _failed(code, "market.quote_not_found")
        return QuoteResult(
            product_code=code,
            value=str(last_close),
            valuation_date=str(last_date),
            provider=self.name,
            status="fresh",
        )
