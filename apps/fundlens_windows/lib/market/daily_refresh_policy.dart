/// Decides whether the daily quote refresh should run.
///
/// The policy compares UTC calendar days: at most one attempt per day, so a
/// failed attempt is not retried until the next day.
final class DailyRefreshPolicy {
  const DailyRefreshPolicy(this.clock);

  final DateTime Function() clock;

  bool shouldRun(DateTime? lastAttemptUtc) {
    if (lastAttemptUtc == null) return true;
    final now = clock().toUtc();
    return now.year != lastAttemptUtc.year ||
        now.month != lastAttemptUtc.month ||
        now.day != lastAttemptUtc.day;
  }
}
