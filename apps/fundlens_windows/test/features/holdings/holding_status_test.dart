import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_status.dart';

final _now = DateTime.utc(2026, 7, 20);

/// 构造一条"正常"的行情类持仓;用命名参数覆盖需要变化的字段。
/// noQuantity/noPrice/noDate 用于显式制造 null(默认参数有兜底值)。
Holding fixtureHolding({
  String id = 'h-1',
  String productName = '测试基金',
  String? productCode = '110011',
  String currency = 'CNY',
  DecimalValue? quantity,
  DecimalValue? currentPrice,
  DecimalValue? costAmount,
  DecimalValue? holdingProfit,
  DecimalValue? holdingReturn,
  DecimalValue? currentValue,
  ValuationMethod valuationMethod = ValuationMethod.automaticQuote,
  DateTime? valuationDate,
  bool noQuantity = false,
  bool noPrice = false,
  bool noDate = false,
}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: productName,
    productCode: productCode,
    currency: currency,
    quantity: noQuantity ? null : (quantity ?? DecimalValue.parse('1000')),
    currentPrice: noPrice ? null : (currentPrice ?? DecimalValue.parse('1.5')),
    costAmount: costAmount,
    holdingProfit: holdingProfit,
    holdingReturn: holdingReturn,
    currentValue: currentValue ?? DecimalValue.parse('1500'),
    valuationMethod: valuationMethod,
    valuationDate: noDate ? null : (valuationDate ?? DateTime.utc(2026, 7, 19)),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  group('deriveHoldingDataStatus', () {
    test('正常持仓返回 normal', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(costAmount: DecimalValue.parse('1000')),
        freshQuoteHoldingIds: {'h-1'},
      );
      expect(status, HoldingDataStatus.normal);
    });

    test('名称为空返回未填写', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(productName: '  '),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.incomplete);
    });

    test('自动行情缺产品代码返回未填写', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(productCode: null),
        freshQuoteHoldingIds: const {'h-1'},
      );
      expect(status, HoldingDataStatus.incomplete);
    });

    test('行情类缺现价返回暂无行情(不被未填写吞掉)', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(noPrice: true),
        freshQuoteHoldingIds: const {'h-1'},
      );
      expect(status, HoldingDataStatus.noQuote);
    });

    test('自动行情不在新鲜集合返回等待更新', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(costAmount: DecimalValue.parse('1000')),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.staleQuote);
    });

    test('无有效成本返回缺少成本', () {
      // 手动金额类(不参与行情判断),无成本也无盈亏。
      final status = deriveHoldingDataStatus(
        fixtureHolding(valuationMethod: ValuationMethod.manualAmount),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.missingCost);
    });

    test('优先级:缺代码与缺成本并存时返回未填写', () {
      final status = deriveHoldingDataStatus(
        fixtureHolding(productCode: null),
        freshQuoteHoldingIds: const {},
      );
      expect(status, HoldingDataStatus.incomplete);
    });
  });

  group('单元格缺失文案', () {
    test('份额:手动金额类不适用,行情类缺失暂无行情,有值显示千分位', () {
      expect(
        holdingQuantityText(
          fixtureHolding(valuationMethod: ValuationMethod.manualAmount),
        ),
        '不适用',
      );
      expect(
        holdingQuantityText(
          fixtureHolding(
            valuationMethod: ValuationMethod.quantityTimesPrice,
            noQuantity: true,
          ),
        ),
        '暂无行情',
      );
      expect(
        holdingQuantityText(
          fixtureHolding(valuationMethod: ValuationMethod.quantityTimesPrice),
        ),
        '1,000',
      );
    });

    test('覆盖成本:null 显示缺少成本,否则千分位金额', () {
      expect(holdingCostText(fixtureHolding()), '缺少成本');
      expect(
        holdingCostText(fixtureHolding(costAmount: DecimalValue.parse('12345.6'))),
        '12,345.60',
      );
    });

    test('持仓盈亏:无成本显示缺少成本,有盈亏带符号', () {
      expect(holdingProfitText(fixtureHolding()), '缺少成本');
      expect(
        holdingProfitText(
          fixtureHolding(
            costAmount: DecimalValue.parse('1000'),
            holdingProfit: DecimalValue.parse('-25.5'),
          ),
        ),
        '-25.50',
      );
    });

    test('持仓收益率:无成本显示缺少成本,有收益率带符号百分号', () {
      expect(holdingReturnText(fixtureHolding()), '缺少成本');
      expect(
        holdingReturnText(
          fixtureHolding(
            costAmount: DecimalValue.parse('1000'),
            holdingReturn: DecimalValue.parse('0.125'),
          ),
        ),
        '+12.50%',
      );
      // holdingReturn 为空但有成本与盈亏 → 由 盈亏÷成本 推导。
      expect(
        holdingReturnText(
          fixtureHolding(
            costAmount: DecimalValue.parse('1000'),
            holdingProfit: DecimalValue.parse('100'),
          ),
        ),
        '+10.00%',
      );
    });

    test('估值日期:行情类缺失暂无行情,手动金额类不适用', () {
      expect(
        holdingValuationDateText(fixtureHolding(noDate: true)),
        '暂无行情',
      );
      expect(
        holdingValuationDateText(
          fixtureHolding(
            valuationMethod: ValuationMethod.manualAmount,
            noDate: true,
          ),
        ),
        '不适用',
      );
      expect(
        holdingValuationDateText(fixtureHolding()),
        '2026-07-19',
      );
    });

    test('资产占比:null 不适用,否则百分比', () {
      expect(holdingShareText(null), '不适用');
      expect(holdingShareText(DecimalValue.parse('0.1234')), '12.34%');
    });
  });

  group('HoldingValueFormatter.percent', () {
    test('小数转百分比保留两位', () {
      expect(
        HoldingValueFormatter.percent(DecimalValue.parse('0.5')),
        '50.00%',
      );
      expect(HoldingValueFormatter.percent(null), '—');
    });
  });

  group('holdingPnlDirection 盈亏方向四态', () {
    test('正/负/零/null 分别返回 positive/negative/zero/null', () {
      expect(
        holdingPnlDirection(DecimalValue.parse('12.5')),
        PnlDirection.positive,
      );
      expect(
        holdingPnlDirection(DecimalValue.parse('-3.2')),
        PnlDirection.negative,
      );
      expect(holdingPnlDirection(DecimalValue.parse('0')), PnlDirection.zero);
      // 缺失(缺少成本、无有效收益率)为 null,不应用任何红绿。
      expect(holdingPnlDirection(null), isNull);
    });
  });
}
