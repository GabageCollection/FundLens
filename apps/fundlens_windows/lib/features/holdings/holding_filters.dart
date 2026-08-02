import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import 'holding_status.dart';

/// 表头与排序下拉共用的可排序字段。
enum HoldingSortField {
  name,
  currentValue,
  share,
  quantity,
  currentPrice,
  cost,
  profit,
  returnRate,
  valuationDate,
}

/// 排序字段中文标签。
const holdingSortFieldLabels = <HoldingSortField, String>{
  HoldingSortField.name: '产品名称',
  HoldingSortField.currentValue: '当前金额',
  HoldingSortField.share: '资产占比',
  HoldingSortField.quantity: '份额',
  HoldingSortField.currentPrice: '现价',
  HoldingSortField.cost: '覆盖成本',
  HoldingSortField.profit: '持仓盈亏',
  HoldingSortField.returnRate: '持仓收益率',
  HoldingSortField.valuationDate: '估值日期',
};

/// 排序状态:字段 + 方向。默认当前金额降序。
final class HoldingSort {
  const HoldingSort(this.field, this.ascending);

  final HoldingSortField field;
  final bool ascending;

  static const initial = HoldingSort(HoldingSortField.currentValue, false);

  /// 排序下拉与表头共用的展示文案。
  String get label {
    final direction = field == HoldingSortField.name
        ? (ascending ? 'A → Z' : 'Z → A')
        : (ascending ? '从低到高' : '从高到低');
    return '${holdingSortFieldLabels[field]} · $direction';
  }

  @override
  bool operator ==(Object other) {
    return other is HoldingSort &&
        other.field == field &&
        other.ascending == ascending;
  }

  @override
  int get hashCode => Object.hash(field, ascending);
}

/// 持仓页筛选状态。
final class HoldingFilterState {
  const HoldingFilterState({
    this.query = '',
    this.sources = const {},
    this.assetClasses = const {},
    this.statuses = const {},
    this.tags = const {},
    this.sort = HoldingSort.initial,
  });

  final String query;
  final Set<SourcePlatform> sources;
  final Set<AssetClass> assetClasses;
  final Set<HoldingDataStatus> statuses;

  /// 组合标签筛选;元素为 null 表示"未标记"(platformTags 为空的持仓)。
  final Set<String?> tags;
  final HoldingSort sort;

  HoldingFilterState copyWith({
    String? query,
    Set<SourcePlatform>? sources,
    Set<AssetClass>? assetClasses,
    Set<HoldingDataStatus>? statuses,
    Set<String?>? tags,
    HoldingSort? sort,
  }) {
    return HoldingFilterState(
      query: query ?? this.query,
      sources: sources ?? this.sources,
      assetClasses: assetClasses ?? this.assetClasses,
      statuses: statuses ?? this.statuses,
      tags: tags ?? this.tags,
      sort: sort ?? this.sort,
    );
  }

  /// 是否存在任一激活的筛选(不含排序)。
  bool get hasActiveFilter {
    return query.trim().isNotEmpty ||
        sources.isNotEmpty ||
        assetClasses.isNotEmpty ||
        statuses.isNotEmpty ||
        tags.isNotEmpty;
  }

  /// 清除全部筛选,保留排序。
  HoldingFilterState cleared() => HoldingFilterState(sort: sort);
}

/// 持仓页交互筛选状态。
final holdingFilterProvider =
    StateProvider<HoldingFilterState>((ref) => const HoldingFilterState());

/// 多选状态:选中的持仓 id 集合。筛选变化不清空,删除/取消后清空。
final holdingSelectionProvider = StateProvider<Set<String>>((ref) => const {});

/// 全部持仓出现过的组合标签(去重排序);"未标记"由界面层追加。
final holdingTagOptionsProvider = Provider<List<String>>((ref) {
  final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
  final tags = <String>{for (final h in holdings) ...h.platformTags};
  final sorted = tags.toList()..sort();
  return List.unmodifiable(sorted);
});

/// 排序比较器:空值恒排末尾(与方向无关),同值按 id 稳定次序。
int Function(Holding, Holding) holdingComparator(HoldingSort sort) {
  int sign(int c) => sort.ascending ? c : -c;

  int compareDecimal(DecimalValue? a, DecimalValue? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return sign(a.compareTo(b));
  }

  int compareDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return sign(a.compareTo(b));
  }

  return (a, b) {
    final c = switch (sort.field) {
      HoldingSortField.name => sign(a.productName.compareTo(b.productName)),
      // 同一分母下占比序与金额序一致。
      HoldingSortField.currentValue ||
      HoldingSortField.share =>
        compareDecimal(a.currentValue, b.currentValue),
      HoldingSortField.quantity => compareDecimal(a.quantity, b.quantity),
      HoldingSortField.currentPrice =>
        compareDecimal(a.currentPrice, b.currentPrice),
      HoldingSortField.cost =>
        compareDecimal(a.effectiveCostAmount, b.effectiveCostAmount),
      HoldingSortField.profit =>
        compareDecimal(a.currentFloatingProfit, b.currentFloatingProfit),
      HoldingSortField.returnRate =>
        compareDecimal(holdingEffectiveReturn(a), holdingEffectiveReturn(b)),
      HoldingSortField.valuationDate =>
        compareDate(a.valuationDate, b.valuationDate),
    };
    return c != 0 ? c : a.id.compareTo(b.id);
  };
}

/// 组合筛选(搜索/类别/平台/状态/标签)与排序后的可见持仓。
final visibleHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(filteredHoldingsProvider);
  final filter = ref.watch(holdingFilterProvider);
  final freshIds = ref.watch(freshQuoteHoldingIdsProvider);

  final query = filter.query.trim();
  Iterable<Holding> result = holdings;
  if (query.isNotEmpty) {
    final lower = query.toLowerCase();
    result = result.where((holding) {
      return holding.productName.contains(query) ||
          (holding.productCode?.toLowerCase().contains(lower) ?? false);
    });
  }
  if (filter.sources.isNotEmpty) {
    result = result.where((h) => filter.sources.contains(h.sourcePlatform));
  }
  if (filter.assetClasses.isNotEmpty) {
    result = result.where((h) => filter.assetClasses.contains(h.assetClass));
  }
  if (filter.statuses.isNotEmpty) {
    result = result.where(
      (h) => filter.statuses.contains(
        deriveHoldingDataStatus(h, freshQuoteHoldingIds: freshIds),
      ),
    );
  }
  if (filter.tags.isNotEmpty) {
    result = result.where(
      (h) => h.platformTags.isEmpty
          ? filter.tags.contains(null)
          : h.platformTags.any(filter.tags.contains),
    );
  }

  final sorted = result.toList(growable: false);
  sorted.sort(holdingComparator(filter.sort));
  return List.unmodifiable(sorted);
});

// === 以下内容从旧文件原样保留: ===
// - _quoteEligibleTypes 与 holdingSupportsQuoteRefresh
// - HoldingLabels(sourcePlatform / instrumentType / assetClass /
//   valuationMethod / dataOrigin)
// (原 HoldingColumnPreset 枚举与 preset 字段已删除)

/// Instruments whose quotes come from market providers.
const _quoteEligibleTypes = {
  InstrumentType.stock,
  InstrumentType.etf,
  InstrumentType.lof,
  InstrumentType.reit,
  InstrumentType.offExchangeFund,
};

/// Quote refresh is only meaningful for coded, quote-eligible assets.
/// Manual amount-only assets (confirmed amounts) never refresh.
bool holdingSupportsQuoteRefresh(Holding holding) {
  return holding.productCode != null &&
      _quoteEligibleTypes.contains(holding.instrumentType) &&
      holding.valuationMethod != ValuationMethod.manualAmount;
}

/// Chinese labels shared by the grid, editor and CSV export.
abstract final class HoldingLabels {
  static const sourcePlatform = {
    SourcePlatform.alipay: '支付宝',
    SourcePlatform.ths: '同花顺',
    SourcePlatform.manual: '手工录入',
  };

  static const instrumentType = {
    InstrumentType.cashManagement: '现金管理',
    InstrumentType.bankDeposit: '银行存款',
    InstrumentType.stock: '股票',
    InstrumentType.etf: 'ETF',
    InstrumentType.lof: 'LOF',
    InstrumentType.reit: 'REIT',
    InstrumentType.offExchangeFund: '场外基金',
    InstrumentType.accumulatedGold: '积存金',
    InstrumentType.physicalGold: '实物黄金',
  };

  static const assetClass = {
    AssetClass.cash: '现金',
    AssetClass.deposit: '存款',
    AssetClass.equity: '权益',
    AssetClass.fixedIncome: '固收',
    AssetClass.mixed: '混合',
    AssetClass.gold: '黄金',
    AssetClass.other: '其他',
  };

  static const valuationMethod = {
    ValuationMethod.automaticQuote: '行情估值',
    ValuationMethod.quantityTimesPrice: '份额×现价',
    ValuationMethod.manualAmount: '金额确认',
  };

  static const dataOrigin = {
    DataOrigin.manual: '手工',
    DataOrigin.excel: 'Excel',
    DataOrigin.csv: 'CSV',
    DataOrigin.ocr: '截图识别',
  };
}
