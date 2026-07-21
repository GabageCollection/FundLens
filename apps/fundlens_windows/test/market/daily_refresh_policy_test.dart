import 'package:fundlens_windows/market/daily_refresh_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DailyRefreshPolicy', () {
    test('runs when there was no previous attempt', () {
      final policy = DailyRefreshPolicy(() => DateTime.utc(2026, 7, 21, 9));
      expect(policy.shouldRun(null), isTrue);
    });

    test('does not run twice on the same UTC day', () {
      var now = DateTime.utc(2026, 7, 21, 9);
      final policy = DailyRefreshPolicy(() => now);
      expect(policy.shouldRun(DateTime.utc(2026, 7, 21, 2)), isFalse);
      now = DateTime.utc(2026, 7, 21, 23, 59);
      expect(policy.shouldRun(DateTime.utc(2026, 7, 21, 2)), isFalse);
    });

    test('runs again on the next UTC day', () {
      final policy = DailyRefreshPolicy(() => DateTime.utc(2026, 7, 22, 0, 1));
      expect(policy.shouldRun(DateTime.utc(2026, 7, 21, 23, 59)), isTrue);
    });

    test('runs again across month and year boundaries', () {
      final policy = DailyRefreshPolicy(() => DateTime.utc(2027, 1, 1));
      expect(policy.shouldRun(DateTime.utc(2026, 12, 31, 23)), isTrue);
      expect(policy.shouldRun(DateTime.utc(2026, 7, 21)), isTrue);
    });
  });
}
