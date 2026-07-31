import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/overview/trend_chart.dart';

PortfolioSnapshot _snapshot(
  String id,
  DateTime at, {
  required List<(String, String?)> holdings,
}) {
  return PortfolioSnapshot(
    id: id,
    label: id,
    createdAt: at,
    holdings: [
      for (var i = 0; i < holdings.length; i++)
        SnapshotHolding(
          holdingId: '$id-$i',
          productName: '产品$i',
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: AssetClass.equity,
          sourcePlatform: SourcePlatform.manual,
          currentValue: DecimalValue.parse(holdings[i].$1),
          costAmount: holdings[i].$2 == null
              ? null
              : DecimalValue.parse(holdings[i].$2!),
          fieldProvenance: const {},
        ),
    ],
  );
}

void main() {
  group('trendPointFromSnapshot', () {
    test('总资产为快照持仓金额之和,覆盖成本为有成本持仓成本之和', () {
      final point = trendPointFromSnapshot(
        _snapshot('s1', DateTime(2026, 7, 1), holdings: [
          ('10000.00', '9000.00'),
          ('5000.00', null),
        ]),
      );
      expect(point.at, DateTime(2026, 7, 1));
      expect(point.totalValue, DecimalValue.parse('15000.00'));
      expect(point.coveredCost, DecimalValue.parse('9000.00'));
    });

    test('缺失成本但持有盈亏存在时按金额-盈亏反推成本', () {
      final snapshot = PortfolioSnapshot(
        id: 's2',
        label: 's2',
        createdAt: DateTime(2026, 7, 1),
        holdings: [
          SnapshotHolding(
            holdingId: 'a',
            productName: '支付宝基金',
            instrumentType: InstrumentType.offExchangeFund,
            assetClass: AssetClass.equity,
            sourcePlatform: SourcePlatform.alipay,
            currentValue: DecimalValue.parse('11000.00'),
            holdingProfit: DecimalValue.parse('1000.00'),
            fieldProvenance: const {},
          ),
        ],
      );
      expect(
        trendPointFromSnapshot(snapshot).coveredCost,
        DecimalValue.parse('10000.00'),
      );
    });
  });

  group('filterTrendPoints', () {
    final points = [
      TrendPoint(
        at: DateTime(2025, 7, 15),
        totalValue: DecimalValue.parse('100'),
        coveredCost: DecimalValue.parse('90'),
      ),
      TrendPoint(
        at: DateTime(2026, 5, 15),
        totalValue: DecimalValue.parse('110'),
        coveredCost: DecimalValue.parse('95'),
      ),
      TrendPoint(
        at: DateTime(2026, 7, 20),
        totalValue: DecimalValue.parse('120'),
        coveredCost: DecimalValue.parse('100'),
      ),
      TrendPoint(
        at: DateTime(2026, 7, 31),
        totalValue: DecimalValue.parse('125'),
        coveredCost: DecimalValue.parse('100'),
      ),
    ];
    final now = DateTime(2026, 7, 31, 12);

    test('全部范围保留所有点', () {
      expect(
        filterTrendPoints(points, TrendRange.all, now).length,
        points.length,
      );
    });

    test('近1月只保留30天内的点', () {
      final filtered = filterTrendPoints(points, TrendRange.month1, now);
      expect(filtered.length, 2);
      expect(filtered.first.at, DateTime(2026, 7, 20));
    });

    test('近3月只保留91天内的点', () {
      final filtered = filterTrendPoints(points, TrendRange.month3, now);
      expect(filtered.length, 3);
      expect(filtered.first.at, DateTime(2026, 5, 15));
    });

    test('近1年保留365天内的点', () {
      final filtered = filterTrendPoints(points, TrendRange.year1, now);
      expect(filtered.length, 3);
    });

    test('不过滤产生虚假历史:范围外没有点时不补点', () {
      final filtered = filterTrendPoints(points, TrendRange.month1, now);
      expect(filtered.every((p) => !p.at.isBefore(DateTime(2026, 7, 1))), isTrue);
    });
  });
}
