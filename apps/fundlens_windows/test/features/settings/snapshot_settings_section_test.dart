import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/schedule_policy.dart';
import 'package:fundlens_windows/features/settings/persisted_settings.dart';
import 'package:fundlens_windows/features/settings/snapshot_settings_section.dart';
import 'package:fundlens_windows/storage/app_settings_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

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
  late _FakeAppSettingsRepository settings;

  Future<ProviderContainer> pumpSection(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(settings),
          ...overrides,
        ],
        child: MaterialApp(
          theme: FundLensTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(child: const SnapshotSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SnapshotSettingsSection)),
    );
  }

  setUp(() => settings = _FakeAppSettingsRepository());

  testWidgets('shows switch, frequency, keep count and explanations',
      (tester) async {
    await pumpSection(tester);
    expect(find.text('自动创建快照'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('每天'), findsOneWidget);
    expect(find.text('每周'), findsOneWidget);
    expect(find.text('仅手动'), findsOneWidget);
    expect(find.text('保存数量'), findsOneWidget);
    expect(find.textContaining('仅自动快照参与数量清理'), findsOneWidget);
    expect(find.textContaining('上次自动创建：尚未创建'), findsOneWidget);
  });

  testWidgets('defaults to keep count 10', (tester) async {
    await pumpSection(tester);
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('snapshot-keep-count')),
    );
    expect(field.controller?.text, '10');
  });

  testWidgets('toggling the switch persists the setting', (tester) async {
    final container = await pumpSection(tester);
    expect(container.read(snapshotAutoCreateEnabledProvider), isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(snapshotAutoCreateEnabledProvider), isFalse);
    expect(settings.map[SettingKeys.snapshotAutoCreateEnabled], '0');
  });

  testWidgets('selecting weekly frequency persists it', (tester) async {
    final container = await pumpSection(tester);
    await tester.tap(find.text('每周'));
    await tester.pumpAndSettle();
    expect(
      container.read(snapshotCreateFrequencyProvider),
      ScheduleFrequency.weekly,
    );
    expect(settings.map[SettingKeys.snapshotCreateFrequency], 'weekly');
  });

  testWidgets('editing keep count clamps into 1..100 and persists',
      (tester) async {
    final container = await pumpSection(tester);
    await tester.enterText(
      find.byKey(const ValueKey('snapshot-keep-count')),
      '250',
    );
    await tester.pumpAndSettle();
    expect(container.read(snapshotKeepCountProvider), 100);
    expect(settings.map[SettingKeys.snapshotKeepCount], '100');

    await tester.enterText(
      find.byKey(const ValueKey('snapshot-keep-count')),
      '0',
    );
    await tester.pumpAndSettle();
    expect(container.read(snapshotKeepCountProvider), 1);
    expect(settings.map[SettingKeys.snapshotKeepCount], '1');
  });
}
