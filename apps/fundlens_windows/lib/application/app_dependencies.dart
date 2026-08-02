import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../backup/backup_service.dart';
import '../storage/app_database.dart';
import '../storage/holding_repository.dart';
import '../storage/snapshot_repository.dart';

/// Dependency providers wire infrastructure into the application layer.
///
/// [databaseLifecycleProvider] throws [UnimplementedError] by default so that
/// tests and the bootstrap in `main.dart` are forced to override it exactly
/// once. Everything else derives from it so a successful restore — which
/// closes and reopens the physical database — is visible to all consumers
/// after [databaseRevisionProvider] is bumped. Widgets must never
/// instantiate repositories or engine clients directly.

/// Owns the live database across backup and restore.
final databaseLifecycleProvider = Provider<DriftDatabaseLifecycle>((ref) {
  throw UnimplementedError(
    'databaseLifecycleProvider must be overridden by the bootstrap.',
  );
});

/// Bumped after a successful restore so database-dependent providers
/// re-resolve against the reopened database.
final databaseRevisionProvider = StateProvider<int>((ref) => 0);

/// The live database; re-resolved from the lifecycle after a restore.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  ref.watch(databaseRevisionProvider);
  return ref.watch(databaseLifecycleProvider).currentDatabase;
});

final holdingRepositoryProvider = Provider<HoldingRepository>((ref) {
  return DriftHoldingRepository(ref.watch(appDatabaseProvider));
});

final snapshotRepositoryProvider = Provider<SnapshotRepository>((ref) {
  return DriftSnapshotRepository(ref.watch(appDatabaseProvider));
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
/// Written after each successful refresh so derived freshness reflects the
/// real last run.
final freshQuoteHoldingIdsProvider = StateProvider<Set<String>>((ref) {
  return const <String>{};
});
