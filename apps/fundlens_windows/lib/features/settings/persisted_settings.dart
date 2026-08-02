import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/schedule_policy.dart';
import '../analysis/structure_thresholds.dart';

/// Setting keys persisted in the encrypted `app_setting` table.
///
/// Values are plain strings; serialization rules follow each key's comment.
abstract final class SettingKeys {
  /// '0' or '1'; missing means enabled.
  static const autoRefreshEnabled = 'market.autoRefreshEnabled';

  /// [ScheduleFrequency.name]; missing means daily.
  static const refreshFrequency = 'market.refreshFrequency';

  /// ISO-8601 UTC of the last refresh attempt (success or failure).
  static const lastRefreshAttemptAtUtc = 'market.lastRefreshAttemptAtUtc';

  /// '0' or '1'; missing means enabled.
  static const snapshotAutoCreateEnabled = 'snapshot.autoCreateEnabled';

  /// [ScheduleFrequency.name]; missing means daily.
  static const snapshotCreateFrequency = 'snapshot.createFrequency';

  /// Integer string in 1..100; missing means 10.
  static const snapshotKeepCount = 'snapshot.keepCount';

  /// ISO-8601 UTC of the last auto snapshot creation.
  static const snapshotLastAutoCreateAtUtc = 'snapshot.lastAutoCreateAtUtc';

  /// Decimal canonical strings; a missing row means the threshold is unset.
  static const thresholdMaxSingleHolding = 'thresholds.maxSingleHoldingShare';
  static const thresholdMaxAssetClass = 'thresholds.maxAssetClassShare';
  static const thresholdMinCashAndDeposit = 'thresholds.minCashAndDepositShare';
  static const thresholdMaxEquityExposure = 'thresholds.maxEquityExposureShare';

  /// Absolute path of the most recent backup.
  static const backupLastPath = 'backup.lastPath';

  /// ISO-8601 UTC when the most recent backup was created.
  static const backupLastCreatedAtUtc = 'backup.lastCreatedAtUtc';

  /// Integer string with the recorded size in bytes of the most recent backup.
  static const backupLastFileSizeBytes = 'backup.lastFileSizeBytes';
}

/// Whether the automatic quote refresh is enabled. Runtime source of truth;
/// persisted under [SettingKeys.autoRefreshEnabled].
final dailyAutoRefreshEnabledProvider = StateProvider<bool>((ref) => true);

/// Quote refresh cadence. Persisted under [SettingKeys.refreshFrequency].
final refreshFrequencyProvider = StateProvider<ScheduleFrequency>(
  (ref) => ScheduleFrequency.daily,
);

/// Wall-clock schedule policy used to derive next-run times in the UI.
final schedulePolicyProvider = Provider<SchedulePolicy>((ref) {
  return SchedulePolicy(DateTime.now);
});

/// When the next automatic quote refresh will run, or null when the cadence is
/// manual or auto refresh is disabled.
final nextQuoteRefreshProvider = Provider<DateTime?>((ref) {
  final frequency = ref.watch(refreshFrequencyProvider);
  if (frequency == ScheduleFrequency.manual) return null;
  if (!ref.watch(dailyAutoRefreshEnabledProvider)) return null;
  final last = ref.watch(lastRefreshAttemptAtUtcProvider);
  return ref.watch(schedulePolicyProvider).nextRun(frequency, last);
});

/// UTC time of the last refresh attempt. Persisted so the next-run calculation
/// survives restarts.
final lastRefreshAttemptAtUtcProvider = StateProvider<DateTime?>(
  (ref) => null,
);

/// Whether automatic snapshot creation is enabled.
final snapshotAutoCreateEnabledProvider = StateProvider<bool>((ref) => true);

/// Auto snapshot cadence.
final snapshotCreateFrequencyProvider = StateProvider<ScheduleFrequency>(
  (ref) => ScheduleFrequency.daily,
);

/// How many auto snapshots to keep; older ones are pruned.
final snapshotKeepCountProvider = StateProvider<int>((ref) => 10);

/// UTC time of the last auto snapshot creation.
final snapshotLastAutoCreateAtUtcProvider = StateProvider<DateTime?>(
  (ref) => null,
);

/// Facts about the most recent backup, for the backup info rows.
final lastBackupInfoProvider = StateProvider<({String path, DateTime at, int bytes})?>(
  (ref) => null,
);

/// Loads every persisted setting into its runtime provider.
///
/// Called once after the database opens and again after a restore (the
/// replacement database carries the settings that existed at backup time).
Future<void> loadPersistedSettings(ProviderContainer container) async {
  final Map<String, String> all;
  try {
    all = await container.read(appSettingsRepositoryProvider).getAll();
  } catch (_) {
    // The table may be unreadable right after a restore; keep the runtime
    // defaults rather than failing the caller.
    return;
  }

  container.read(dailyAutoRefreshEnabledProvider.notifier).state =
      all[SettingKeys.autoRefreshEnabled] != '0';
  container.read(refreshFrequencyProvider.notifier).state =
      _parseFrequency(all[SettingKeys.refreshFrequency]) ??
          ScheduleFrequency.daily;
  container.read(lastRefreshAttemptAtUtcProvider.notifier).state =
      _parseUtc(all[SettingKeys.lastRefreshAttemptAtUtc]);

  container.read(snapshotAutoCreateEnabledProvider.notifier).state =
      all[SettingKeys.snapshotAutoCreateEnabled] != '0';
  container.read(snapshotCreateFrequencyProvider.notifier).state =
      _parseFrequency(all[SettingKeys.snapshotCreateFrequency]) ??
          ScheduleFrequency.daily;
  container.read(snapshotKeepCountProvider.notifier).state =
      _parseKeepCount(all[SettingKeys.snapshotKeepCount]);
  container.read(snapshotLastAutoCreateAtUtcProvider.notifier).state =
      _parseUtc(all[SettingKeys.snapshotLastAutoCreateAtUtc]);

  container.read(structureThresholdsProvider.notifier).state =
      _thresholdsFromMap(all);

  final path = all[SettingKeys.backupLastPath];
  final at = _parseUtc(all[SettingKeys.backupLastCreatedAtUtc]);
  final bytes = int.tryParse(all[SettingKeys.backupLastFileSizeBytes] ?? '');
  container.read(lastBackupInfoProvider.notifier).state =
      (path != null && at != null && bytes != null)
          ? (path: path, at: at, bytes: bytes)
          : null;
}

/// Persists one setting value. Failures are swallowed: a lost write simply
/// falls back to defaults on the next launch and never blocks the UI.
Future<void> persistSetting(
  ProviderContainer container,
  String key,
  String value,
) async {
  try {
    await container.read(appSettingsRepositoryProvider).set(key, value);
  } catch (_) {
    // Ignore persistence failures; the in-memory provider is authoritative
    // for the current session.
  }
}

ScheduleFrequency? _parseFrequency(String? raw) {
  if (raw == null) return null;
  for (final f in ScheduleFrequency.values) {
    if (f.name == raw) return f;
  }
  return null;
}

DateTime? _parseUtc(String? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

int _parseKeepCount(String? raw) {
  final value = int.tryParse(raw ?? '');
  if (value == null) return 10;
  return value.clamp(1, 100);
}

StructureThresholds _thresholdsFromMap(Map<String, String> all) {
  return StructureThresholds(
    maxSingleHoldingShare:
        _decimal(all[SettingKeys.thresholdMaxSingleHolding]),
    maxAssetClassShare: _decimal(all[SettingKeys.thresholdMaxAssetClass]),
    minCashAndDepositShare:
        _decimal(all[SettingKeys.thresholdMinCashAndDeposit]),
    maxEquityExposureShare:
        _decimal(all[SettingKeys.thresholdMaxEquityExposure]),
  );
}

DecimalValue? _decimal(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return DecimalValue.parse(raw);
  } catch (_) {
    return null;
  }
}
