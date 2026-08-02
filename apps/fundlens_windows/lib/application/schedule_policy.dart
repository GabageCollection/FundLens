/// Frequency choices for recurring tasks (quote refresh, auto snapshots).
///
/// `manual` disables the recurring behavior; the action is only performed when
/// the user triggers it explicitly.
enum ScheduleFrequency { daily, weekly, manual }

/// Decides whether a recurring task should run and when it is due next.
///
/// `daily` compares UTC calendar days (at most one attempt per day, so a failed
/// attempt is not retried until the next day). `weekly` runs once at least
/// seven days have elapsed. `manual` never auto-runs.
final class SchedulePolicy {
  const SchedulePolicy(this.clock);

  final DateTime Function() clock;

  bool shouldRun(ScheduleFrequency frequency, DateTime? lastAttemptUtc) {
    if (frequency == ScheduleFrequency.manual) return false;
    if (lastAttemptUtc == null) return true;
    final now = clock().toUtc();
    switch (frequency) {
      case ScheduleFrequency.daily:
        return now.year != lastAttemptUtc.year ||
            now.month != lastAttemptUtc.month ||
            now.day != lastAttemptUtc.day;
      case ScheduleFrequency.weekly:
        return now.difference(lastAttemptUtc.toUtc()).inDays >= 7;
      case ScheduleFrequency.manual:
        return false;
    }
  }

  /// The next run time anchored to the same wall-clock hour as [clock]'s now,
  /// or null for manual (or a daily run already completed today).
  DateTime? nextRun(ScheduleFrequency frequency, DateTime? lastAttemptUtc) {
    if (frequency == ScheduleFrequency.manual) return null;
    final now = clock().toUtc();
    if (!shouldRun(frequency, lastAttemptUtc)) return null;
    switch (frequency) {
      case ScheduleFrequency.daily:
        return DateTime.utc(now.year, now.month, now.day + 1, now.hour,
            now.minute);
      case ScheduleFrequency.weekly:
        final anchor = (lastAttemptUtc ?? now).toUtc();
        final base = DateTime.utc(anchor.year, anchor.month, anchor.day,
            now.hour, now.minute);
        return base.add(const Duration(days: 7));
      case ScheduleFrequency.manual:
        return null;
    }
  }
}
