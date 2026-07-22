import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';

/// Column presets for the holdings grid.
enum HoldingColumnPreset { portfolio, trading, platform }

/// Sort orders supported by the holdings workspace.
enum HoldingSort { currentValueDescending, currentValueAscending, nameAscending }

/// Filter state for the holdings page.
final class HoldingFilterState {
  const HoldingFilterState({
    this.query = '',
    this.sources = const {},
    this.assetClasses = const {},
    this.preset = HoldingColumnPreset.portfolio,
    this.sort = HoldingSort.currentValueDescending,
  });

  final String query;
  final Set<SourcePlatform> sources;
  final Set<AssetClass> assetClasses;
  final HoldingColumnPreset preset;
  final HoldingSort sort;

  HoldingFilterState copyWith({
    String? query,
    Set<SourcePlatform>? sources,
    Set<AssetClass>? assetClasses,
    HoldingColumnPreset? preset,
    HoldingSort? sort,
  }) {
    return HoldingFilterState(
      query: query ?? this.query,
      sources: sources ?? this.sources,
      assetClasses: assetClasses ?? this.assetClasses,
      preset: preset ?? this.preset,
      sort: sort ?? this.sort,
    );
  }
}

/// Interactive filter state for the holdings page.
final holdingFilterProvider =
    StateProvider<HoldingFilterState>((ref) => const HoldingFilterState());

/// Applies the holdings-page filter state on top of the (possibly
/// spectrum-filtered) holdings and returns a sorted, unmodifiable list.
final visibleHoldingsProvider = Provider<List<Holding>>((ref) {
  final holdings = ref.watch(filteredHoldingsProvider);
  final filter = ref.watch(holdingFilterProvider);

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

  final sorted = result.toList(growable: false);
  switch (filter.sort) {
    case HoldingSort.currentValueDescending:
      sorted.sort((a, b) => b.currentValue.compareTo(a.currentValue));
    case HoldingSort.currentValueAscending:
      sorted.sort((a, b) => a.currentValue.compareTo(b.currentValue));
    case HoldingSort.nameAscending:
      sorted.sort((a, b) => a.productName.compareTo(b.productName));
  }
  return List.unmodifiable(sorted);
});

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
