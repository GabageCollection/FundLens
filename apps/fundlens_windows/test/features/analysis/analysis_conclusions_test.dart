import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/app/app_shell.dart';
import 'package:fundlens_windows/features/analysis/analysis_conclusions.dart';
import 'package:fundlens_windows/features/analysis/structure_thresholds.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

Holding fixtureHolding({
  required String id,
  required AssetClass assetClass,
  String? costAmount,
  ValuationMethod valuationMethod = ValuationMethod.manualAmount,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: '持仓$id',
    currency: 'CNY',
    currentValue: DecimalValue.parse('1000'),
    costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
    valuationMethod: valuationMethod,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

PortfolioSummary fakeSummary({
  Map<AssetClass, DecimalValue> byAssetClass = const {},
  String totalValue = '1000',
  String returnCoverage = '1',
  String largestHoldingShare = '1',
}) {
  return PortfolioSummary(
    totalValue: DecimalValue.parse(totalValue),
    totalCost: DecimalValue.zero,
    totalFloatingProfit: DecimalValue.zero,
    totalReturn: null,
    returnCoverage: DecimalValue.parse(returnCoverage),
    byAssetClass: byAssetClass,
    byInstrumentType: const {},
    bySource: const {},
    holdingShares: const {},
    largestHoldingShare: DecimalValue.parse(largestHoldingShare),
    largestAssetClassShare: DecimalValue.zero,
    cashAndDepositShare: DecimalValue.zero,
    equityExposureShare: DecimalValue.zero,
  );
}

DataQualitySummary fakeQuality({
  String dataCompleteness = '1',
  String? quoteFreshness = '1',
}) {
  return DataQualitySummary(
    dataCompleteness: DecimalValue.parse(dataCompleteness),
    quoteFreshness: quoteFreshness == null
        ? null
        : DecimalValue.parse(quoteFreshness),
  );
}

void main() {
  test('全部资产归入"其他"时输出数据质量警告而非正常结论', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.other: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.other)],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    final structure = items[0];
    expect(structure.name, '资产结构');
    expect(structure.result, '0.0%'); // 分类率 = 1 − 100%
    expect(structure.status, ConclusionStatus.warning);
    expect(structure.explanation, contains('补充资产类别'));
    expect(structure.action, AppDestination.holdings);
    expect(structure.actionLabel, '补充资产分类');
    // 全其他场景不出现"最大资产类别"结论
    expect(items.map((i) => i.name), isNot(contains('最大资产类别')));
  });

  test('部分未分类输出需要处理与入口', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {
          AssetClass.equity: DecimalValue.parse('600'),
          AssetClass.other: DecimalValue.parse('400'),
        },
        totalValue: '1000',
      ),
      quality: fakeQuality(),
      holdings: [
        fixtureHolding(id: 'h-1', assetClass: AssetClass.equity),
        fixtureHolding(id: 'h-2', assetClass: AssetClass.other),
      ],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    expect(items[0].result, '60.0%');
    expect(items[0].status, ConclusionStatus.warning);
    expect(items[0].actionLabel, '补充资产分类');
  });

  test('全部分类完成时资产结构正常且无入口', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    expect(items[0].result, '100.0%');
    expect(items[0].status, ConclusionStatus.normal);
    expect(items[0].action, isNull);
  });

  test('集中度:未设阈值时不作判断,超出阈值时警告并提供入口', () {
    final noThreshold = buildAnalysisConclusions(
      summary: fakeSummary(largestHoldingShare: '0.8'),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    expect(noThreshold[1].status, isNull);

    final breached = buildAnalysisConclusions(
      summary: fakeSummary(largestHoldingShare: '0.8'),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: StructureThresholds(
        maxSingleHoldingShare: DecimalValue.parse('0.5'),
      ),
      freshQuoteHoldingIds: const <String>{},
    );
    expect(breached[1].status, ConclusionStatus.warning);
    expect(breached[1].action, AppDestination.holdings);
    expect(breached[1].result, contains('持仓h-1'));
  });

  test('收益覆盖不足时提示并给出未覆盖金额', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
        totalValue: '1000',
        returnCoverage: '0.6',
      ),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    final coverage = items[3];
    expect(coverage.result, '60.0%');
    expect(coverage.status, ConclusionStatus.attention);
    expect(coverage.explanation, contains('400.00')); // 1000 − 600
    expect(coverage.action, AppDestination.holdings);
  });

  test('行情新鲜度:无自动行情时为 —,未全部更新时提示', () {
    final none = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(quoteFreshness: null),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    expect(none[4].result, '—');
    expect(none[4].status, isNull);

    final stale = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(quoteFreshness: '0.5'),
      holdings: [
        fixtureHolding(
          id: 'h-1',
          assetClass: AssetClass.equity,
          valuationMethod: ValuationMethod.automaticQuote,
        ),
      ],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    expect(stale[4].status, ConclusionStatus.attention);
    expect(stale[4].action, AppDestination.importReview);
  });

  test('五项结论顺序固定', () {
    final items = buildAnalysisConclusions(
      summary: fakeSummary(
        byAssetClass: {AssetClass.equity: DecimalValue.parse('1000')},
      ),
      quality: fakeQuality(),
      holdings: [fixtureHolding(id: 'h-1', assetClass: AssetClass.equity)],
      thresholds: const StructureThresholds(),
      freshQuoteHoldingIds: const <String>{},
    );
    expect(items.map((i) => i.name).toList(), [
      '资产结构',
      '集中度',
      '数据质量',
      '收益覆盖',
      '行情新鲜度',
    ]);
  });

  testWidgets('结论卡显示五项的名称/结果/解释与状态标签', (tester) async {
    final items = [
      ConclusionItem(
        name: '资产结构',
        result: '0.0%',
        status: ConclusionStatus.warning,
        explanation: '全部资产暂时被归入"其他",请补充资产类别后再进行结构分析。',
        action: AppDestination.holdings,
        actionLabel: '补充资产分类',
      ),
      ConclusionItem(name: '集中度', result: '持仓h-1 100.0%', explanation: '未设置集中度阈值,仅展示实际占比。'),
      ConclusionItem(
        name: '数据质量',
        result: '100.0%',
        status: ConclusionStatus.normal,
        explanation: '持仓字段完整,可直接进行结构分析。',
      ),
      ConclusionItem(name: '收益覆盖', result: '100.0%', explanation: '全部资产均纳入收益统计。'),
      ConclusionItem(name: '行情新鲜度', result: '—', explanation: '没有自动行情持仓,不涉及行情新鲜度。'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(
          body: AnalysisConclusionsCard(items: items),
        ),
      ),
    );
    expect(find.text('资产结构'), findsOneWidget);
    expect(find.text('0.0%'), findsOneWidget);
    expect(find.text('需要处理'), findsOneWidget); // warning chip 文案
    expect(find.textContaining('补充资产类别'), findsOneWidget);
    expect(find.text('补充资产分类'), findsOneWidget); // 修复入口按钮
    expect(find.text('正常'), findsOneWidget); // 数据质量 normal chip
    expect(find.textContaining('持仓字段完整'), findsOneWidget);
  });

  testWidgets('状态 chip 在无状态时不渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(
          body: AnalysisConclusionsCard(
            items: [
              ConclusionItem(
                name: '集中度',
                result: '50.0%',
                explanation: '未设置集中度阈值,仅展示实际占比。',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('正常'), findsNothing);
    expect(find.text('需要处理'), findsNothing);
  });

  testWidgets('点击修复入口发出 SelectDestinationIntent', (tester) async {
    AppDestination? dispatched;
    await tester.pumpWidget(
      MaterialApp(
        theme: FundLensTheme.light,
        home: Actions(
          actions: {
            SelectDestinationIntent: CallbackAction<SelectDestinationIntent>(
              onInvoke: (intent) {
                dispatched = intent.destination;
                return null;
              },
            ),
          },
          child: Scaffold(
            body: AnalysisConclusionsCard(
              items: [
                ConclusionItem(
                  name: '资产结构',
                  result: '0.0%',
                  status: ConclusionStatus.warning,
                  explanation: '全部资产暂时被归入"其他"。',
                  action: AppDestination.holdings,
                  actionLabel: '补充资产分类',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('补充资产分类'));
    await tester.pump();
    expect(dispatched, AppDestination.holdings);
  });
}
