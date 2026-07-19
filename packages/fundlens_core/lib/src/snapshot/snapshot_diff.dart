import '../model/decimal_value.dart';
import '../model/holding.dart';
import 'portfolio_snapshot.dart';

final class SnapshotDiff {
  const SnapshotDiff({
    required this.totalAmountChange,
    required this.holdingAmountChanges,
    required this.assetClassAmountChanges,
  });

  final String metricLabel = '资产金额变化';
  final DecimalValue totalAmountChange;
  final Map<String, DecimalValue> holdingAmountChanges;
  final Map<AssetClass, DecimalValue> assetClassAmountChanges;
}

final class SnapshotDiffService {
  SnapshotDiff compare(PortfolioSnapshot before, PortfolioSnapshot after) {
    final beforeByHolding = <String, SnapshotHolding>{
      for (final h in before.holdings) h.holdingId: h,
    };
    final afterByHolding = <String, SnapshotHolding>{
      for (final h in after.holdings) h.holdingId: h,
    };

    final holdingIds = beforeByHolding.keys.toSet()
      ..addAll(afterByHolding.keys);
    final holdingAmountChanges = <String, DecimalValue>{};
    var totalAmountChange = DecimalValue.zero;

    for (final id in holdingIds) {
      final beforeValue =
          beforeByHolding[id]?.currentValue ?? DecimalValue.zero;
      final afterValue = afterByHolding[id]?.currentValue ?? DecimalValue.zero;
      final change = afterValue - beforeValue;
      holdingAmountChanges[id] = change;
      totalAmountChange += change;
    }

    final beforeByClass = _groupByAssetClass(before.holdings);
    final afterByClass = _groupByAssetClass(after.holdings);
    final assetClasses = beforeByClass.keys.toSet()..addAll(afterByClass.keys);
    final assetClassAmountChanges = <AssetClass, DecimalValue>{};

    for (final assetClass in assetClasses) {
      final beforeValue = beforeByClass[assetClass] ?? DecimalValue.zero;
      final afterValue = afterByClass[assetClass] ?? DecimalValue.zero;
      assetClassAmountChanges[assetClass] = afterValue - beforeValue;
    }

    return SnapshotDiff(
      totalAmountChange: totalAmountChange,
      holdingAmountChanges: Map.unmodifiable(holdingAmountChanges),
      assetClassAmountChanges: Map.unmodifiable(assetClassAmountChanges),
    );
  }

  Map<AssetClass, DecimalValue> _groupByAssetClass(
    List<SnapshotHolding> holdings,
  ) {
    final result = <AssetClass, DecimalValue>{};
    for (final h in holdings) {
      result[h.assetClass] =
          (result[h.assetClass] ?? DecimalValue.zero) + h.currentValue;
    }
    return result;
  }
}
