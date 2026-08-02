import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/analysis/structure_thresholds.dart';
import 'package:fundlens_windows/features/settings/asset_rules_section.dart';
import 'package:fundlens_windows/features/settings/persisted_settings.dart';
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
            body: SingleChildScrollView(child: const AssetRulesSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(AssetRulesSection)),
    );
  }

  setUp(() => settings = _FakeAppSettingsRepository());

  testWidgets('advanced settings are collapsed by default', (tester) async {
    await pumpSection(tester);
    expect(find.text('资产识别规则'), findsOneWidget);
    expect(find.text('高级设置'), findsOneWidget);
    // 折叠时不渲染参数输入框。
    expect(
      find.byKey(const ValueKey('threshold-maxSingleHoldingShare')),
      findsNothing,
    );
  });

  testWidgets('expanding shows all four labeled parameters', (tester) async {
    await pumpSection(tester);
    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();
    expect(find.text('单一持仓占比上限'), findsOneWidget);
    expect(find.text('单一类别占比上限'), findsOneWidget);
    expect(find.text('现金及存款占比下限'), findsOneWidget);
    expect(find.text('权益仓位占比上限'), findsOneWidget);
    expect(find.text('默认：未设置（不提示）'), findsNWidgets(4));
    expect(find.text('恢复默认'), findsNWidgets(4));
  });

  testWidgets('editing a threshold writes provider and persists', (tester) async {
    final container = await pumpSection(tester);
    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('threshold-maxSingleHoldingShare')),
      '35',
    );
    await tester.pumpAndSettle();

    final thresholds = container.read(structureThresholdsProvider);
    expect(thresholds.maxSingleHoldingShare, isNotNull);
    expect(
      thresholds.maxSingleHoldingShare!.value.toDouble(),
      closeTo(0.35, 0.0001),
    );
    expect(
      settings.map[SettingKeys.thresholdMaxSingleHolding],
      '0.35',
    );
    expect(thresholds.maxAssetClassShare, isNull);
  });

  testWidgets('restoring default clears the value and deletes the key',
      (tester) async {
    final container = await pumpSection(tester);
    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('threshold-maxSingleHoldingShare')),
      '35',
    );
    await tester.pumpAndSettle();
    expect(container.read(structureThresholdsProvider).maxSingleHoldingShare, isNotNull);

    await tester.tap(find.text('恢复默认').first);
    await tester.pumpAndSettle();

    expect(container.read(structureThresholdsProvider).maxSingleHoldingShare, isNull);
    expect(
      settings.map.containsKey(SettingKeys.thresholdMaxSingleHolding),
      isFalse,
    );
  });

  testWidgets('illegal or negative input is ignored', (tester) async {
    final container = await pumpSection(tester);
    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('threshold-maxSingleHoldingShare')),
      '-5',
    );
    await tester.pumpAndSettle();

    expect(container.read(structureThresholdsProvider).maxSingleHoldingShare, isNull);
  });
}
