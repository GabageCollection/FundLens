import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/main.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';

import 'features/import_review/import_review_harness.dart';

final class _FakeSnapshotRepository implements SnapshotRepository {
  @override
  Future<List<PortfolioSnapshot>> getAll() async => const [];

  @override
  Future<PortfolioSnapshot> getById(String id) =>
      throw StateError('not found: $id');

  @override
  Future<String> createFromCurrent({required String label}) async => 'unused';

  @override
  Future<void> deleteById(String id) async {}
}

void main() {
  testWidgets('boots the Windows shell with the six real pages',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holdingRepositoryProvider
              .overrideWithValue(FakeHoldingRepository()),
          snapshotRepositoryProvider
              .overrideWithValue(_FakeSnapshotRepository()),
          portfolioCalculatorProvider
              .overrideWithValue(PortfolioCalculator()),
          dataQualityCalculatorProvider
              .overrideWithValue(DataQualityCalculator()),
          dataEngineClientProvider.overrideWithValue(FakeDataEngineClient()),
          importFilePickerProvider.overrideWithValue(FakeImportFilePicker()),
          screenshotTempStoreProvider
              .overrideWithValue(FakeScreenshotTempStore()),
          importDraftStoreProvider
              .overrideWithValue(InMemoryImportDraftStore()),
        ],
        child: const FundLensBootstrapApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FundLens'), findsOneWidget);
    for (final label in [
      '资产总览',
      '资产分析',
      '全部持仓',
      '历史快照',
      '导入与识别',
      '设置与备份',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });
}
