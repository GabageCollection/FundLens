import 'dart:convert';

import 'package:fundlens_core/fundlens_core.dart';

const _sourcePlatformToWire = {
  SourcePlatform.alipay: 'alipay',
  SourcePlatform.ths: 'ths',
  SourcePlatform.manual: 'manual',
};

const _instrumentTypeToWire = {
  InstrumentType.cashManagement: 'cash_management',
  InstrumentType.bankDeposit: 'bank_deposit',
  InstrumentType.stock: 'stock',
  InstrumentType.etf: 'etf',
  InstrumentType.lof: 'lof',
  InstrumentType.reit: 'reit',
  InstrumentType.offExchangeFund: 'off_exchange_fund',
  InstrumentType.accumulatedGold: 'accumulated_gold',
  InstrumentType.physicalGold: 'physical_gold',
};

const _assetClassToWire = {
  AssetClass.cash: 'cash',
  AssetClass.deposit: 'deposit',
  AssetClass.equity: 'equity',
  AssetClass.fixedIncome: 'fixed_income',
  AssetClass.mixed: 'mixed',
  AssetClass.gold: 'gold',
  AssetClass.other: 'other',
};

const _valuationMethodToWire = {
  ValuationMethod.automaticQuote: 'automatic_quote',
  ValuationMethod.quantityTimesPrice: 'quantity_times_price',
  ValuationMethod.manualAmount: 'manual_amount',
};

const _dataOriginToWire = {
  DataOrigin.manual: 'manual',
  DataOrigin.excel: 'excel',
  DataOrigin.csv: 'csv',
  DataOrigin.ocr: 'ocr',
};

const _provenanceKindToWire = {
  ProvenanceKind.original: 'original',
  ProvenanceKind.inferred: 'inferred',
  ProvenanceKind.market: 'market',
  ProvenanceKind.userCorrected: 'user_corrected',
};

String sourcePlatformToWire(SourcePlatform value) =>
    _sourcePlatformToWire[value]!;

SourcePlatform sourcePlatformFromWire(String wire) {
  for (final entry in _sourcePlatformToWire.entries) {
    if (entry.value == wire) return entry.key;
  }
  throw ArgumentError.value(wire, 'sourcePlatform', 'unknown wire name');
}

String instrumentTypeToWire(InstrumentType value) =>
    _instrumentTypeToWire[value]!;

InstrumentType instrumentTypeFromWire(String wire) {
  for (final entry in _instrumentTypeToWire.entries) {
    if (entry.value == wire) return entry.key;
  }
  throw ArgumentError.value(wire, 'instrumentType', 'unknown wire name');
}

String assetClassToWire(AssetClass value) => _assetClassToWire[value]!;

AssetClass assetClassFromWire(String wire) {
  for (final entry in _assetClassToWire.entries) {
    if (entry.value == wire) return entry.key;
  }
  throw ArgumentError.value(wire, 'assetClass', 'unknown wire name');
}

String valuationMethodToWire(ValuationMethod value) =>
    _valuationMethodToWire[value]!;

ValuationMethod valuationMethodFromWire(String wire) {
  for (final entry in _valuationMethodToWire.entries) {
    if (entry.value == wire) return entry.key;
  }
  throw ArgumentError.value(wire, 'valuationMethod', 'unknown wire name');
}

String dataOriginToWire(DataOrigin value) => _dataOriginToWire[value]!;

DataOrigin dataOriginFromWire(String wire) {
  for (final entry in _dataOriginToWire.entries) {
    if (entry.value == wire) return entry.key;
  }
  throw ArgumentError.value(wire, 'dataOrigin', 'unknown wire name');
}

String provenanceKindToWire(ProvenanceKind value) =>
    _provenanceKindToWire[value]!;

ProvenanceKind provenanceKindFromWire(String wire) {
  for (final entry in _provenanceKindToWire.entries) {
    if (entry.value == wire) return entry.key;
  }
  throw ArgumentError.value(wire, 'provenanceKind', 'unknown wire name');
}

String platformTagsToJson(List<String> tags) => jsonEncode(tags);

List<String> platformTagsFromJson(String json) {
  final decoded = jsonDecode(json) as List<dynamic>;
  return decoded.cast<String>();
}

String fieldProvenanceToJson(Map<String, FieldProvenance> provenance) {
  final map = <String, Object?>{
    for (final entry in provenance.entries)
      entry.key: {
        'kind': provenanceKindToWire(entry.value.kind),
        'source': entry.value.source,
      },
  };
  return jsonEncode(map);
}

Map<String, FieldProvenance> fieldProvenanceFromJson(String json) {
  final decoded = jsonDecode(json) as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      entry.key: FieldProvenance(
        kind: provenanceKindFromWire(entry.value['kind'] as String),
        source: entry.value['source'] as String,
      ),
  };
}

int dateTimeToEpochMillis(DateTime value) =>
    value.toUtc().millisecondsSinceEpoch;

DateTime dateTimeFromEpochMillis(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

DecimalValue? decimalFromNullableString(String? value) =>
    value == null ? null : DecimalValue.parse(value);

String? decimalToNullableString(DecimalValue? value) => value?.canonical;
