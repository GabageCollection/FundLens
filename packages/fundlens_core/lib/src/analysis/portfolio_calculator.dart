import '../model/decimal_value.dart';
import '../model/holding.dart';
import 'portfolio_summary.dart';

final class PortfolioCalculator {
  PortfolioSummary calculate(List<Holding> holdings) {
    var total = DecimalValue.zero;
    var cost = DecimalValue.zero;
    var coveredValue = DecimalValue.zero;
    var profit = DecimalValue.zero;
    final byClass = <AssetClass, DecimalValue>{};
    final byType = <InstrumentType, DecimalValue>{};
    final bySource = <SourcePlatform, DecimalValue>{};
    for (final holding in holdings) {
      total += holding.currentValue;
      byClass[holding.assetClass] =
          (byClass[holding.assetClass] ?? DecimalValue.zero) +
          holding.currentValue;
      byType[holding.instrumentType] =
          (byType[holding.instrumentType] ?? DecimalValue.zero) +
          holding.currentValue;
      bySource[holding.sourcePlatform] =
          (bySource[holding.sourcePlatform] ?? DecimalValue.zero) +
          holding.currentValue;
      // Infer cost from holdingProfit when costAmount is missing (Alipay-style).
      final effectiveCost = holding.effectiveCostAmount;
      if (effectiveCost != null && !effectiveCost.isZero) {
        cost += effectiveCost;
        coveredValue += holding.currentValue;
        profit +=
            holding.currentFloatingProfit ??
            (holding.currentValue - effectiveCost);
      }
    }
    final shares = <String, DecimalValue>{
      for (final holding in holdings)
        holding.id: total.isZero
            ? DecimalValue.zero
            : holding.currentValue.divide(total),
    };
    final classShares = byClass.values
        .map((value) => total.isZero ? DecimalValue.zero : value.divide(total))
        .toList(growable: false);
    final cashAndDeposits =
        (byClass[AssetClass.cash] ?? DecimalValue.zero) +
        (byClass[AssetClass.deposit] ?? DecimalValue.zero);
    final equities = byClass[AssetClass.equity] ?? DecimalValue.zero;
    return PortfolioSummary(
      totalValue: total,
      totalCost: cost,
      totalFloatingProfit: profit,
      totalReturn: cost.isZero ? null : profit.divide(cost),
      returnCoverage: total.isZero
          ? DecimalValue.zero
          : coveredValue.divide(total),
      byAssetClass: Map.unmodifiable(byClass),
      byInstrumentType: Map.unmodifiable(byType),
      bySource: Map.unmodifiable(bySource),
      holdingShares: Map.unmodifiable(shares),
      largestHoldingShare: shares.values.fold(
        DecimalValue.zero,
        (a, b) => a.compareTo(b) >= 0 ? a : b,
      ),
      largestAssetClassShare: classShares.fold(
        DecimalValue.zero,
        (a, b) => a.compareTo(b) >= 0 ? a : b,
      ),
      cashAndDepositShare: total.isZero
          ? DecimalValue.zero
          : cashAndDeposits.divide(total),
      equityExposureShare: total.isZero
          ? DecimalValue.zero
          : equities.divide(total),
    );
  }
}
