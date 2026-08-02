import 'package:fundlens_windows/application/schedule_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SchedulePolicy shouldRun', () {
    test('daily runs when there was no previous attempt', () {
      final policy = SchedulePolicy(() => DateTime.utc(2026, 7, 21, 9));
      expect(
        policy.shouldRun(ScheduleFrequency.daily, null),
        isTrue,
      );
    });

    test('daily does not run twice on the same UTC day', () {
      var now = DateTime.utc(2026, 7, 21, 9);
      final policy = SchedulePolicy(() => now);
      expect(
        policy.shouldRun(
          ScheduleFrequency.daily,
          DateTime.utc(2026, 7, 21, 2),
        ),
        isFalse,
      );
      now = DateTime.utc(2026, 7, 21, 23, 59);
      expect(
        policy.shouldRun(
          ScheduleFrequency.daily,
          DateTime.utc(2026, 7, 21, 2),
        ),
        isFalse,
      );
    });

    test('daily runs again on the next UTC day', () {
      final policy = SchedulePolicy(() => DateTime.utc(2026, 7, 22, 0, 1));
      expect(
        policy.shouldRun(
          ScheduleFrequency.daily,
          DateTime.utc(2026, 7, 21, 23, 59),
        ),
        isTrue,
      );
    });

    test('daily runs again across month and year boundaries', () {
      final policy = SchedulePolicy(() => DateTime.utc(2027, 1, 1));
      expect(
        policy.shouldRun(
          ScheduleFrequency.daily,
          DateTime.utc(2026, 12, 31, 23),
        ),
        isTrue,
      );
      expect(
        policy.shouldRun(
          ScheduleFrequency.daily,
          DateTime.utc(2026, 7, 21),
        ),
        isTrue,
      );
    });

    test('weekly runs after at least seven days', () {
      final now = DateTime.utc(2026, 7, 21, 9);
      final policy = SchedulePolicy(() => now);
      expect(
        policy.shouldRun(
          ScheduleFrequency.weekly,
          DateTime.utc(2026, 7, 14, 9),
        ),
        isTrue,
      );
    });

    test('weekly does not run within seven days', () {
      final now = DateTime.utc(2026, 7, 21, 9);
      final policy = SchedulePolicy(() => now);
      expect(
        policy.shouldRun(
          ScheduleFrequency.weekly,
          DateTime.utc(2026, 7, 15, 9),
        ),
        isFalse,
      );
      expect(
        policy.shouldRun(
          ScheduleFrequency.weekly,
          DateTime.utc(2026, 7, 21, 8),
        ),
        isFalse,
      );
    });

    test('weekly runs with no previous attempt', () {
      final policy = SchedulePolicy(() => DateTime.utc(2026, 7, 21, 9));
      expect(policy.shouldRun(ScheduleFrequency.weekly, null), isTrue);
    });

    test('manual never runs', () {
      final policy = SchedulePolicy(() => DateTime.utc(2026, 7, 21, 9));
      expect(policy.shouldRun(ScheduleFrequency.manual, null), isFalse);
      expect(
        policy.shouldRun(
          ScheduleFrequency.manual,
          DateTime.utc(2026, 7, 1),
        ),
        isFalse,
      );
    });
  });

  group('SchedulePolicy nextRun', () {
    test('manual has no next run', () {
      final policy = SchedulePolicy(() => DateTime.utc(2026, 7, 21, 9));
      expect(
        policy.nextRun(ScheduleFrequency.manual, null),
        isNull,
      );
    });

    test('daily next run is the next UTC day', () {
      final policy = SchedulePolicy(() => DateTime.utc(2026, 7, 21, 9));
      expect(
        policy.nextRun(ScheduleFrequency.daily, null),
        DateTime.utc(2026, 7, 22, 9),
      );
      // Slot day (7-20) in the past at an earlier hour rolls to tomorrow.
      expect(
        policy.nextRun(
          ScheduleFrequency.daily,
          DateTime.utc(2026, 7, 20, 7),
        ),
        DateTime.utc(2026, 7, 22, 7),
      );
    });

    test('weekly next run is the next weekly boundary after now', () {
      final policy = SchedulePolicy(() => DateTime.utc(2026, 7, 21, 9));
      // 7-17 boundary is in the past; walk forward to 7-24.
      expect(
        policy.nextRun(
          ScheduleFrequency.weekly,
          DateTime.utc(2026, 7, 10, 6),
        ),
        DateTime.utc(2026, 7, 24, 6),
      );
      expect(
        policy.nextRun(
          ScheduleFrequency.weekly,
          DateTime.utc(2026, 7, 20, 8),
        ),
        DateTime.utc(2026, 7, 27, 8),
      );
    });
  });
}
