import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

/// Optional user-set structure thresholds.
///
/// Every field is opt-in: when a threshold is absent the analysis page shows
/// the actual value without any status judgment. The settings page (Task 7)
/// provides the editing surface for these values.
final class StructureThresholds {
  const StructureThresholds({
    this.maxSingleHoldingShare,
    this.maxAssetClassShare,
    this.minCashAndDepositShare,
    this.maxEquityExposureShare,
  });

  final DecimalValue? maxSingleHoldingShare;
  final DecimalValue? maxAssetClassShare;
  final DecimalValue? minCashAndDepositShare;
  final DecimalValue? maxEquityExposureShare;

  @override
  bool operator ==(Object other) {
    return other is StructureThresholds &&
        other.maxSingleHoldingShare == maxSingleHoldingShare &&
        other.maxAssetClassShare == maxAssetClassShare &&
        other.minCashAndDepositShare == minCashAndDepositShare &&
        other.maxEquityExposureShare == maxEquityExposureShare;
  }

  @override
  int get hashCode => Object.hash(
        maxSingleHoldingShare,
        maxAssetClassShare,
        minCashAndDepositShare,
        maxEquityExposureShare,
      );
}

final structureThresholdsProvider = StateProvider<StructureThresholds>(
  (ref) => const StructureThresholds(),
);
