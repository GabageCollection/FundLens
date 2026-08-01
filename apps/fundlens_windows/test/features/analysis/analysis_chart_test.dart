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
    label: '其他',
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
    expect(rows.last.label, '其他');
    expect(rows.last.isAggregate, isTrue);
    expect(rows.last.amount.canonical, '3000'); // 降序前 5 之后的最小 2 项:2000+1000
    expect(rows.last.share.canonical, '0.10714285'); // 3000 ÷ 28000,DecimalValue 除法按 8 位截断
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

  testWidgets('条形图同时显示名称、金额与占比', (tester) async {
    await tester.pumpWidget(chartHarness(HorizontalBarChart(rows: testRows)));
    expect(find.text('权益'), findsOneWidget);
    expect(find.text('¥30,000.00'), findsOneWidget);
    expect(find.text('38.0%'), findsOneWidget);
    expect(find.text('现金'), findsOneWidget);
    expect(find.text('¥12,000.00'), findsOneWidget);
  });

  testWidgets('条形图聚合行使用暖灰色而非主色', (tester) async {
    await tester.pumpWidget(chartHarness(HorizontalBarChart(rows: testRows)));
    final aggregateBar = tester.widget<Container>(
      find.descendant(
        of: find.byType(HorizontalBarChart),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).color == FundLensTokens.muted,
        ),
      ),
    );
    expect(aggregateBar, isNotNull);
  });

  testWidgets('条形图每行提供 Tooltip 语义(金额与占比)', (tester) async {
    await tester.pumpWidget(chartHarness(HorizontalBarChart(rows: testRows)));
    final tooltip = tester.widget<Tooltip>(
      find.byWidgetPredicate(
        (w) => w is Tooltip && (w.message ?? '').contains('权益'),
      ),
    );
    expect(tooltip.message, contains('金额'));
    expect(tooltip.message, contains('38.0%'));
  });

  testWidgets('条形图空状态显示原因', (tester) async {
    await tester.pumpWidget(chartHarness(const HorizontalBarChart(rows: [])));
    expect(find.textContaining('暂无有效资产数据'), findsOneWidget);
  });

  testWidgets('来源平台比例条显示图例(名称/金额/占比)', (tester) async {
    await tester.pumpWidget(
      chartHarness(
        PlatformProportionBar(
          rows: [
            ChartBarRow(
              label: '支付宝',
              amount: DecimalValue.parse('5000'),
              share: DecimalValue.parse('0.5'),
            ),
            ChartBarRow(
              label: '同花顺',
              amount: DecimalValue.parse('3000'),
              share: DecimalValue.parse('0.3'),
            ),
            ChartBarRow(
              label: '手工录入',
              amount: DecimalValue.parse('2000'),
              share: DecimalValue.parse('0.2'),
            ),
          ],
        ),
      ),
    );
    expect(find.text('支付宝'), findsOneWidget);
    expect(find.text('¥5,000.00'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('同花顺'), findsOneWidget);
  });

  testWidgets('窄屏(400px)下图表不溢出', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      chartHarness(HorizontalBarChart(rows: testRows)),
    );
    expect(tester.takeException(), isNull);
  });
}
