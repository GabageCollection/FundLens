import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_dependencies.dart';
import '../application/schedule_policy.dart';
import '../features/holdings/holding_actions.dart';
import '../features/settings/persisted_settings.dart';

/// Runs the automatic quote refresh at startup when the schedule says it is
/// due. Reuses the same unified refresh entry point as the manual button so
/// the global UI state and last-attempt record stay consistent.
///
/// A failed attempt (including an unavailable engine) is still recorded so a
/// broken engine does not hammer every launch.
final class StartupRefreshCoordinator {
  StartupRefreshCoordinator({required this.container, required this.policy});

  final ProviderContainer container;
  final SchedulePolicy policy;

  Future<void> runIfDue() async {
    if (!container.read(dailyAutoRefreshEnabledProvider)) return;
    final frequency = container.read(refreshFrequencyProvider);
    if (frequency == ScheduleFrequency.manual) return;
    final lastAttempt = container.read(lastRefreshAttemptAtUtcProvider);
    if (!policy.shouldRun(frequency, lastAttempt)) return;

    final holdings = await container.read(holdingRepositoryProvider).getAll();
    await HoldingActions.refreshQuotes(container, holdings);
    await _recordAttempt();
  }

  Future<void> _recordAttempt() async {
    final now = DateTime.now().toUtc();
    container.read(lastRefreshAttemptAtUtcProvider.notifier).state = now;
    await persistSetting(
      container,
      SettingKeys.lastRefreshAttemptAtUtc,
      now.toIso8601String(),
    );
  }
}
