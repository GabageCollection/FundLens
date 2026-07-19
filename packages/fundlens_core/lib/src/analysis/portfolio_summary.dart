import '../model/decimal_value.dart';
import '../model/holding.dart';

final class PortfolioSummary {
  const PortfolioSummary({
    required this.totalValue,
    required this.totalCost,
    required this.totalFloatingProfit,
    required this.totalReturn,
    required this.returnCoverage,
    required this.byAssetClass,
    required this.byInstrumentType,
    required this.bySource,
    required this.holdingShares,
    required this.largestHoldingShare,
    required this.largestAssetClassShare,
    required this.cashAndDepositShare,
    required this.equityExposureShare,
  });
  final DecimalValue totalValue;
  final DecimalValue totalCost;
  final DecimalValue totalFloatingProfit;
  final DecimalValue? totalReturn;
  final DecimalValue returnCoverage;
  final Map<AssetClass, DecimalValue> byAssetClass;
  final Map<InstrumentType, DecimalValue> byInstrumentType;
  final Map<SourcePlatform, DecimalValue> bySource;
  final Map<String, DecimalValue> holdingShares;
  final DecimalValue largestHoldingShare;
  final DecimalValue largestAssetClassShare;
  final DecimalValue cashAndDepositShare;
  final DecimalValue equityExposureShare;
}
