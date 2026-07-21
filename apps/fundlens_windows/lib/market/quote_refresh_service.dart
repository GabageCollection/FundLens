import 'package:drift/drift.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../data_engine/data_engine_client.dart';
import '../importing/import_models.dart';
import '../storage/app_database.dart';
import '../storage/enum_mappers.dart';
import '../storage/holding_repository.dart';
import 'quote.dart';

/// Instruments whose prices come from free market providers. Gold, deposits
/// and cash products are excluded: their values are confirmed amounts and are
/// never derived from quotes.
String? _quoteKind(InstrumentType type) {
  return switch (type) {
    InstrumentType.stock => 'stock',
    InstrumentType.etf => 'etf',
    InstrumentType.lof => 'lof',
    InstrumentType.reit => 'reit',
    InstrumentType.offExchangeFund => 'fund',
    _ => null,
  };
}

/// Outcome of one quote refresh run.
final class QuoteRefreshReport {
  const QuoteRefreshReport({
    required this.updated,
    required this.retained,
    required this.failed,
    required this.issues,
  });

  /// Holdings whose [Holding.currentValue] was recomputed as
  /// `quantity × quote` (both code and quantity confirmed).
  final List<Holding> updated;

  /// Quote-eligible holdings whose confirmed amount was preserved; they may
  /// still adopt the fresh price (e.g. Alipay amount-only holdings).
  final List<Holding> retained;

  /// Holdings whose quote failed or was rejected; the last valid value is
  /// kept untouched and a `market.quote_stale` issue is reported.
  final List<Holding> failed;

  final List<DataIssue> issues;
}

/// Applies daily market quotes to holdings with safe degradation.
///
/// Rules (see plan Task 6 and global constraints):
/// - Batches all quote-eligible codes into one `market.fetch_quotes` call;
///   the engine routes per provider.
/// - Writes accepted quotes to [QuoteCacheStore] before touching holdings.
/// - Rejects zero/negative or implausibly dated quotes.
/// - Recomputes `currentValue = quantity × quote` only when both product code
///   and quantity are confirmed (not inferred).
/// - Amount-only holdings keep their confirmed value but may adopt the price.
/// - On failure the last valid value is retained and marked stale; zero is
///   never substituted.
/// - All holding writes happen in one repository transaction.
final class QuoteRefreshService {
  factory QuoteRefreshService({
    required DataEngineClient engine,
    required HoldingRepository holdings,
    required QuoteCacheStore quoteCache,
    required DateTime Function() clock,
  }) => QuoteRefreshService._(engine, holdings, quoteCache, clock);

  const QuoteRefreshService._(
    this._engine,
    this._holdings,
    this._quoteCache,
    this._clock,
  );
  /// Oldest valuation date still accepted as plausible for a "fresh" quote.
  static const Duration maxQuoteAge = Duration(days: 45);

  final DataEngineClient _engine;
  final HoldingRepository _holdings;
  final QuoteCacheStore _quoteCache;
  final DateTime Function() _clock;

  Future<QuoteRefreshReport> refresh(List<Holding> holdings) async {
    final eligible = holdings
        .where((h) => h.productCode != null && _quoteKind(h.instrumentType) != null)
        .toList();

    if (eligible.isEmpty) {
      return const QuoteRefreshReport(
        updated: [],
        retained: [],
        failed: [],
        issues: [],
      );
    }

    final quotesByCode = await _fetchQuotes(eligible);

    final updated = <Holding>[];
    final retained = <Holding>[];
    final failed = <Holding>[];
    final issues = <DataIssue>[];
    final acceptedQuotes = <Quote>[];

    for (final holding in eligible) {
      final quote = quotesByCode[holding.productCode];
      final rejection = quote == null ? 'missing' : _validate(quote);
      if (rejection != null) {
        failed.add(holding);
        issues.add(_staleIssue(holding, quote, rejection));
        continue;
      }
      acceptedQuotes.add(quote!);
      final applied = _apply(holding, quote);
      if (_canRecompute(holding)) {
        updated.add(applied);
      } else {
        retained.add(applied);
      }
    }

    // Persist the quote cache before applying any holding update.
    if (acceptedQuotes.isNotEmpty) {
      final now = _clock().toUtc();
      await _quoteCache.upsertAll([
        for (final quote in acceptedQuotes)
          CachedQuote(
            productCode: quote.productCode,
            price: quote.value?.canonical,
            fetchedAt: now,
            source: quote.provider,
          ),
      ]);
    }

    // Apply all holding updates in one transaction. Failed holdings are
    // never written, so their last valid value survives untouched.
    final toWrite = [...updated, ...retained];
    if (toWrite.isNotEmpty) {
      await _holdings.inTransaction(() async {
        for (final holding in toWrite) {
          await _holdings.upsert(holding);
        }
      });
    }

    return QuoteRefreshReport(
      updated: updated,
      retained: retained,
      failed: failed,
      issues: issues,
    );
  }

  Future<Map<String, Quote>> _fetchQuotes(List<Holding> eligible) async {
    final items = [
      for (final holding in eligible)
        {
          'code': holding.productCode!,
          'kind': _quoteKind(holding.instrumentType)!,
        },
    ];
    Map<String, Object?> result;
    try {
      result = await _engine.call('market.fetch_quotes', {'items': items});
    } on Exception {
      // Total engine failure: every eligible holding degrades to stale.
      return const {};
    }
    final rawQuotes = result['quotes'];
    if (rawQuotes is! List) return const {};
    final byCode = <String, Quote>{};
    for (final raw in rawQuotes) {
      if (raw is Map) {
        final quote = Quote.fromJson(Map<String, Object?>.from(raw));
        byCode[quote.productCode] = quote;
      }
    }
    return byCode;
  }

  /// Returns a rejection reason, or null when the quote may be applied.
  String? _validate(Quote quote) {
    if (quote.status != QuoteStatus.fresh) return 'not_fresh';
    final value = quote.value;
    if (value == null) return 'missing_value';
    if (value.isZero || value.isNegative) return 'non_positive';
    final date = quote.valuationDate;
    if (date == null) return 'missing_date';
    final now = _clock().toUtc();
    final dayAfterTomorrow = DateTime.utc(now.year, now.month, now.day + 2);
    if (!date.toUtc().isBefore(dayAfterTomorrow)) return 'future_date';
    if (date.toUtc().isBefore(now.subtract(maxQuoteAge))) return 'too_old';
    return null;
  }

  bool _isConfirmed(Holding holding, String field) {
    return holding.fieldProvenance[field]?.kind != ProvenanceKind.inferred;
  }

  bool _canRecompute(Holding holding) {
    return holding.productCode != null &&
        holding.quantity != null &&
        _isConfirmed(holding, 'productCode') &&
        _isConfirmed(holding, 'quantity');
  }

  Holding _apply(Holding holding, Quote quote) {
    final price = quote.value!;
    final provenance = Map<String, FieldProvenance>.of(holding.fieldProvenance);
    provenance['currentPrice'] = FieldProvenance(
      kind: ProvenanceKind.market,
      source: quote.provider,
    );
    final recompute = _canRecompute(holding);
    final newValue = recompute ? _normalize(holding.quantity! * price) : null;
    if (recompute) {
      provenance['currentValue'] = FieldProvenance(
        kind: ProvenanceKind.market,
        source: quote.provider,
      );
    }
    return _copy(
      holding,
      currentPrice: price,
      currentValue: newValue,
      valuationDate: quote.valuationDate,
      fieldProvenance: provenance,
      updatedAt: _clock().toUtc(),
    );
  }

  DataIssue _staleIssue(Holding holding, Quote? quote, String reason) {
    return DataIssue(
      code: 'market.quote_stale',
      field: 'currentPrice',
      severity: IssueSeverity.warning,
      message:
          '行情更新失败（${quote?.errorCode ?? reason}），保留上次有效值，已标记过期',
      holdingIndex: null,
    );
  }

  /// Trims insignificant trailing zeros so `2100 × 4.455` reads `9355.5`.
  static DecimalValue _normalize(DecimalValue value) {
    var s = value.canonical;
    if (!s.contains('.')) return value;
    s = s.replaceAll(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return DecimalValue.parse(s);
  }

  static Holding _copy(
    Holding holding, {
    DecimalValue? currentPrice,
    DecimalValue? currentValue,
    DateTime? valuationDate,
    Map<String, FieldProvenance>? fieldProvenance,
    DateTime? updatedAt,
  }) {
    return Holding(
      id: holding.id,
      sourcePlatform: holding.sourcePlatform,
      instrumentType: holding.instrumentType,
      assetClass: holding.assetClass,
      productName: holding.productName,
      productCode: holding.productCode,
      currency: holding.currency,
      quantity: holding.quantity,
      availableQuantity: holding.availableQuantity,
      currentPrice: currentPrice ?? holding.currentPrice,
      costPrice: holding.costPrice,
      currentValue: currentValue ?? holding.currentValue,
      costAmount: holding.costAmount,
      holdingProfit: holding.holdingProfit,
      holdingReturn: holding.holdingReturn,
      dailyProfit: holding.dailyProfit,
      cumulativeProfit: holding.cumulativeProfit,
      platformTags: holding.platformTags,
      valuationMethod: holding.valuationMethod,
      valuationDate: valuationDate ?? holding.valuationDate,
      dataOrigin: holding.dataOrigin,
      fieldProvenance: fieldProvenance ?? holding.fieldProvenance,
      note: holding.note,
      createdAt: holding.createdAt,
      updatedAt: updatedAt ?? holding.updatedAt,
    );
  }
}

/// Drift-backed [QuoteCacheStore] writing to the `quote_cache` table.
final class DriftQuoteCacheStore implements QuoteCacheStore {
  DriftQuoteCacheStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> upsertAll(List<CachedQuote> quotes) async {
    if (quotes.isEmpty) return;
    await _db.batch((batch) {
      for (final quote in quotes) {
        batch.insert(
          _db.quoteCacheTable,
          QuoteCacheTableCompanion(
            productCode: Value(quote.productCode),
            productName: Value(quote.productName),
            price: Value(quote.price),
            fetchedAt: Value(dateTimeToEpochMillis(quote.fetchedAt)),
            source: Value(quote.source),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
