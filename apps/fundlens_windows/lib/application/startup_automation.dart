import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../market/startup_refresh_coordinator.dart';
import 'schedule_policy.dart';

/// Runs non-blocking startup automation after the UI is up: the automatic
/// quote refresh and, when implemented, auto snapshots.
///
/// Each step is isolated so a failure in one never blocks the others or the
/// app shell.
Future<void> runStartupAutomation(ProviderContainer container) async {
  await _guard(
    () => StartupRefreshCoordinator(
      container: container,
      policy: SchedulePolicy(DateTime.now),
    ).runIfDue(),
  );
}

Future<void> _guard(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    // Automation failures are non-fatal; the UI already reflects degraded
    // states (e.g. a failed refresh) through its providers.
  }
}
