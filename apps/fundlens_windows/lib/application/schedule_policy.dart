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

  /// The next scheduled run strictly after now, for display purposes, or null
  /// for manual. `daily` recurs on the last attempt's time-of-day; `weekly`
  /// recurs every seven days from the last attempt.
  DateTime? nextRun(ScheduleFrequency frequency, DateTime? lastAttemptUtc) {
    if (frequency == ScheduleFrequency.manual) return null;
    final now = clock().toUtc();
    final slot = (lastAttemptUtc ?? now).toUtc();
    final step = frequency == ScheduleFrequency.daily
        ? const Duration(days: 1)
        : const Duration(days: 7);
    var next = frequency == ScheduleFrequency.daily
        ? DateTime.utc(slot.year, slot.month, slot.day, slot.hour, slot.minute)
            .add(step)
        : slot.add(step);
    while (!next.isAfter(now)) {
      next = next.add(step);
    }
    return next;
  }
}
