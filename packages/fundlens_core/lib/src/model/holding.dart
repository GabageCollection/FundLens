import 'decimal_value.dart';
import 'field_provenance.dart';

enum SourcePlatform { alipay, ths, manual }

enum InstrumentType {
  cashManagement,
  bankDeposit,
  stock,
  etf,
  lof,
  reit,
  offExchangeFund,
  accumulatedGold,
  physicalGold,
}

enum AssetClass { cash, deposit, equity, fixedIncome, mixed, gold, other }

enum ValuationMethod { automaticQuote, quantityTimesPrice, manualAmount }

enum DataOrigin { manual, excel, csv, ocr }

final class Holding {
  const Holding({
    required this.id,
    required this.sourcePlatform,
    required this.instrumentType,
    required this.assetClass,
    required this.productName,
    required this.currency,
    required this.currentValue,
    required this.valuationMethod,
    required this.dataOrigin,
    required this.fieldProvenance,
    required this.createdAt,
    required this.updatedAt,
    this.productCode,
    this.quantity,
    this.availableQuantity,
    this.currentPrice,
    this.costPrice,
    this.costAmount,
    this.holdingProfit,
    this.holdingReturn,
    this.dailyProfit,
    this.cumulativeProfit,
    this.platformTags = const [],
    this.valuationDate,
    this.note,
  });

  final String id;
  final SourcePlatform sourcePlatform;
  final InstrumentType instrumentType;
  final AssetClass assetClass;
  final String productName;
  final String? productCode;
  final String currency;
  final DecimalValue? quantity;
  final DecimalValue? availableQuantity;
  final DecimalValue? currentPrice;
  final DecimalValue? costPrice;
  final DecimalValue currentValue;
  final DecimalValue? costAmount;
  final DecimalValue? holdingProfit;
  final DecimalValue? holdingReturn;
  final DecimalValue? dailyProfit;
  final DecimalValue? cumulativeProfit;
  final List<String> platformTags;
  final ValuationMethod valuationMethod;
  final DateTime? valuationDate;
  final DataOrigin dataOrigin;
  final Map<String, FieldProvenance> fieldProvenance;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  DecimalValue? get currentFloatingProfit =>
      holdingProfit ?? (costAmount == null ? null : currentValue - costAmount!);

  /// Effective cost for return calculations.
  /// When [costAmount] is absent but [holdingProfit] is present, infer cost
  /// as `currentValue - holdingProfit` to keep Alipay-style holdings in the
  /// return denominator, matching the specification in §9.1.
  DecimalValue? get effectiveCostAmount =>
      costAmount ??
      (holdingProfit == null ? null : currentValue - holdingProfit!);

  /// 定向拷贝:仅支持批量操作需要的非空字段。
  /// 未传的字段保持原值;可空字段不在此列(批量操作不清空数据)。
  Holding copyWith({
    SourcePlatform? sourcePlatform,
    AssetClass? assetClass,
    Map<String, FieldProvenance>? fieldProvenance,
    DateTime? updatedAt,
  }) {
    return Holding(
      id: id,
      sourcePlatform: sourcePlatform ?? this.sourcePlatform,
      instrumentType: instrumentType,
      assetClass: assetClass ?? this.assetClass,
      productName: productName,
      productCode: productCode,
      currency: currency,
      quantity: quantity,
      availableQuantity: availableQuantity,
      currentPrice: currentPrice,
      costPrice: costPrice,
      currentValue: currentValue,
      costAmount: costAmount,
      holdingProfit: holdingProfit,
      holdingReturn: holdingReturn,
      dailyProfit: dailyProfit,
      cumulativeProfit: cumulativeProfit,
      platformTags: platformTags,
      valuationMethod: valuationMethod,
      valuationDate: valuationDate,
      dataOrigin: dataOrigin,
      fieldProvenance: fieldProvenance ?? this.fieldProvenance,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
