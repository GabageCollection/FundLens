import 'package:fundlens_core/fundlens_core.dart';
import 'package:test/test.dart';

void main() {
  test('decimal values serialize without binary floating point', () {
    expect(DecimalValue.parse('78347.8700').canonical, '78347.87');
    expect(DecimalValue.parse('-0.00').canonical, '0');
  });

  test('decimal divide supports fixed scale', () {
    expect(
      DecimalValue.parse(
        '1',
      ).divide(DecimalValue.parse('3'), scale: 4).canonical,
      '0.3333',
    );
    expect(
      DecimalValue.parse(
        '10',
      ).divide(DecimalValue.parse('4'), scale: 2).canonical,
      '2.5',
    );
  });

  test('holding keeps cumulative profit separate from holding profit', () {
    final holding = Holding(
      id: 'h1',
      sourcePlatform: SourcePlatform.alipay,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.fixedIncome,
      productName: '脱敏纯债基金A',
      currency: 'CNY',
      currentValue: DecimalValue.parse('78347.87'),
      holdingProfit: DecimalValue.parse('428.96'),
      cumulativeProfit: DecimalValue.parse('888.88'),
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: DataOrigin.ocr,
      fieldProvenance: const {},
      createdAt: DateTime.utc(2026, 7, 19),
      updatedAt: DateTime.utc(2026, 7, 19),
    );
    expect(holding.currentFloatingProfit?.canonical, '428.96');
  });

  test(
    'effective cost amount is inferred from holding profit when cost amount is absent',
    () {
      final holding = Holding(
        id: 'h2',
        sourcePlatform: SourcePlatform.alipay,
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.fixedIncome,
        productName: '脱敏纯债基金B',
        currency: 'CNY',
        currentValue: DecimalValue.parse('1000'),
        holdingProfit: DecimalValue.parse('200'),
        valuationMethod: ValuationMethod.manualAmount,
        dataOrigin: DataOrigin.manual,
        fieldProvenance: const {},
        createdAt: DateTime.utc(2026, 7, 19),
        updatedAt: DateTime.utc(2026, 7, 19),
      );
      expect(holding.effectiveCostAmount?.canonical, '800');
      expect(holding.currentFloatingProfit?.canonical, '200');
    },
  );
}
