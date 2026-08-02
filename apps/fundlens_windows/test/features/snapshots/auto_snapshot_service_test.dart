import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/schedule_policy.dart';
import 'package:fundlens_windows/features/settings/persisted_settings.dart';
import 'package:fundlens_windows/features/snapshots/auto_snapshot_service.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/app_settings_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';

final class _FakeAppSettingsRepository implements AppSettingsRepository {
  final Map<String, String> map = {};

  @override
  Future<String?> get(String key) async => map[key];

  @override
  Future<Map<String, String>> getAll() async => Map.of(map);

  @override
  Future<void> set(String key, String value) async => map[key] = value;

  @override
  Future<void> delete(String key) async => map.remove(key);
}

void main() {
  late AppDatabase db;
  late SnapshotRepository snapshots;
  late _FakeAppSettingsRepository settings;
  late ProviderContainer container;
  var now = DateTime.utc(2026, 7, 21, 9);

  void buildContainer({
    bool enabled = true,
    ScheduleFrequency frequency = ScheduleFrequency.daily,
    DateTime? lastAuto,
    int keepCount = 10,
  }) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    snapshots = DriftSnapshotRepository(db);
    settings = _FakeAppSettingsRepository();
    container = ProviderContainer(
      overrides: [
        snapshotRepositoryProvider.overrideWithValue(snapshots),
        appSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    container.read(snapshotAutoCreateEnabledProvider.notifier).state = enabled;
    container.read(snapshotCreateFrequencyProvider.notifier).state = frequency;
    container.read(snapshotKeepCountProvider.notifier).state = keepCount;
    container.read(snapshotLastAutoCreateAtUtcProvider.notifier).state = lastAuto;
  }

  AutoSnapshotService service() => AutoSnapshotService(
        container: container,
        policy: SchedulePolicy(() => now),
        clock: () => now,
      );

  group('runIfDue', () {
    test('disabled: no snapshot created, nothing persisted', () async {
      buildContainer(enabled: false);
      await service().runIfDue();
      expect(await snapshots.getAll(), isEmpty);
      expect(settings.map, isEmpty);
    });

    test('manual frequency: no snapshot created', () async {
      buildContainer(frequency: ScheduleFrequency.manual);
      await service().runIfDue();
      expect(await snapshots.getAll(), isEmpty);
    });

    test('due daily: creates an auto snapshot and records the time', () async {
      buildContainer(lastAuto: DateTime.utc(2026, 7, 20, 8));
      await service().runIfDue();
      final all = await snapshots.getAll();
      expect(all, hasLength(1));
      expect(all.single.label, '自动快照 2026-07-21');
      expect(
        container.read(snapshotLastAutoCreateAtUtcProvider),
        now,
      );
      expect(
        settings.map[SettingKeys.snapshotLastAutoCreateAtUtc],
        now.toIso8601String(),
      );
    });

    test('not due (created today): no new snapshot', () async {
      buildContainer(lastAuto: DateTime.utc(2026, 7, 21, 7));
      now = DateTime.utc(2026, 7, 21, 9);
      await service().runIfDue();
      expect(await snapshots.getAll(), isEmpty);
    });
  });

  group('prune', () {
    test('removes oldest auto snapshots beyond keep count only', () async {
      buildContainer(keepCount: 2);
      for (var i = 0; i < 3; i++) {
        await snapshots.createFromCurrent(label: '自动快照 2026-07-0$i');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      // 手动快照永远保留。
      await snapshots.createFromCurrent(label: '手动重要快照');

      final removed = await service().prune();

      expect(removed, 1);
      final remaining = await snapshots.getAll();
      final labels = remaining.map((s) => s.label).toList();
      expect(labels, contains('自动快照 2026-07-02'));
      expect(labels, contains('手动重要快照'));
      expect(labels, isNot(contains('自动快照 2026-07-00')));
      expect(remaining.where((s) => s.label.startsWith('自动快照 ')), hasLength(2));
    });

    test('does nothing when within keep count', () async {
      buildContainer(keepCount: 10);
      await snapshots.createFromCurrent(label: '自动快照 2026-07-01');
      final removed = await service().prune();
      expect(removed, 0);
      expect(await snapshots.getAll(), hasLength(1));
    });

    test('keeps only the newest when keep count is 1', () async {
      buildContainer(keepCount: 1);
      for (var i = 0; i < 3; i++) {
        await snapshots.createFromCurrent(label: '自动快照 2026-07-0$i');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final removed = await service().prune();
      expect(removed, 2);
      final labels =
          (await snapshots.getAll()).map((s) => s.label).toList();
      expect(labels, ['自动快照 2026-07-02']);
    });
  });

  group('auto snapshot label', () {
    test('exposes the auto prefix and matcher', () {
      expect(AutoSnapshotService.isAutoSnapshotLabel('自动快照 2026-07-21'), isTrue);
      expect(AutoSnapshotService.isAutoSnapshotLabel('手动快照'), isFalse);
    });
  });
}
