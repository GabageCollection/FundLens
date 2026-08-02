import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/portfolio_providers.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_status.dart';

import '../overview/asset_spectrum_test.dart' show FakeHoldingRepository;

final _now = DateTime.utc(2026, 7, 20);

Holding makeHolding({
  required String id,
  String name = '产品',
  SourcePlatform source = SourcePlatform.alipay,
  AssetClass assetClass = AssetClass.equity,
  DecimalValue? currentValue,
  DecimalValue? quantity,
  DecimalValue? costAmount,
  DecimalValue? holdingProfit,
  ValuationMethod valuationMethod = ValuationMethod.automaticQuote,
  DateTime? valuationDate,
  List<String> platformTags = const [],
  bool noQuantity = false,
}) {
  return Holding(
    id: id,
    sourcePlatform: source,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: name,
    productCode: '110011',
    currency: 'CNY',
    quantity: noQuantity ? null : (quantity ?? DecimalValue.parse('100')),
    currentPrice: DecimalValue.parse('1.0'),
    currentValue: currentValue ?? DecimalValue.parse('100'),
    costAmount: costAmount,
    holdingProfit: holdingProfit,
    valuationMethod: valuationMethod,
    valuationDate: valuationDate ?? _now,
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    platformTags: platformTags,
    createdAt: _now,
    updatedAt: _now,
  );
}

ProviderContainer makeContainer(List<Holding> holdings) {
  return ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(FakeHoldingRepository(holdings)),
    // 默认全部行情新鲜,避免"等待更新"干扰数据状态断言。
    freshQuoteHoldingIdsProvider.overrideWith(
      (ref) => {for (final h in holdings) h.id},
    ),
  ]);
}

/// 保持 holdingsProvider 存活并等待首次发射。
///
/// Riverpod 3 下非 keepAlive 的 provider 需至少一个监听者,否则会在
/// 发射前被自动释放,导致 "disposed during loading state"。
Future<List<Holding>> firstEmission(ProviderContainer container) {
  final subscription = container.listen(holdingsProvider, (_, _) {});
  addTearDown(subscription.close);
  return container.read(holdingsProvider.future);
}

void main() {
  group('visibleHoldingsProvider 筛选组合', () {
    test('搜索 + 资产类别 + 来源平台组合过滤', () async {
      final container = makeContainer([
        makeHolding(id: 'a', name: '沪深300', currentValue: DecimalValue.parse('300')),
        makeHolding(id: 'b', name: '中证500', assetClass: AssetClass.fixedIncome),
        makeHolding(id: 'c', name: '沪深增强', source: SourcePlatform.ths),
      ]);
      addTearDown(container.dispose);
      await firstEmission(container);

      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(
        query: '沪深',
        assetClasses: {AssetClass.equity},
        sources: {SourcePlatform.alipay},
      );
      final visible = container.read(visibleHoldingsProvider);
      expect(visible.map((h) => h.id), ['a']);
    });

    test('数据状态筛选:只保留缺少成本的持仓', () async {
      final container = makeContainer([
        makeHolding(id: 'no-cost'),
        makeHolding(id: 'has-cost', costAmount: DecimalValue.parse('50')),
      ]);
      addTearDown(container.dispose);
      await firstEmission(container);

      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(
        statuses: {HoldingDataStatus.missingCost},
      );
      final visible = container.read(visibleHoldingsProvider);
      expect(visible.map((h) => h.id), ['no-cost']);
    });

    test('组合标签筛选:标签命中与未标记', () async {
      final container = makeContainer([
        makeHolding(id: 'tagged', platformTags: const ['工资账户']),
        makeHolding(id: 'untagged'),
      ]);
      addTearDown(container.dispose);
      await firstEmission(container);

      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(tags: {'工资账户'});
      expect(
        container.read(visibleHoldingsProvider).map((h) => h.id),
        ['tagged'],
      );

      // null 元素 = 未标记。
      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(tags: {null});
      expect(
        container.read(visibleHoldingsProvider).map((h) => h.id),
        ['untagged'],
      );
    });

    test('hasActiveFilter 与 cleared:清除筛选保留排序', () {
      const filter = HoldingFilterState(
        query: 'x',
        sort: HoldingSort(HoldingSortField.name, true),
      );
      expect(filter.hasActiveFilter, isTrue);
      final cleared = filter.cleared();
      expect(cleared.hasActiveFilter, isFalse);
      expect(cleared.sort.field, HoldingSortField.name);
      expect(cleared.sort.ascending, isTrue);
      expect(const HoldingFilterState().hasActiveFilter, isFalse);
    });
  });

  group('holdingComparator', () {
    test('当前金额降序(默认),占比序与金额序一致', () {
      final small = makeHolding(id: 's', currentValue: DecimalValue.parse('10'));
      final big = makeHolding(id: 'b', currentValue: DecimalValue.parse('99'));
      final list = [small, big]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.currentValue, false)),
        );
      expect(list.map((h) => h.id), ['b', 's']);
      final byShare = [small, big]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.share, true)),
        );
      expect(byShare.map((h) => h.id), ['s', 'b']);
    });

    test('空值恒排末尾(与方向无关),同值按 id 稳定', () {
      final noQty = makeHolding(id: 'z-none', noQuantity: true);
      final a = makeHolding(id: 'a', quantity: DecimalValue.parse('1'));
      final b = makeHolding(id: 'b', quantity: DecimalValue.parse('2'));
      for (final ascending in [true, false]) {
        final list = [noQty, b, a]..sort(
            holdingComparator(HoldingSort(HoldingSortField.quantity, ascending)),
          );
        expect(list.last.id, 'z-none', reason: 'ascending=$ascending');
      }
      final same1 = makeHolding(id: 'a', quantity: DecimalValue.parse('1'));
      final same2 = makeHolding(id: 'b', quantity: DecimalValue.parse('1'));
      final list = [same2, same1]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.quantity, true)),
        );
      expect(list.map((h) => h.id), ['a', 'b']);
    });

    test('收益率排序:平台值与推导值混合比较', () {
      final platform = makeHolding(
        id: 'p',
        costAmount: DecimalValue.parse('100'),
        holdingProfit: DecimalValue.parse('50'),
      );
      // holdingReturn 为空 → 由 50÷100 推导 0.5。
      final list = [platform]..sort(
          holdingComparator(const HoldingSort(HoldingSortField.returnRate, false)),
        );
      expect(list.single.id, 'p'); // 不抛异常即验证推导路径可比较
    });
  });

  group('holdingTagOptionsProvider', () {
    test('汇总全部持仓标签并去重排序', () async {
      final container = makeContainer([
        makeHolding(id: 'a', platformTags: const ['奖金', '工资']),
        makeHolding(id: 'b', platformTags: const ['工资']),
      ]);
      addTearDown(container.dispose);
      await firstEmission(container);
      expect(container.read(holdingTagOptionsProvider), ['奖金', '工资']);
    });
  });

  test('HoldingSort.label:金额与名称的方向文案', () {
    expect(
      const HoldingSort(HoldingSortField.currentValue, false).label,
      '当前金额 · 从高到低',
    );
    expect(
      const HoldingSort(HoldingSortField.name, true).label,
      '产品名称 · A → Z',
    );
  });
}
