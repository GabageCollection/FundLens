import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/analysis/analysis_page.dart';
import 'package:fundlens_windows/features/analysis/composition_table.dart';
import 'package:fundlens_windows/features/analysis/structure_thresholds.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/widgets/page_scaffold.dart';

final class FakeHoldingRepository implements HoldingRepository {
  FakeHoldingRepository(this._holdings);

  final List<Holding> _holdings;

  @override
  Stream<List<Holding>> watchAll() => Stream.value(_holdings);

  @override
  Future<List<Holding>> getAll() async => _holdings;

  @override
  Future<void> upsert(Holding holding) async {}

  @override
  Future<void> replacePlatform(
    SourcePlatform platform,
    List<Holding> holdings,
  ) async {}

  @override
  Future<void> deleteByIds(List<String> ids) async {}

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();
}

Holding fixtureHolding({
  required String id,
  required String productName,
  required AssetClass assetClass,
  required InstrumentType instrumentType,
  required SourcePlatform sourcePlatform,
  required String currentValue,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: sourcePlatform,
    instrumentType: instrumentType,
    assetClass: assetClass,
    productName: productName,
    currency: 'CNY',
    currentValue: DecimalValue.parse(currentValue),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

Widget analysisHarness({
  StructureThresholds thresholds = const StructureThresholds(),
}) {
  final holdings = [
    fixtureHolding(
      id: 'h-1',
      productName: '成长基金',
      assetClass: AssetClass.equity,
      instrumentType: InstrumentType.offExchangeFund,
      sourcePlatform: SourcePlatform.alipay,
      currentValue: '1000.00',
    ),
    fixtureHolding(
      id: 'h-2',
      productName: '定期存款',
      assetClass: AssetClass.deposit,
      instrumentType: InstrumentType.bankDeposit,
      sourcePlatform: SourcePlatform.manual,
      currentValue: '3000.00',
    ),
  ];
  return ProviderScope(
    overrides: [
      holdingRepositoryProvider.overrideWithValue(
        FakeHoldingRepository(holdings),
      ),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
      structureThresholdsProvider.overrideWith((ref) => thresholds),
    ],
    child: MaterialApp(theme: FundLensTheme.light, home: const AnalysisPage()),
  );
}

/// 复用文件内 providers overrides 搭建方式的可选尺寸泵入辅助。
Future<void> pumpAnalysis(WidgetTester tester, {Size? size}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(analysisHarness());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('analysis does not emit allocation advice', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    for (final forbidden in ['建议', '应当', '调仓', '再平衡', '买入', '卖出']) {
      expect(find.textContaining(forbidden), findsNothing);
    }
  });

  testWidgets('asset class table shows exact amount and share', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();

    expect(find.text('资产类别'), findsOneWidget);
    expect(find.text('3,000.00'), findsOneWidget);
    expect(find.text('1,000.00'), findsOneWidget);
    expect(find.text('75.0%'), findsWidgets);
    expect(find.text('25.0%'), findsWidgets);
  });

  testWidgets('source view groups holdings by platform', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('来源平台'));
    await tester.pumpAndSettle();

    expect(find.text('手工录入'), findsOneWidget);
    expect(find.text('支付宝'), findsOneWidget);
  });

  testWidgets('largest holding and structure facts are factual', (
    tester,
  ) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();

    expect(find.text('最大单项持仓'), findsOneWidget);
    expect(find.text('定期存款'), findsWidgets);
    expect(find.text('现金及存款占比'), findsOneWidget);
    expect(find.text('权益敞口占比'), findsOneWidget);
    expect(find.text('数据完整度'), findsOneWidget);
    // No threshold set: no status judgment is shown.
    expect(find.text('超出你设置的阈值'), findsNothing);
  });

  testWidgets('comparison appears only against a user-set threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      analysisHarness(
        thresholds: StructureThresholds(
          maxSingleHoldingShare: DecimalValue.parse('0.20'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('超出你设置的阈值'), findsOneWidget);
  });

  testWidgets('分析页使用 standard 档 PageScaffold,维度切换移入页头', (tester) async {
    await pumpAnalysis(tester);
    expect(find.byType(PageScaffold), findsOneWidget);
    expect(find.text('资产分析'), findsOneWidget);
    expect(
      find.text('资产类别'),
      findsOneWidget,
    ); // SegmentedButton 在 PageHeader actions
  });

  testWidgets('构成表在窄屏下横向滚动不压缩列', (tester) async {
    await pumpAnalysis(tester, size: const Size(760, 900));
    expect(tester.takeException(), isNull);
    // 构成表行不溢出:存在横向滚动视图
    expect(
      find.descendant(
        of: find.byType(CompositionTable),
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsWidgets,
    );
  });
}
