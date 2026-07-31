import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/overview/insight_list.dart';

Holding _holding({
  required String id,
  required String productName,
  required String currentValue,
  AssetClass assetClass = AssetClass.equity,
  String? costAmount,
  ValuationMethod valuationMethod = ValuationMethod.manualAmount,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.manual,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: productName,
    currency: 'CNY',
    currentValue: DecimalValue.parse(currentValue),
    costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
    valuationMethod: valuationMethod,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('buildOverviewInsights', () {
    test('单项持仓占比达到 25% 时产生集中度提醒并带查看持仓操作', () {
      final holdings = [
        _holding(
          id: 'h1',
          productName: '东方添益债券',
          currentValue: '31800.00',
          costAmount: '30000.00',
        ),
        _holding(id: 'h2', productName: '产品B', currentValue: '23000.00'),
        _holding(id: 'h3', productName: '产品C', currentValue: '23000.00'),
        _holding(id: 'h4', productName: '产品D', currentValue: '22200.00'),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      final single = insights.where((i) => i.code == 'single_concentration');
      expect(single, hasLength(1));
      expect(single.single.title, contains('东方添益债券'));
      expect(single.single.title, contains('31.8%'));
      expect(single.single.detail, isNotEmpty);
      expect(single.single.actionLabel, '查看持仓');
      expect(single.single.action, OverviewInsightAction.holdings);
    });

    test('前 3 项持仓占比达到 60% 时产生前3集中度提醒', () {
      final holdings = [
        for (var i = 0; i < 4; i++)
          _holding(id: 'h$i', productName: '产品$i', currentValue: '2500.00'),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      final top3 = insights.where((i) => i.code == 'top3_concentration');
      expect(top3, hasLength(1));
      expect(top3.single.title, contains('75.0%'));
      expect(top3.single.action, OverviewInsightAction.holdings);
    });

    test('未分类资产数量提醒', () {
      final holdings = [
        _holding(id: 'h1', productName: '未识别产品', currentValue: '100.00',
            assetClass: AssetClass.other),
        _holding(id: 'h2', productName: '正常产品', currentValue: '900.00'),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      final uncategorized =
          insights.where((i) => i.code == 'uncategorized_assets');
      expect(uncategorized, hasLength(1));
      expect(uncategorized.single.title, contains('1'));
      expect(uncategorized.single.action, OverviewInsightAction.holdings);
    });

    test('缺少成本的持仓数量提醒', () {
      final holdings = [
        _holding(id: 'h1', productName: '无成本A', currentValue: '100.00'),
        _holding(id: 'h2', productName: '无成本B', currentValue: '100.00'),
        _holding(
          id: 'h3',
          productName: '有成本',
          currentValue: '800.00',
          costAmount: '700.00',
        ),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      final missing = insights.where((i) => i.code == 'missing_cost');
      expect(missing, hasLength(1));
      expect(missing.single.title, contains('2'));
    });

    test('行情过期数量提醒,操作为查看数据状态', () {
      final holdings = [
        _holding(
          id: 'h1',
          productName: '自动行情产品',
          currentValue: '1000.00',
          valuationMethod: ValuationMethod.automaticQuote,
        ),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      final stale = insights.where((i) => i.code == 'stale_quotes');
      expect(stale, hasLength(1));
      expect(stale.single.title, contains('1'));
      expect(stale.single.action, OverviewInsightAction.importReview);
    });

    test('收益未覆盖金额提醒', () {
      final holdings = [
        _holding(id: 'h1', productName: '现金', currentValue: '2500.00'),
        _holding(
          id: 'h2',
          productName: '基金',
          currentValue: '7500.00',
          costAmount: '7000.00',
        ),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      final uncovered = insights.where((i) => i.code == 'uncovered_return');
      expect(uncovered, hasLength(1));
      expect(uncovered.single.title, contains('2,500'));
    });

    test('全部正常时不产生任何提醒', () {
      final holdings = [
        for (var i = 0; i < 6; i++)
          _holding(
            id: 'h$i',
            productName: '产品$i',
            currentValue: '2000.00',
            costAmount: '1800.00',
          ),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      expect(insights, isEmpty);
    });

    test('提醒文案不包含投资行为措辞', () {
      final holdings = [
        _holding(
          id: 'h1',
          productName: '东方添益债券',
          currentValue: '9000.00',
          costAmount: '8000.00',
        ),
        _holding(id: 'h2', productName: '现金', currentValue: '1000.00'),
      ];
      final insights = buildOverviewInsights(
        holdings: holdings,
        summary: PortfolioCalculator().calculate(holdings),
        freshQuoteHoldingIds: const {},
      );
      for (final insight in insights) {
        for (final forbidden in ['建议', '应当', '调仓', '再平衡', '买入', '卖出']) {
          expect(insight.title, isNot(contains(forbidden)));
          expect(insight.detail, isNot(contains(forbidden)));
        }
      }
    });
  });
}
