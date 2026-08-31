import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/analysis/analysis_chart.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

PortfolioSummary fakeSummary({
  Map<AssetClass, DecimalValue> byAssetClass = const {},
  Map<InstrumentType, DecimalValue> byInstrumentType = const {},
  Map<SourcePlatform, DecimalValue> bySource = const {},
  String totalValue = '10000',
}) {
  return PortfolioSummary(
    totalValue: DecimalValue.parse(totalValue),
    totalCost: DecimalValue.zero,
    totalFloatingProfit: DecimalValue.zero,
    totalReturn: null,
    returnCoverage: DecimalValue.zero,
    byAssetClass: byAssetClass,
    byInstrumentType: byInstrumentType,
    bySource: bySource,
    holdingShares: const {},
    largestHoldingShare: DecimalValue.zero,
    largestAssetClassShare: DecimalValue.zero,
    cashAndDepositShare: DecimalValue.zero,
    equityExposureShare: DecimalValue.zero,
  );
}

Widget chartHarness(Widget child) => MaterialApp(
  theme: FundLensTheme.light,
  home: Scaffold(body: child),
);

final testRows = [
  ChartBarRow(
    label: '权益',
    amount: DecimalValue.parse('30000'),
    share: DecimalValue.parse('0.38'),
  ),
  ChartBarRow(
    label: '现金',
    amount: DecimalValue.parse('12000'),
    share: DecimalValue.parse('0.152'),
  ),
  ChartBarRow(
    label: '其余 2 项',
    amount: DecimalValue.parse('8000'),
    share: DecimalValue.parse('0.101'),
    isAggregate: true,
  ),
];

void main() {
  test('≤6 项全部显示且按金额降序,占比可追溯到金额', () {
    final summary = fakeSummary(
      byAssetClass: {
        AssetClass.cash: DecimalValue.parse('1000'),
        AssetClass.equity: DecimalValue.parse('3000'),
        AssetClass.gold: DecimalValue.parse('2000'),
      },
      totalValue: '6000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.map((r) => r.label).toList(), ['权益', '黄金', '现金']);
    expect(rows[0].amount.canonical, '3000');
    expect(rows[0].share.canonical, '0.5'); // 3000 ÷ 6000
    expect(rows.every((r) => !r.isAggregate), isTrue);
  });

  test('超过 6 项时取前 5 并合并其余为"其他"聚合行', () {
    final byAssetClass = <AssetClass, DecimalValue>{
      for (final (i, c) in AssetClass.values.indexed)
        c: DecimalValue.parse('${(i + 1) * 1000}'),
    }; // 7 类:1000..7000,其他=7000 最大
    final summary = fakeSummary(
      byAssetClass: byAssetClass,
      totalValue: '28000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.length, 6);
    expect(rows.last.label, '其余 2 项');
    expect(rows.last.isAggregate, isTrue);
    expect(rows.last.amount.canonical, '3000'); // 降序前 5 之后的最小 2 项:2000+1000
    expect(
      rows.last.share.canonical,
      '0.10714285',
    ); // 3000 ÷ 28000,DecimalValue 除法按 8 位截断
  });

  test('产品类型 9 类触发合并', () {
    final byInstrumentType = <InstrumentType, DecimalValue>{
      for (final (i, t) in InstrumentType.values.indexed)
        t: DecimalValue.parse('${(i + 1) * 1000}'),
    };
    final summary = fakeSummary(
      byInstrumentType: byInstrumentType,
      totalValue: '45000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.instrumentType);
    expect(rows.length, 6);
    expect(rows.last.isAggregate, isTrue);
    expect(rows.first.label, '实物黄金'); // 9000 最大
  });

  test('来源平台 3 项全部显示', () {
    final summary = fakeSummary(
      bySource: {
        SourcePlatform.alipay: DecimalValue.parse('5000'),
        SourcePlatform.ths: DecimalValue.parse('3000'),
        SourcePlatform.manual: DecimalValue.parse('2000'),
      },
      totalValue: '10000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.source);
    expect(rows.map((r) => r.label).toList(), ['支付宝', '同花顺', '手工录入']);
    expect(rows.length, 3);
  });

  test('零金额项被过滤', () {
    final summary = fakeSummary(
      byAssetClass: {
        AssetClass.cash: DecimalValue.zero,
        AssetClass.equity: DecimalValue.parse('3000'),
      },
      totalValue: '3000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.length, 1);
    expect(rows.single.label, '权益');
  });

  test('总资产为 0 时占比为 0 而非除零', () {
    final summary = fakeSummary(
      byAssetClass: {AssetClass.equity: DecimalValue.parse('3000')},
      totalValue: '0',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows.single.share.canonical, '0');
  });

  test('资产类别维度按类别段色着色,聚合行不着色', () {
    final summary = fakeSummary(
      byAssetClass: {
        AssetClass.cash: DecimalValue.parse('1000'),
        AssetClass.equity: DecimalValue.parse('3000'),
      },
      totalValue: '4000',
    );
    final rows = buildChartRows(summary, AnalysisDimension.assetClass);
    expect(rows[0].color, FundLensTokens.categoryColors[AssetClass.equity]);
    expect(rows[1].color, FundLensTokens.categoryColors[AssetClass.cash]);
  });

  test('产品类型与来源平台维度不着色(回退段序暖墨档位)', () {
    final summary = fakeSummary(
      byInstrumentType: {InstrumentType.etf: DecimalValue.parse('3000')},
      bySource: {SourcePlatform.alipay: DecimalValue.parse('3000')},
      totalValue: '3000',
    );
    expect(
      buildChartRows(summary, AnalysisDimension.instrumentType).single.color,
      isNull,
    );
    expect(
      buildChartRows(summary, AnalysisDimension.source).single.color,
      isNull,
    );
  });

  testWidgets('环形图图例行显示名称、金额与占比', (tester) async {
    await tester.pumpWidget(
      chartHarness(CompositionDonutChart(rows: testRows)),
    );
    expect(find.text('权益'), findsOneWidget);
    expect(find.text('¥30,000.00'), findsOneWidget);
    expect(find.text('38.0%'), findsOneWidget);
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('¥12,000.00'), findsOneWidget);
  });

  testWidgets('环心默认显示总资产合计', (tester) async {
    await tester.pumpWidget(
      chartHarness(CompositionDonutChart(rows: testRows)),
    );
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('¥50,000.00'), findsOneWidget); // 30000+12000+8000
  });

  testWidgets('类别段色用于图例色点', (tester) async {
    await tester.pumpWidget(
      chartHarness(
        CompositionDonutChart(
          rows: [
            ChartBarRow(
              label: '权益',
              amount: DecimalValue.parse('30000'),
              share: DecimalValue.parse('0.6'),
              color: FundLensTokens.categoryColors[AssetClass.equity],
            ),
            ChartBarRow(
              label: '存款',
              amount: DecimalValue.parse('20000'),
              share: DecimalValue.parse('0.4'),
              color: FundLensTokens.categoryColors[AssetClass.deposit],
            ),
          ],
        ),
      ),
    );
    final colored = find.descendant(
      of: find.byType(CompositionDonutChart),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color ==
                FundLensTokens.categoryColors[AssetClass.deposit],
      ),
    );
    expect(colored, findsOneWidget);
  });

  testWidgets('聚合行图例色点使用暖灰色', (tester) async {
    await tester.pumpWidget(
      chartHarness(CompositionDonutChart(rows: testRows)),
    );
    final aggregateDot = find.descendant(
      of: find.byType(CompositionDonutChart),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == FundLensTokens.muted,
      ),
    );
    expect(aggregateDot, findsOneWidget);
  });

  testWidgets('图例行提供 Tooltip 语义(金额与占比)', (tester) async {
    await tester.pumpWidget(
      chartHarness(CompositionDonutChart(rows: testRows)),
    );
    final tooltip = tester.widget<Tooltip>(
      find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').contains('权益'),
      ),
    );
    expect(tooltip.message, contains('金额'));
    expect(tooltip.message, contains('38.0%'));
  });

  testWidgets('空状态显示原因', (tester) async {
    await tester.pumpWidget(
      chartHarness(const CompositionDonutChart(rows: [])),
    );
    expect(find.textContaining('暂无有效资产数据'), findsOneWidget);
  });

  testWidgets('悬停图例行时环心切换为该分项', (tester) async {
    await tester.pumpWidget(
      chartHarness(CompositionDonutChart(rows: testRows)),
    );
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('权益')));
    await tester.pump();
    // 图例行 + 环心各出现一次该分项占比。
    expect(find.text('38.0%'), findsNWidgets(2));
    expect(find.text('权益'), findsNWidgets(2));
  });

  testWidgets('窄屏(400px)下图表不溢出', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      chartHarness(CompositionDonutChart(rows: testRows)),
    );
    expect(tester.takeException(), isNull);
  });
}
