import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/data_health/data_health_metrics.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';

final _now = DateTime.utc(2026, 7, 20);

/// 构造一条持仓;命名参数覆盖需要变化的字段。
Holding fixtureHolding({
  String id = 'h-1',
  String productName = '测试基金',
  String? productCode = '110011',
  String currency = 'CNY',
  DecimalValue? quantity,
  DecimalValue? currentPrice,
  DecimalValue? costAmount,
  DecimalValue? holdingProfit,
  DecimalValue? currentValue,
  AssetClass assetClass = AssetClass.equity,
  ValuationMethod valuationMethod = ValuationMethod.automaticQuote,
  DateTime? valuationDate,
  bool noQuantity = false,
  bool noPrice = false,
  bool noDate = false,
  DateTime? updatedAt,
}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: productName,
    productCode: productCode,
    currency: currency,
    quantity: noQuantity ? null : (quantity ?? DecimalValue.parse('1000')),
    currentPrice: noPrice ? null : (currentPrice ?? DecimalValue.parse('1.5')),
    costAmount: costAmount,
    holdingProfit: holdingProfit,
    holdingReturn: null,
    currentValue: currentValue ?? DecimalValue.parse('1500'),
    valuationMethod: valuationMethod,
    valuationDate: noDate ? null : (valuationDate ?? DateTime.utc(2026, 7, 19)),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: updatedAt ?? _now,
  );
}

/// 方便构造一行指标的辅助。
DataHealthMetrics calc(
  List<Holding> holdings, {
  Set<String> freshIds = const {},
  DecimalValue? returnCoverage,
  LastImportRecord? lastImport,
  DateTime? lastQuoteRefresh,
  DateTime? now,
}) {
  return calculateDataHealthMetrics(
    holdings: holdings,
    freshQuoteHoldingIds: freshIds,
    returnCoverage: returnCoverage ?? DecimalValue.zero,
    lastImport: lastImport,
    lastQuoteRefresh: lastQuoteRefresh,
    now: now ?? _now,
  );
}

void main() {
  group('持仓识别率', () {
    test('手动金额类资产无需代码,从分母排除', () {
      final m = calc([
        fixtureHolding(),
        fixtureHolding(
          id: 'h-2',
          productCode: null,
          valuationMethod: ValuationMethod.manualAmount,
        ),
      ]);
      expect(m.recognitionRate.count, 1);
      expect(m.recognitionRate.total, 1);
      expect(m.recognitionRate.ratio, 1.0);
    });

    test('行情类缺代码时计入分子缺失', () {
      final m = calc([
        fixtureHolding(),
        fixtureHolding(id: 'h-2', productCode: null),
      ]);
      expect(m.recognitionRate.count, 1);
      expect(m.recognitionRate.total, 2);
      expect(m.recognitionRate.ratio, 0.5);
    });

    test('空白代码视为未识别', () {
      final m = calc([
        fixtureHolding(id: 'h-2', productCode: '  '),
      ]);
      expect(m.recognitionRate.count, 0);
      expect(m.recognitionRate.total, 1);
    });
  });

  group('资产分类率', () {
    test('未分类(AssetClass.other)不计入分子', () {
      final m = calc([
        fixtureHolding(),
        fixtureHolding(
          id: 'h-2',
          assetClass: AssetClass.other,
        ),
      ]);
      expect(m.classificationRate.count, 1);
      expect(m.classificationRate.total, 2);
      expect(m.classificationRate.ratio, 0.5);
    });

    test('空仓分类率总数为 0,比率为 null(不适用)', () {
      final m = calc([]);
      expect(m.classificationRate.total, 0);
      expect(m.classificationRate.ratio, isNull);
    });
  });

  group('成本覆盖率', () {
    test('有有效成本的持仓计入分子', () {
      final m = calc([
        fixtureHolding(costAmount: DecimalValue.parse('1000')),
        fixtureHolding(id: 'h-2'),
      ]);
      expect(m.costCoverageRate.count, 1);
      expect(m.costCoverageRate.total, 2);
      expect(m.costCoverageRate.ratio, 0.5);
    });

    test('支付宝反推:无成本但有盈亏时按 金额-盈亏 计入', () {
      final m = calc([
        fixtureHolding(
          costAmount: null,
          holdingProfit: DecimalValue.parse('100'),
          currentValue: DecimalValue.parse('1500'),
        ),
      ]);
      expect(m.costCoverageRate.count, 1);
      expect(m.costCoverageRate.total, 1);
    });

    test('零成本不视为有成本', () {
      final m = calc([
        fixtureHolding(costAmount: DecimalValue.zero),
      ]);
      expect(m.costCoverageRate.count, 0);
      expect(m.costCoverageRate.total, 1);
    });
  });

  group('行情覆盖率', () {
    test('手动金额类不进行情覆盖率分母', () {
      final m = calc([
        // 自动行情:freshIds 含 → 有效
        fixtureHolding(),
        // 手动金额:排除
        fixtureHolding(
          id: 'h-2',
          valuationMethod: ValuationMethod.manualAmount,
        ),
      ], freshIds: {'h-1'});
      expect(m.quoteCoverageRate.count, 1);
      expect(m.quoteCoverageRate.total, 1);
      expect(m.quoteCoverageRate.ratio, 1.0);
    });

    test('不在 freshIds 的自动行情视为过期,不计入分子', () {
      final m = calc([
        fixtureHolding(),
        fixtureHolding(id: 'h-2'),
      ], freshIds: {'h-1'});
      expect(m.quoteCoverageRate.count, 1);
      expect(m.quoteCoverageRate.total, 2);
    });

    test('缺现价的自动行情不计入分子', () {
      final m = calc([
        fixtureHolding(noPrice: true),
      ], freshIds: {'h-1'});
      expect(m.quoteCoverageRate.count, 0);
      expect(m.quoteCoverageRate.total, 1);
    });

    test('估值日期超过最大年龄即使 freshIds 含也视为过期', () {
      final oldDate = _now.subtract(const Duration(days: 60));
      final m = calc([
        fixtureHolding(valuationDate: oldDate),
      ], freshIds: {'h-1'});
      expect(m.quoteCoverageRate.count, 0);
      expect(m.quoteCoverageRate.total, 1);
    });
  });

  group('过期行情数量', () {
    test('统计过期与无行的自动行情持仓', () {
      final oldDate = _now.subtract(const Duration(days: 60));
      final m = calc([
        fixtureHolding(), // freshIds 含 → 新鲜
        fixtureHolding(id: 'h-2'), // 不在 freshIds → 过期
        fixtureHolding(id: 'h-3', valuationDate: oldDate), // 超龄 → 过期
        fixtureHolding(
          id: 'h-4',
          valuationMethod: ValuationMethod.manualAmount,
        ), // 手动 → 不计
      ], freshIds: {'h-1'});
      expect(m.staleQuoteCount, 2);
    });
  });

  group('收益覆盖率', () {
    test('直接透传传入的 returnCoverage', () {
      final m = calc(
        [],
        returnCoverage: DecimalValue.parse('0.75'),
      );
      expect(m.returnCoverageRate, DecimalValue.parse('0.75'));
    });
  });

  group('待处理异常数量', () {
    test('数据状态非正常的持仓计数', () {
      final m = calc([
        fixtureHolding(costAmount: DecimalValue.parse('1000')), // normal(fresh)
        fixtureHolding(id: 'h-2'), // 无成本 → missingCost
      ], freshIds: {'h-1'});
      expect(m.pendingIssueCount, 1);
    });

    test('全部正常时为 0', () {
      final m = calc([
        fixtureHolding(costAmount: DecimalValue.parse('1000')),
      ], freshIds: {'h-1'});
      expect(m.pendingIssueCount, 0);
    });
  });

  group('数据截至时间', () {
    test('取全部持仓估值日期的最大值', () {
      final m = calc([
        fixtureHolding(id: 'h-1', valuationDate: DateTime.utc(2026, 7, 18)),
        fixtureHolding(id: 'h-2', valuationDate: DateTime.utc(2026, 7, 19)),
      ]);
      expect(m.asOfDate, DateTime.utc(2026, 7, 19));
    });

    test('全无估值日期时取更新时间最大值', () {
      final m = calc([
        fixtureHolding(id: 'h-1', noDate: true, updatedAt: DateTime.utc(2026, 7, 17)),
        fixtureHolding(id: 'h-2', noDate: true, updatedAt: DateTime.utc(2026, 7, 19)),
      ]);
      expect(m.asOfDate, DateTime.utc(2026, 7, 19));
    });

    test('空仓时为 null', () {
      final m = calc([]);
      expect(m.asOfDate, isNull);
    });
  });

  group('最近导入与最近行情刷新', () {
    test('透传最近导入与最近刷新时间', () {
      final import = LastImportRecord(
        committedAt: DateTime.utc(2026, 7, 18),
        inserted: 3,
        updated: 1,
        removed: 0,
        skipped: 2,
      );
      final m = calc(
        [],
        lastImport: import,
        lastQuoteRefresh: DateTime.utc(2026, 7, 19, 8, 30),
      );
      expect(m.lastImport, same(import));
      expect(m.lastQuoteRefresh, DateTime.utc(2026, 7, 19, 8, 30));
    });

    test('缺省时为 null', () {
      final m = calc([]);
      expect(m.lastImport, isNull);
      expect(m.lastQuoteRefresh, isNull);
    });
  });
}
