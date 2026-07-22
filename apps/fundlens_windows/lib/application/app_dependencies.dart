import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../storage/holding_repository.dart';
import '../storage/snapshot_repository.dart';

/// Dependency providers wire infrastructure into the application layer.
///
/// They throw [UnimplementedError] by default so that tests and the bootstrap
/// in `main.dart` are forced to override them exactly once. Widgets must never
/// instantiate repositories or engine clients directly.

final holdingRepositoryProvider = Provider<HoldingRepository>((ref) {
  throw UnimplementedError(
    'holdingRepositoryProvider must be overridden by the bootstrap.',
  );
});

final snapshotRepositoryProvider = Provider<SnapshotRepository>((ref) {
  throw UnimplementedError(
    'snapshotRepositoryProvider must be overridden by the bootstrap.',
  );
});

final portfolioCalculatorProvider = Provider<PortfolioCalculator>((ref) {
  throw UnimplementedError(
    'portfolioCalculatorProvider must be overridden by the bootstrap.',
  );
});

final dataQualityCalculatorProvider = Provider<DataQualityCalculator>((ref) {
  throw UnimplementedError(
    'dataQualityCalculatorProvider must be overridden by the bootstrap.',
  );
});

/// Holding ids whose quotes were refreshed successfully in the latest run.
///
/// Defaults to the empty set: without a quote refresh, every quoted holding is
/// treated as stale (degraded), which is the safe assumption at startup.
final freshQuoteHoldingIdsProvider = Provider<Set<String>>((ref) {
  return const <String>{};
});
