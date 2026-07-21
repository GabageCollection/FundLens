import 'package:fundlens_core/fundlens_core.dart';

/// Status of a single quote as reported by the data engine.
enum QuoteStatus { fresh, stale, failed }

/// A normalized quote for one product code, parsed from the engine's
/// `QuoteResult` DTO (`market.fetch_quotes`).
final class Quote {
  const Quote({
    required this.productCode,
    required this.provider,
    required this.status,
    this.value,
    this.valuationDate,
    this.errorCode,
  });

  factory Quote.fromJson(Map<String, Object?> json) {
    final rawValue = json['value'];
    final rawDate = json['valuation_date'];
    return Quote(
      productCode: json['product_code'] as String? ?? '',
      provider: json['provider'] as String? ?? 'unknown',
      status: switch (json['status']) {
        'fresh' => QuoteStatus.fresh,
        'stale' => QuoteStatus.stale,
        _ => QuoteStatus.failed,
      },
      value: rawValue is String ? _tryParseValue(rawValue) : null,
      valuationDate: rawDate is String ? DateTime.tryParse(rawDate) : null,
      errorCode: json['error_code'] as String?,
    );
  }

  final String productCode;
  final DecimalValue? value;
  final DateTime? valuationDate;
  final String provider;
  final QuoteStatus status;
  final String? errorCode;
}

DecimalValue? _tryParseValue(String raw) {
  try {
    return DecimalValue.parse(raw);
  } on FormatException {
    return null;
  }
}

/// A row persisted into the `quote_cache` table before updates are applied.
final class CachedQuote {
  const CachedQuote({
    required this.productCode,
    required this.price,
    required this.fetchedAt,
    required this.source,
    this.productName,
  });

  final String productCode;
  final String? productName;
  final String? price;
  final DateTime fetchedAt;
  final String source;
}

/// Write port for the quote cache. Implementations must upsert by product
/// code so the freshest accepted quote wins.
abstract interface class QuoteCacheStore {
  Future<void> upsertAll(List<CachedQuote> quotes);
}
