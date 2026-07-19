import 'package:fundlens_core/fundlens_core.dart';
import 'package:test/test.dart';

Holding h(
  String id,
  String value, {
  String? cost,
  String? holdingProfit,
  String? cumulativeProfit,
  AssetClass asset = AssetClass.equity,
  InstrumentType instrument = InstrumentType.stock,
  ValuationMethod method = ValuationMethod.manualAmount,
  String? productCode,
  String? quantity,
  String? currentPrice,
  DateTime? valuationDate,
  SourcePlatform source = SourcePlatform.manual,
}) => Holding(
  id: id,
  sourcePlatform: source,
  instrumentType: instrument,
  assetClass: asset,
  productName: id,
  currency: 'CNY',
  currentValue: DecimalValue.parse(value),
  costAmount: cost == null ? null : DecimalValue.parse(cost),
  holdingProfit: holdingProfit == null
      ? null
      : DecimalValue.parse(holdingProfit),
  cumulativeProfit: cumulativeProfit == null
      ? null
      : DecimalValue.parse(cumulativeProfit),
  valuationMethod: method,
  dataOrigin: DataOrigin.manual,
  fieldProvenance: const {},
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  productCode: productCode,
  quantity: quantity == null ? null : DecimalValue.parse(quantity),
  currentPrice: currentPrice == null ? null : DecimalValue.parse(currentPrice),
  valuationDate: valuationDate,
);

void main() {
  test('summary excludes missing cost from return denominator', () {
    final result = PortfolioCalculator().calculate([
      h('stock', '120', cost: '100'),
      h('deposit', '80', asset: AssetClass.deposit),
    ]);
    expect(result.totalValue.canonical, '200');
    expect(result.totalCost.canonical, '100');
    expect(result.totalFloatingProfit.canonical, '20');
    expect(result.totalReturn?.canonical, '0.2');
    expect(result.returnCoverage.canonical, '0.6');
    expect(result.byAssetClass[AssetClass.equity]?.canonical, '120');
    expect(result.cashAndDepositShare.canonical, '0.4');
    expect(result.largestHoldingShare.canonical, '0.6');
  });

  test('empty portfolio returns zero summary without error', () {
    final result = PortfolioCalculator().calculate([]);
    expect(result.totalValue.canonical, '0');
    expect(result.totalCost.canonical, '0');
    expect(result.totalFloatingProfit.canonical, '0');
    expect(result.totalReturn, isNull);
    expect(result.returnCoverage.canonical, '0');
    expect(result.byAssetClass, isEmpty);
    expect(result.cashAndDepositShare.canonical, '0');
    expect(result.largestHoldingShare.canonical, '0');
    expect(result.largestAssetClassShare.canonical, '0');
    expect(result.equityExposureShare.canonical, '0');
  });

  test('zero cost keeps return empty and excludes from floating profit', () {
    final result = PortfolioCalculator().calculate([
      h('zero-cost', '100', cost: '0'),
    ]);
    expect(result.totalValue.canonical, '100');
    expect(result.totalCost.canonical, '0');
    expect(result.totalFloatingProfit.canonical, '0');
    expect(result.totalReturn, isNull);
    expect(result.returnCoverage.canonical, '0');
  });

  test('negative profit produces negative return', () {
    final result = PortfolioCalculator().calculate([
      h('loser', '90', cost: '100'),
    ]);
    expect(result.totalValue.canonical, '90');
    expect(result.totalCost.canonical, '100');
    expect(result.totalFloatingProfit.canonical, '-10');
    expect(result.totalReturn?.canonical, '-0.1');
  });

  test('gold ETF is classified on both instrument and asset axes', () {
    final result = PortfolioCalculator().calculate([
      h(
        'gold-etf',
        '300',
        asset: AssetClass.gold,
        instrument: InstrumentType.etf,
      ),
    ]);
    expect(result.byAssetClass[AssetClass.gold]?.canonical, '300');
    expect(result.byInstrumentType[InstrumentType.etf]?.canonical, '300');
    expect(result.byAssetClass[AssetClass.equity], isNull);
  });

  test('cumulative profit is excluded from floating profit', () {
    final result = PortfolioCalculator().calculate([
      h('accumulated', '120', cost: '100', cumulativeProfit: '50'),
    ]);
    expect(result.totalFloatingProfit.canonical, '20');
  });

  test(
    'Alipay-style holding with holdingProfit only enters return denominator',
    () {
      final result = PortfolioCalculator().calculate([
        h('alipay-style', '130', holdingProfit: '30'),
      ]);
      expect(result.totalCost.canonical, '100');
      expect(result.totalFloatingProfit.canonical, '30');
      expect(result.totalReturn?.canonical, '0.3');
    },
  );

  test('data quality applies valuation-method field requirements', () {
    final quality = DataQualityCalculator().calculate([
      h('stock', '120', cost: '100'),
    ], freshQuoteHoldingIds: const {});
    expect(
      quality.dataCompleteness.compareTo(DecimalValue.zero),
      greaterThan(0),
    );
    expect(quality.quoteFreshness, isNull);
  });

  test('automatic-quote data completeness penalises missing fields', () {
    final complete = DataQualityCalculator().calculate([
      h(
        'complete',
        '100',
        method: ValuationMethod.automaticQuote,
        productCode: '510000',
        quantity: '10',
        currentPrice: '10',
        valuationDate: DateTime.utc(2026, 1, 1),
      ),
    ], freshQuoteHoldingIds: const {});
    final incomplete = DataQualityCalculator().calculate([
      h('incomplete', '100', method: ValuationMethod.automaticQuote),
    ], freshQuoteHoldingIds: const {});
    expect(complete.dataCompleteness.canonical, '1');
    expect(
      incomplete.dataCompleteness.compareTo(DecimalValue.parse('1')),
      lessThan(0),
    );
    expect(
      incomplete.dataCompleteness.compareTo(DecimalValue.zero),
      greaterThan(0),
    );
  });

  test('quote freshness is value-weighted', () {
    final quality = DataQualityCalculator().calculate(
      [
        h('fresh', '100', method: ValuationMethod.automaticQuote),
        h('stale', '50', method: ValuationMethod.automaticQuote),
      ],
      freshQuoteHoldingIds: const {'fresh'},
    );
    expect(quality.quoteFreshness, isNotNull);
    expect(quality.quoteFreshness!.canonical, '0.66666666');
  });
}
