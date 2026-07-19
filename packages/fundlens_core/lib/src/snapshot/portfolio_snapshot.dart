import '../model/decimal_value.dart';
import '../model/field_provenance.dart';
import '../model/holding.dart';

final class PortfolioSnapshot {
  const PortfolioSnapshot({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.holdings,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final List<SnapshotHolding> holdings;
}

final class SnapshotHolding {
  const SnapshotHolding({
    required this.holdingId,
    required this.productName,
    required this.instrumentType,
    required this.assetClass,
    required this.sourcePlatform,
    required this.currentValue,
    required this.fieldProvenance,
    this.productCode,
    this.quantity,
    this.currentPrice,
    this.costAmount,
    this.holdingProfit,
    this.dailyProfit,
    this.cumulativeProfit,
    this.valuationDate,
  });

  final String holdingId;
  final String productName;
  final String? productCode;
  final InstrumentType instrumentType;
  final AssetClass assetClass;
  final SourcePlatform sourcePlatform;
  final DecimalValue? quantity;
  final DecimalValue? currentPrice;
  final DecimalValue currentValue;
  final DecimalValue? costAmount;
  final DecimalValue? holdingProfit;
  final DecimalValue? dailyProfit;
  final DecimalValue? cumulativeProfit;
  final DateTime? valuationDate;
  final Map<String, FieldProvenance> fieldProvenance;
}
