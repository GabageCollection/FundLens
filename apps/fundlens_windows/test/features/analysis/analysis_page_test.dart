import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/analysis/analysis_page.dart';
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
  String? costAmount,
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
    costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

Widget analysisHarness({List<Holding>? holdings}) {
  final fixture =
      holdings ??
      [
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
          costAmount: '3000.00',
        ),
      ];
  return ProviderScope(
    overrides: [
      holdingRepositoryProvider.overrideWithValue(
        FakeHoldingRepository(fixture),
      ),
      portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
      structureThresholdsProvider.overrideWith(
        (ref) => const StructureThresholds(),
      ),
    ],
    child: MaterialApp(theme: FundLensTheme.light, home: const AnalysisPage()),
  );
}

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

  testWidgets('资产类别图表显示金额与占比', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    // KPI 汇总条也有“资产类别”标签,断言限定在 TabBar 内。
    expect(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.text('资产类别'),
      ),
      findsOneWidget,
    );
    expect(find.text('¥3,000.00'), findsOneWidget);
    expect(find.text('¥1,000.00'), findsOneWidget);
    expect(find.text('75.0%'), findsWidgets);
    expect(find.text('25.0%'), findsWidgets);
  });

  testWidgets('来源平台 Tab 切换后显示平台图例', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('来源平台'));
    await tester.pumpAndSettle();
    expect(find.text('手工录入'), findsOneWidget);
    expect(find.text('支付宝'), findsOneWidget);
  });

  testWidgets('Tabs 支持键盘左右切换', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    // Flutter TabBar 键盘交互:Tab 键聚焦 Tab → 左右方向键移动焦点 → Enter 激活。
    // (原生 TabBar 无"方向键直接切 tab"行为,故按官方焦点模型驱动。)
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // 已切到"产品类型":图表显示产品类型标签
    expect(find.text('场外基金'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('来源平台'), findsOneWidget);
    expect(find.text('手工录入'), findsOneWidget);
  });

  testWidgets('切换维度时图表区高度不变(布局稳定)', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    final before = tester.getSize(
      find.byKey(const ValueKey('analysis-chart-area')),
    );
    await tester.tap(find.text('来源平台'));
    await tester.pumpAndSettle();
    final after = tester.getSize(
      find.byKey(const ValueKey('analysis-chart-area')),
    );
    expect(after.height, before.height);
    await tester.tap(find.text('产品类型'));
    await tester.pumpAndSettle();
    final afterSecond = tester.getSize(
      find.byKey(const ValueKey('analysis-chart-area')),
    );
    expect(afterSecond.height, before.height);
  });

  testWidgets('分析结论卡显示五项结论与状态', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    expect(find.text('分析结论'), findsOneWidget);
    expect(find.text('资产结构'), findsOneWidget);
    expect(find.text('集中度'), findsOneWidget);
    expect(find.text('数据质量'), findsOneWidget);
    expect(find.text('收益覆盖'), findsOneWidget);
    expect(find.text('行情新鲜度'), findsOneWidget);
    expect(find.text('正常'), findsWidgets);
  });

  testWidgets('全部资产为"其他"时输出数据质量警告而非误导性结论', (tester) async {
    await tester.pumpWidget(
      analysisHarness(
        holdings: [
          fixtureHolding(
            id: 'h-1',
            productName: '未分类产品',
            assetClass: AssetClass.other,
            instrumentType: InstrumentType.offExchangeFund,
            sourcePlatform: SourcePlatform.alipay,
            currentValue: '5000.00',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('需要处理'), findsOneWidget);
    expect(find.text('补充资产分类'), findsOneWidget);
    expect(find.textContaining('请补充资产类别'), findsOneWidget);
    expect(find.text('最大资产类别'), findsNothing);
  });

  testWidgets('无持仓时显示空状态与添加入口', (tester) async {
    await tester.pumpWidget(analysisHarness(holdings: []));
    await tester.pumpAndSettle();
    expect(find.text('添加第一项资产'), findsOneWidget);
  });

  testWidgets('分析页使用 standard 档 PageScaffold', (tester) async {
    await pumpAnalysis(tester);
    expect(find.byType(PageScaffold), findsOneWidget);
    expect(find.text('资产分析'), findsOneWidget);
  });

  testWidgets('分析页顶部 KPI 区显示结构指标', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    // 夹具:权益 1000(无成本)+ 存款 3000(有成本),总资产 4000。
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('¥4,000.00'), findsOneWidget);
    expect(find.text('持仓项数'), findsOneWidget);
    expect(find.text('2 项'), findsOneWidget);
    expect(find.text('2 类'), findsOneWidget);
    expect(find.text('最大持仓占比'), findsOneWidget);
    expect(find.text('收益覆盖率'), findsOneWidget);
  });

  testWidgets('结论卡行间以分隔线分组', (tester) async {
    await tester.pumpWidget(analysisHarness());
    await tester.pumpAndSettle();
    final conclusionsCard = find.ancestor(
      of: find.text('分析结论'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: conclusionsCard, matching: find.byType(Divider)),
      findsWidgets,
    );
  });

  testWidgets('窄屏(760px)下堆叠且不溢出', (tester) async {
    await pumpAnalysis(tester, size: const Size(760, 900));
    expect(tester.takeException(), isNull);
  });
}
