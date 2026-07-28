import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'holding_filters.dart';

/// Width of the frozen region (product name/source + current amount).
const double kFrozenRegionWidth = 420;

/// Width of the name/source column inside the frozen region.
const double kFrozenNameWidth = 260;

/// Dedicated value formatter for the holdings grid.
///
/// Row widgets never compute profits or returns; they only render the values
/// already present on [Holding] through this formatter.
abstract final class HoldingValueFormatter {
  /// `1234567.8` → `1,234,567.80`; negative values keep their sign.
  static String amount(DecimalValue? value) {
    if (value == null) return '—';
    return _grouped(value.canonical);
  }

  /// Plain grouped number without forcing decimals (quantities, prices).
  static String number(DecimalValue? value) {
    if (value == null) return '—';
    return _grouped(value.canonical);
  }

  /// Signed percent: `0.125` → `+12.50%`. Always carries a +/- sign so the
  /// profit/loss state is readable without color.
  static String signedPercent(DecimalValue? value) {
    if (value == null) return '—';
    final canonical = value.canonical;
    final parsed = double.tryParse(canonical);
    if (parsed == null) return '—';
    final percent = parsed * 100;
    final sign = percent < 0 ? '-' : '+';
    return '$sign${percent.abs().toStringAsFixed(2)}%';
  }

  /// Signed amount with explicit +/- for profit values.
  static String signedAmount(DecimalValue? value) {
    if (value == null) return '—';
    if (value.isNegative) return amount(value);
    return '+${amount(value)}';
  }

  static String date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toUtc();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _grouped(String canonical) {
    final negative = canonical.startsWith('-');
    final body = negative ? canonical.substring(1) : canonical;
    final dot = body.indexOf('.');
    final integer = dot == -1 ? body : body.substring(0, dot);
    final fraction = dot == -1 ? '' : body.substring(dot);
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      final remaining = integer.length - i;
      buffer.write(integer[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return '${negative ? '-' : ''}$buffer$fraction';
  }
}

/// Column definition for the horizontally scrollable region.
final class HoldingColumn {
  const HoldingColumn({
    required this.label,
    required this.width,
    required this.value,
    this.numeric = true,
  });

  final String label;
  final double width;
  final String Function(Holding holding) value;
  final bool numeric;
}

List<HoldingColumn> holdingColumnsFor(HoldingColumnPreset preset) {
  return switch (preset) {
    HoldingColumnPreset.portfolio => [
        HoldingColumn(
          label: '份额',
          width: 110,
          value: (h) => HoldingValueFormatter.number(h.quantity),
        ),
        HoldingColumn(
          label: '现价',
          width: 110,
          value: (h) => HoldingValueFormatter.number(h.currentPrice),
        ),
        HoldingColumn(
          label: '成本金额',
          width: 130,
          value: (h) => HoldingValueFormatter.amount(h.costAmount),
        ),
        HoldingColumn(
          label: '持仓盈亏',
          width: 130,
          value: (h) => HoldingValueFormatter.signedAmount(h.holdingProfit),
        ),
        HoldingColumn(
          label: '持仓收益率',
          width: 120,
          value: (h) => HoldingValueFormatter.signedPercent(h.holdingReturn),
        ),
        HoldingColumn(
          label: '估值日期',
          width: 110,
          numeric: false,
          value: (h) => HoldingValueFormatter.date(h.valuationDate),
        ),
      ],
    HoldingColumnPreset.trading => [
        HoldingColumn(
          label: '产品代码',
          width: 110,
          numeric: false,
          value: (h) => h.productCode ?? '—',
        ),
        HoldingColumn(
          label: '份额',
          width: 110,
          value: (h) => HoldingValueFormatter.number(h.quantity),
        ),
        HoldingColumn(
          label: '现价',
          width: 110,
          value: (h) => HoldingValueFormatter.number(h.currentPrice),
        ),
        HoldingColumn(
          label: '成本价',
          width: 110,
          value: (h) => HoldingValueFormatter.number(h.costPrice),
        ),
        HoldingColumn(
          label: '当日盈亏',
          width: 130,
          value: (h) => HoldingValueFormatter.signedAmount(h.dailyProfit),
        ),
        HoldingColumn(
          label: '累计盈亏',
          width: 130,
          value: (h) => HoldingValueFormatter.signedAmount(h.cumulativeProfit),
        ),
      ],
    HoldingColumnPreset.platform => [
        HoldingColumn(
          label: '来源平台',
          width: 100,
          numeric: false,
          value: (h) => HoldingLabels.sourcePlatform[h.sourcePlatform]!,
        ),
        HoldingColumn(
          label: '币种',
          width: 80,
          numeric: false,
          value: (h) => h.currency,
        ),
        HoldingColumn(
          label: '数据出处',
          width: 100,
          numeric: false,
          value: (h) => HoldingLabels.dataOrigin[h.dataOrigin]!,
        ),
        HoldingColumn(
          label: '估值方式',
          width: 110,
          numeric: false,
          value: (h) => HoldingLabels.valuationMethod[h.valuationMethod]!,
        ),
        HoldingColumn(
          label: '备注',
          width: 220,
          numeric: false,
          value: (h) => h.note ?? '—',
        ),
      ],
  };
}

/// Frozen-region row: product name + source and current amount.
class HoldingGridRow extends StatelessWidget {
  const HoldingGridRow({super.key, required this.holding});

  final Holding holding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financial = theme.extension<FundLensTextStyles>()!.financialNumber;
    return SizedBox(
      height: FundLensTokens.rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: kFrozenNameWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holding.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    HoldingLabels.sourcePlatform[holding.sourcePlatform]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                HoldingValueFormatter.amount(holding.currentValue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: financial,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable-region row: preset-specific columns only.
class HoldingGridRowDetail extends StatelessWidget {
  const HoldingGridRowDetail({
    super.key,
    required this.holding,
    required this.columns,
  });

  final Holding holding;
  final List<HoldingColumn> columns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financial = theme.extension<FundLensTextStyles>()!.financialNumber;
    return SizedBox(
      height: FundLensTokens.rowHeight,
      child: Row(
        children: [
          for (final column in columns)
            SizedBox(
              width: column.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  column.value(holding),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign:
                      column.numeric ? TextAlign.right : TextAlign.left,
                  style: column.numeric
                      ? financial
                      : theme.textTheme.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Virtualized two-region holdings table.
///
/// A 420 px frozen region (name/source + current amount) sits beside a
/// horizontally scrollable region of preset-specific columns. Both regions
/// are `ListView.builder` lists with `itemExtent = FundLensTokens.rowHeight`
/// and share vertical scroll offsets through a reentrancy-guarded sync.
class HoldingGrid extends StatefulWidget {
  const HoldingGrid({
    super.key,
    required this.holdings,
    this.preset = HoldingColumnPreset.portfolio,
  });

  final List<Holding> holdings;
  final HoldingColumnPreset preset;

  @override
  State<HoldingGrid> createState() => _HoldingGridState();
}

class _HoldingGridState extends State<HoldingGrid> {
  final ScrollController _frozenController = ScrollController();
  final ScrollController _detailController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  /// Reentrancy guard: while one controller is syncing the other, listener
  /// callbacks triggered by that sync are ignored.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _frozenController.addListener(() => _sync(_frozenController, _detailController));
    _detailController.addListener(() => _sync(_detailController, _frozenController));
  }

  void _sync(ScrollController source, ScrollController target) {
    if (_syncing || !target.hasClients || !source.hasClients) return;
    final offset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - offset).abs() < 0.5) return;
    _syncing = true;
    try {
      target.jumpTo(offset);
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _frozenController.dispose();
    _detailController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = holdingColumnsFor(widget.preset);
    final scrollWidth =
        columns.fold<double>(0, (sum, column) => sum + column.width);

    if (widget.holdings.isEmpty) {
      return const Center(child: Text('暂无持仓'));
    }

    final headerStyle = theme.textTheme.bodySmall;

    return DecoratedBox(
      decoration: const BoxDecoration(color: FundLensTokens.surface),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Frozen region: name/source + current amount.
          SizedBox(
            width: kFrozenRegionWidth,
            child: Column(
              children: [
                _FrozenHeader(style: headerStyle),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('holding-grid-frozen'),
                    controller: _frozenController,
                    itemExtent: FundLensTokens.rowHeight,
                    itemCount: widget.holdings.length,
                    itemBuilder: (context, index) => HoldingGridRow(
                      key: ValueKey('frozen-${widget.holdings[index].id}'),
                      holding: widget.holdings[index],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Horizontally scrollable preset columns.
          Expanded(
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: scrollWidth,
                child: Column(
                  children: [
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          for (final column in columns)
                            SizedBox(
                              width: column.width,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Align(
                                  alignment: column.numeric
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Text(
                                    column.label,
                                    maxLines: 1,
                                    style: headerStyle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        key: const ValueKey('holding-grid-detail'),
                        controller: _detailController,
                        itemExtent: FundLensTokens.rowHeight,
                        itemCount: widget.holdings.length,
                        itemBuilder: (context, index) => HoldingGridRowDetail(
                          key: ValueKey('detail-${widget.holdings[index].id}'),
                          holding: widget.holdings[index],
                          columns: columns,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrozenHeader extends StatelessWidget {
  const _FrozenHeader({required this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: kFrozenNameWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('产品名称', maxLines: 1, style: style),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('当前金额', maxLines: 1, style: style),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
