import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/schedule_policy.dart';
import 'package:fundlens_windows/features/analysis/structure_thresholds.dart';
import 'package:fundlens_windows/features/settings/persisted_settings.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/app_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loadPersistedSettings', () {
    late ProviderContainer container;
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(
            DriftAppSettingsRepository(db),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
    });

    test('uses defaults when nothing is persisted', () async {
      await loadPersistedSettings(container);

      expect(container.read(dailyAutoRefreshEnabledProvider), isTrue);
      expect(
        container.read(refreshFrequencyProvider),
        ScheduleFrequency.daily,
      );
      expect(container.read(lastRefreshAttemptAtUtcProvider), isNull);
      expect(container.read(snapshotAutoCreateEnabledProvider), isTrue);
      expect(
        container.read(snapshotCreateFrequencyProvider),
        ScheduleFrequency.daily,
      );
      expect(container.read(snapshotKeepCountProvider), 10);
      expect(container.read(snapshotLastAutoCreateAtUtcProvider), isNull);
      expect(container.read(structureThresholdsProvider), const StructureThresholds());
      expect(container.read(lastBackupInfoProvider), isNull);
    });

    test('loads persisted market and snapshot settings', () async {
      final repo = container.read(appSettingsRepositoryProvider);
      await repo.set(SettingKeys.autoRefreshEnabled, '0');
      await repo.set(SettingKeys.refreshFrequency, 'weekly');
      await repo.set(
        SettingKeys.lastRefreshAttemptAtUtc,
        DateTime.utc(2026, 7, 20, 8).toIso8601String(),
      );
      await repo.set(SettingKeys.snapshotAutoCreateEnabled, '1');
      await repo.set(SettingKeys.snapshotCreateFrequency, 'weekly');
      await repo.set(SettingKeys.snapshotKeepCount, '25');
      await repo.set(
        SettingKeys.snapshotLastAutoCreateAtUtc,
        DateTime.utc(2026, 7, 19, 9).toIso8601String(),
      );

      await loadPersistedSettings(container);

      expect(container.read(dailyAutoRefreshEnabledProvider), isFalse);
      expect(
        container.read(refreshFrequencyProvider),
        ScheduleFrequency.weekly,
      );
      expect(
        container.read(lastRefreshAttemptAtUtcProvider),
        DateTime.utc(2026, 7, 20, 8),
      );
      expect(container.read(snapshotAutoCreateEnabledProvider), isTrue);
      expect(
        container.read(snapshotCreateFrequencyProvider),
        ScheduleFrequency.weekly,
      );
      expect(container.read(snapshotKeepCountProvider), 25);
      expect(
        container.read(snapshotLastAutoCreateAtUtcProvider),
        DateTime.utc(2026, 7, 19, 9),
      );
    });

    test('clamps keep count into 1..100', () async {
      final repo = container.read(appSettingsRepositoryProvider);
      await repo.set(SettingKeys.snapshotKeepCount, '999');
      await loadPersistedSettings(container);
      expect(container.read(snapshotKeepCountProvider), 100);

      await repo.set(SettingKeys.snapshotKeepCount, '0');
      await loadPersistedSettings(container);
      expect(container.read(snapshotKeepCountProvider), 1);
    });

    test('loads persisted thresholds', () async {
      final repo = container.read(appSettingsRepositoryProvider);
      await repo.set(SettingKeys.thresholdMaxSingleHolding, '0.35');
      await repo.set(SettingKeys.thresholdMaxAssetClass, '0.5');

      await loadPersistedSettings(container);

      final thresholds = container.read(structureThresholdsProvider);
      expect(thresholds.maxSingleHoldingShare?.canonical, '0.35');
      expect(thresholds.maxAssetClassShare?.canonical, '0.5');
      expect(thresholds.minCashAndDepositShare, isNull);
      expect(thresholds.maxEquityExposureShare, isNull);
    });

    test('loads last backup info', () async {
      final repo = container.read(appSettingsRepositoryProvider);
      await repo.set(SettingKeys.backupLastPath, r'C:\tmp\fundlens.bak');
      await repo.set(
        SettingKeys.backupLastCreatedAtUtc,
        DateTime.utc(2026, 7, 18, 6).toIso8601String(),
      );
      await repo.set(SettingKeys.backupLastFileSizeBytes, '2048');

      await loadPersistedSettings(container);

      final info = container.read(lastBackupInfoProvider);
      expect(info?.path, r'C:\tmp\fundlens.bak');
      expect(info?.at, DateTime.utc(2026, 7, 18, 6));
      expect(info?.bytes, 2048);
    });
  });

  group('persistSetting', () {
    test('writes the value through the repository', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(
            DriftAppSettingsRepository(db),
          ),
        ],
      );
      addTearDown(container.dispose);

      await persistSetting(container, SettingKeys.refreshFrequency, 'weekly');

      expect(
        await container.read(appSettingsRepositoryProvider).get(
              SettingKeys.refreshFrequency,
            ),
        'weekly',
      );
    });
  });
}
