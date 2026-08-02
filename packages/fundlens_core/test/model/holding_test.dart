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

  test('holding copyWith updates only the given fields', () {
    final now = DateTime.utc(2026, 7, 1);
    final later = DateTime.utc(2026, 8, 2, 9, 30);
    final original = Holding(
      id: 'h-1',
      sourcePlatform: SourcePlatform.alipay,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.equity,
      productName: '测试基金',
      currency: 'CNY',
      currentValue: DecimalValue.parse('1500'),
      costAmount: DecimalValue.parse('1200'),
      valuationMethod: ValuationMethod.automaticQuote,
      dataOrigin: DataOrigin.excel,
      fieldProvenance: const {
        'currentValue': FieldProvenance(
          kind: ProvenanceKind.original,
          source: '导入',
        ),
      },
      createdAt: now,
      updatedAt: now,
    );
    final updated = original.copyWith(
      assetClass: AssetClass.gold,
      fieldProvenance: {
        ...original.fieldProvenance,
        'assetClass': const FieldProvenance(
          kind: ProvenanceKind.userCorrected,
          source: '批量修改',
        ),
      },
      updatedAt: later,
    );
    expect(updated.assetClass, AssetClass.gold);
    expect(updated.updatedAt, later);
    expect(
      updated.fieldProvenance['assetClass']!.kind,
      ProvenanceKind.userCorrected,
    );
    // 未传字段保持不变。
    expect(updated.sourcePlatform, SourcePlatform.alipay);
    expect(updated.currentValue.canonical, '1500');
    expect(updated.fieldProvenance['currentValue']!.kind, ProvenanceKind.original);
  });
}
