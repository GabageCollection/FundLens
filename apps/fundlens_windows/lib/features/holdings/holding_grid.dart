import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import 'holding_filters.dart';
import 'holding_status.dart';

/// 复选框列宽。
const double kHoldingCheckboxWidth = 40;

/// 产品名称列最小宽度。
const double kHoldingNameMinWidth = 200;

/// 名称列的 flex 权重(与滚动区列共享剩余空间)。
const double _kNameFlex = 2;

/// 单元格上下文:持仓 + 组合总额 + 新鲜行情集合。
final class HoldingCellContext {
  const HoldingCellContext({
    required this.holding,
    required this.totalValue,
    required this.freshQuoteHoldingIds,
  });

  final Holding holding;
  final DecimalValue totalValue;
  final Set<String> freshQuoteHoldingIds;

  /// 资产占比;组合总额为 0 时为 null(显示"不适用")。
  DecimalValue? get share {
    if (totalValue.isZero) return null;
    return holding.currentValue.divide(totalValue);
  }
}

/// 滚动区列定义:标签、最小宽度、flex 权重、对齐与取值函数。
final class HoldingColumnSpec {
  const HoldingColumnSpec({
    required this.label,
    required this.minWidth,
    required this.flex,
    required this.numeric,
    required this.value,
    this.sortField,
    this.muted = false,
  });

  final String label;
  final double minWidth;
  final double flex;
  final bool numeric;
  final String Function(HoldingCellContext ctx) value;
  final HoldingSortField? sortField;

  /// 克制文字标签列(数据状态):单元格用 muted 色,不用高饱和色块。
  final bool muted;
}

/// 11 个滚动区列(复选框与产品名称在冻结区)。
List<HoldingColumnSpec> holdingColumnSpecs() {
  String assetClass(HoldingCellContext c) =>
      HoldingLabels.assetClass[c.holding.assetClass]!;
  String platform(HoldingCellContext c) =>
      HoldingLabels.sourcePlatform[c.holding.sourcePlatform]!;
  String amount(HoldingCellContext c) =>
      HoldingValueFormatter.amount(c.holding.currentValue);
  String share(HoldingCellContext c) => holdingShareText(c.share);
  String quantity(HoldingCellContext c) => holdingQuantityText(c.holding);
  String price(HoldingCellContext c) => holdingPriceText(c.holding);
  String cost(HoldingCellContext c) => holdingCostText(c.holding);
  String profit(HoldingCellContext c) => holdingProfitText(c.holding);
  String returnRate(HoldingCellContext c) => holdingReturnText(c.holding);
  String date(HoldingCellContext c) => holdingValuationDateText(c.holding);
  String status(HoldingCellContext c) => holdingDataStatusLabels[
      deriveHoldingDataStatus(
        c.holding,
        freshQuoteHoldingIds: c.freshQuoteHoldingIds,
      )]!;

  return [
    HoldingColumnSpec(
      label: '资产类别', minWidth: 88, flex: 1, numeric: false,
      value: assetClass,
    ),
    HoldingColumnSpec(
      label: '来源平台', minWidth: 96, flex: 1, numeric: false,
      value: platform,
    ),
    HoldingColumnSpec(
      label: '当前金额', minWidth: 120, flex: 1.2, numeric: true,
      value: amount, sortField: HoldingSortField.currentValue,
    ),
    HoldingColumnSpec(
      label: '资产占比', minWidth: 96, flex: 1, numeric: true,
      value: share, sortField: HoldingSortField.share,
    ),
    HoldingColumnSpec(
      label: '份额', minWidth: 110, flex: 1, numeric: true,
      value: quantity, sortField: HoldingSortField.quantity,
    ),
    HoldingColumnSpec(
      label: '现价', minWidth: 100, flex: 1, numeric: true,
      value: price, sortField: HoldingSortField.currentPrice,
    ),
    HoldingColumnSpec(
      label: '覆盖成本', minWidth: 120, flex: 1.2, numeric: true,
      value: cost, sortField: HoldingSortField.cost,
    ),
    HoldingColumnSpec(
      label: '持仓盈亏', minWidth: 120, flex: 1.2, numeric: true,
      value: profit, sortField: HoldingSortField.profit,
    ),
    HoldingColumnSpec(
      label: '持仓收益率', minWidth: 110, flex: 1, numeric: true,
      value: returnRate, sortField: HoldingSortField.returnRate,
    ),
    HoldingColumnSpec(
      label: '估值日期', minWidth: 104, flex: 1, numeric: false,
      value: date, sortField: HoldingSortField.valuationDate,
    ),
    HoldingColumnSpec(
      label: '数据状态', minWidth: 96, flex: 1, numeric: false,
      value: status, muted: true,
    ),
  ];
}

/// 一次布局解析的结果:名称列宽、各滚动列宽、是否横向滚动。
final class HoldingColumnLayout {
  const HoldingColumnLayout({
    required this.nameWidth,
    required this.columnWidths,
    required this.scrollable,
  });

  final double nameWidth;
  final List<double> columnWidths;
  final bool scrollable;

  /// 滚动区内容总宽。
  double get scrollContentWidth =>
      columnWidths.fold<double>(0, (a, b) => a + b);
}

/// 列宽分配:容器超出各列最小宽度总和时按 flex 权重分满;
/// 不足时取最小宽度并横向滚动。
HoldingColumnLayout resolveHoldingColumnLayout(double availableWidth) {
  final specs = holdingColumnSpecs();
  final mins = [for (final c in specs) c.minWidth];
  final minScroll = mins.fold<double>(0, (a, b) => a + b);
  final minTotal = kHoldingCheckboxWidth + kHoldingNameMinWidth + minScroll;
  if (availableWidth <= minTotal) {
    return HoldingColumnLayout(
      nameWidth: kHoldingNameMinWidth,
      columnWidths: mins,
      scrollable: true,
    );
  }
  final leftover = availableWidth - minTotal;
  final flexSum = _kNameFlex + specs.fold<double>(0, (s, c) => s + c.flex);
  return HoldingColumnLayout(
    nameWidth: kHoldingNameMinWidth + leftover * (_kNameFlex / flexSum),
    columnWidths: [
      for (final c in specs) c.minWidth + leftover * (c.flex / flexSum),
    ],
    scrollable: false,
  );
}

/// 虚拟化双区持仓表格:冻结区(复选框+产品名称) + 横向滚动区(11 列)。
///
/// 布局由 [resolveHoldingColumnLayout] 一次解析,表头与两区行共用,
/// 保证列对齐;垂直滚动由两个 ListView 经重入保护同步。
class HoldingGrid extends StatefulWidget {
  const HoldingGrid({
    super.key,
    required this.holdings,
    required this.totalValue,
    required this.freshQuoteHoldingIds,
    required this.sort,
    required this.onSortChanged,
    required this.selectedIds,
    required this.onSelectedChanged,
    required this.onSelectAllChanged,
    required this.onRowTap,
  });

  final List<Holding> holdings;
  final DecimalValue totalValue;
  final Set<String> freshQuoteHoldingIds;
  final HoldingSort sort;
  final void Function(HoldingSort sort) onSortChanged;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onSelectedChanged;
  final void Function(bool selectAll) onSelectAllChanged;
  final void Function(Holding holding)? onRowTap;

  @override
  State<HoldingGrid> createState() => _HoldingGridState();
}

class _HoldingGridState extends State<HoldingGrid> {
  final ScrollController _frozenController = ScrollController();
  final ScrollController _detailController = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _frozenController.addListener(
      () => _sync(_frozenController, _detailController),
    );
    _detailController.addListener(
      () => _sync(_detailController, _frozenController),
    );
  }

  @override
  void dispose() {
    _frozenController.dispose();
    _detailController.dispose();
    super.dispose();
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

  /// 表头点击的三态循环:
  /// 未激活 → 首态(数字列降序,名称升序);首态 → 反向;反向 → 默认。
  void _cycleSort(HoldingSortField field) {
    final sort = widget.sort;
    final firstAscending = field == HoldingSortField.name;
    if (sort.field != field) {
      widget.onSortChanged(HoldingSort(field, firstAscending));
      return;
    }
    if (sort.ascending == firstAscending) {
      widget.onSortChanged(HoldingSort(field, !firstAscending));
    } else {
      widget.onSortChanged(HoldingSort.initial);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.holdings.isEmpty) {
      return const SizedBox.shrink();
    }
    final specs = holdingColumnSpecs();
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = resolveHoldingColumnLayout(constraints.maxWidth);
        final frozenWidth = kHoldingCheckboxWidth + layout.nameWidth;
        final scrollRegionWidth = constraints.maxWidth - frozenWidth;
        final contentWidth =
            layout.scrollable ? layout.scrollContentWidth : scrollRegionWidth;
        return DecoratedBox(
          decoration: const BoxDecoration(color: FundLensTokens.surface),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 冻结区:复选框 + 产品名称。
              SizedBox(
                width: frozenWidth,
                child: Column(
                  children: [
                    _FrozenHeader(
                      nameWidth: layout.nameWidth,
                      sort: widget.sort,
                      onSortTap: _cycleSort,
                      selectedIds: widget.selectedIds,
                      holdings: widget.holdings,
                      onSelectAllChanged: widget.onSelectAllChanged,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        key: const ValueKey('holding-grid-frozen'),
                        controller: _frozenController,
                        itemExtent: FundLensTokens.rowHeight,
                        itemCount: widget.holdings.length,
                        itemBuilder: (context, index) {
                          final holding = widget.holdings[index];
                          return HoldingGridFrozenRow(
                            key: ValueKey('frozen-${holding.id}'),
                            holding: holding,
                            nameWidth: layout.nameWidth,
                            selected: widget.selectedIds.contains(holding.id),
                            onSelectedChanged: widget.onSelectedChanged,
                            onTap: widget.onRowTap == null
                                ? null
                                : () => widget.onRowTap!(holding),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              // 横向滚动区:11 列。
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('holding-grid-hscroll'),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      children: [
                        _DetailHeader(
                          specs: specs,
                          widths: layout.columnWidths,
                          sort: widget.sort,
                          onSortTap: _cycleSort,
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            key: const ValueKey('holding-grid-detail'),
                            controller: _detailController,
                            itemExtent: FundLensTokens.rowHeight,
                            itemCount: widget.holdings.length,
                            itemBuilder: (context, index) {
                              final holding = widget.holdings[index];
                              return HoldingGridRowView(
                                key: ValueKey('detail-${holding.id}'),
                                specs: specs,
                                widths: layout.columnWidths,
                                cellContext: HoldingCellContext(
                                  holding: holding,
                                  totalValue: widget.totalValue,
                                  freshQuoteHoldingIds:
                                      widget.freshQuoteHoldingIds,
                                ),
                                selected:
                                    widget.selectedIds.contains(holding.id),
                                onTap: widget.onRowTap == null
                                    ? null
                                    : () => widget.onRowTap!(holding),
                              );
                            },
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
      },
    );
  }
}

/// 冻结区表头:全选复选框 + 可排序的"产品名称"。
class _FrozenHeader extends StatelessWidget {
  const _FrozenHeader({
    required this.nameWidth,
    required this.sort,
    required this.onSortTap,
    required this.selectedIds,
    required this.holdings,
    required this.onSelectAllChanged,
  });

  final double nameWidth;
  final HoldingSort sort;
  final void Function(HoldingSortField field) onSortTap;
  final Set<String> selectedIds;
  final List<Holding> holdings;
  final void Function(bool selectAll) onSelectAllChanged;

  @override
  Widget build(BuildContext context) {
    final allSelected =
        holdings.isNotEmpty && selectedIds.length == holdings.length;
    final someSelected = selectedIds.isNotEmpty && !allSelected;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: kHoldingCheckboxWidth,
            child: Center(
              child: Checkbox(
                key: const ValueKey('select-all'),
                tristate: true,
                value: allSelected ? true : (someSelected ? null : false),
                semanticLabel: '全选持仓',
                onChanged: (value) => onSelectAllChanged(value ?? false),
              ),
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: _SortHeaderCell(
              label: '产品名称',
              field: HoldingSortField.name,
              sort: sort,
              numeric: false,
              active: sort.field == HoldingSortField.name,
              onTap: () => onSortTap(HoldingSortField.name),
            ),
          ),
        ],
      ),
    );
  }
}

/// 滚动区表头。
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.specs,
    required this.widths,
    required this.sort,
    required this.onSortTap,
  });

  final List<HoldingColumnSpec> specs;
  final List<double> widths;
  final HoldingSort sort;
  final void Function(HoldingSortField field) onSortTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < specs.length; i++)
            SizedBox(
              width: widths[i],
              child: specs[i].sortField == null
                  ? _PlainHeaderCell(
                      label: specs[i].label,
                      numeric: specs[i].numeric,
                    )
                  : _SortHeaderCell(
                      label: specs[i].label,
                      field: specs[i].sortField!,
                      sort: sort,
                      numeric: specs[i].numeric,
                      active: sort.field == specs[i].sortField,
                      onTap: () => onSortTap(specs[i].sortField!),
                    ),
            ),
        ],
      ),
    );
  }
}

class _PlainHeaderCell extends StatelessWidget {
  const _PlainHeaderCell({required this.label, required this.numeric});

  final String label;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
      child: Align(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// 可排序表头单元格:箭头指示方向,InkWell 可聚焦(键盘 Enter 触发)。
class _SortHeaderCell extends StatelessWidget {
  const _SortHeaderCell({
    required this.label,
    required this.field,
    required this.sort,
    required this.numeric,
    required this.active,
    required this.onTap,
  });

  final String label;
  final HoldingSortField field;
  final HoldingSort sort;
  final bool numeric;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('sort-${field.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FundLensTokens.space3),
        child: Row(
          mainAxisAlignment:
              numeric ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (active)
              Icon(
                sort.ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14,
                color: FundLensTokens.accent,
              ),
          ],
        ),
      ),
    );
  }
}

/// 冻结区行:复选框 + 产品名称(含代码副行)。
class HoldingGridFrozenRow extends StatelessWidget {
  const HoldingGridFrozenRow({
    super.key,
    required this.holding,
    required this.nameWidth,
    required this.selected,
    required this.onSelectedChanged,
    required this.onTap,
  });

  final Holding holding;
  final double nameWidth;
  final bool selected;
  final void Function(String id, bool selected) onSelectedChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _RowFrame(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: kHoldingCheckboxWidth,
            child: Center(
              child: Checkbox(
                key: ValueKey('select-${holding.id}'),
                value: selected,
                semanticLabel: '选择 ${holding.productName}',
                onChanged: (value) =>
                    onSelectedChanged(holding.id, value ?? false),
              ),
            ),
          ),
          SizedBox(
            width: nameWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FundLensTokens.space3,
              ),
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
                  if (holding.productCode != null)
                    Text(
                      holding.productCode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 滚动区行:11 列单元格。
class HoldingGridRowView extends StatelessWidget {
  const HoldingGridRowView({
    super.key,
    required this.specs,
    required this.widths,
    required this.cellContext,
    required this.selected,
    required this.onTap,
  });

  final List<HoldingColumnSpec> specs;
  final List<double> widths;
  final HoldingCellContext cellContext;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _RowFrame(
      selected: selected,
      onTap: onTap,
      // 滚动区行不参与焦点遍历:冻结区行已承载焦点,避免 Tab 重复。
      focusable: false,
      child: Row(
        children: [
          for (var i = 0; i < specs.length; i++)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FundLensTokens.space3,
                ),
                child: Text(
                  specs[i].value(cellContext),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign:
                      specs[i].numeric ? TextAlign.right : TextAlign.left,
                  style: _cellStyle(specs[i], theme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 单元格样式:数值列用等宽数字;持仓盈亏/收益率列按红盈利绿亏损着色
  /// (零值中性,保持默认墨色);数据状态列为 muted 克制文字标签;
  /// 其余金额列保持默认墨色。
  TextStyle _cellStyle(HoldingColumnSpec spec, ThemeData theme) {
    final financial = theme.extension<FundLensTextStyles>()!.financialNumber;
    if (!spec.numeric) {
      // 数据状态列:克制文字标签,不饱和色块。
      if (spec.muted) {
        return theme.textTheme.bodyMedium!
            .copyWith(color: FundLensTokens.muted);
      }
      return theme.textTheme.bodyMedium!;
    }
    final direction = switch (spec.sortField) {
      HoldingSortField.profit => holdingPnlDirection(
          cellContext.holding.currentFloatingProfit,
        ),
      HoldingSortField.returnRate => holdingPnlDirection(
          holdingEffectiveReturn(cellContext.holding),
        ),
      _ => null,
    };
    final color = switch (direction) {
      PnlDirection.positive => FundLensTokens.profit,
      PnlDirection.negative => FundLensTokens.loss,
      // 零值:既非盈也非亏,保持默认墨色。
      PnlDirection.zero || null => null,
    };
    if (color == null) return financial;
    return financial.copyWith(color: color);
  }
}

/// 行外框:选中底色、hover 反馈、点击;整行可聚焦(Enter 等效点击)。
///
/// 点击时显式请求焦点:抽屉/对话框 pop 后 Flutter 会把焦点恢复到
/// 弹出前聚焦的节点,行持有焦点后 Enter 即可重新触发行操作。
class _RowFrame extends StatefulWidget {
  const _RowFrame({
    required this.selected,
    required this.onTap,
    required this.child,
    this.focusable = true,
  });

  final bool selected;
  final VoidCallback? onTap;
  final Widget child;

  /// 是否参与 Tab 焦点遍历:冻结区行承载焦点,滚动区行仅鼠标/触屏点击。
  final bool focusable;

  @override
  State<_RowFrame> createState() => _RowFrameState();
}

class _RowFrameState extends State<_RowFrame> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    // 焦点变化时重建,以切换行外框的 2px 主色轮廓。
    if (mounted) setState(() {});
  }

  void _handleTap() {
    if (widget.focusable) _focusNode.requestFocus();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return Material(
      color:
          widget.selected ? FundLensTokens.accentSoft : FundLensTokens.surface,
      child: InkWell(
        focusNode: _focusNode,
        canRequestFocus: widget.focusable,
        onTap: widget.onTap == null ? null : _handleTap,
        hoverColor: FundLensTokens.canvas,
        focusColor: FundLensTokens.canvas,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: focused
                ? Border.all(
                    color: FundLensTokens.accent,
                    width: FundLensTokens.focusOutlineWidth,
                  )
                : null,
          ),
          // 前景绘制:边框叠加在内容之上,不参与布局,避免 2px 边框引起
          // 内容内缩与列错位(表格行高与列宽保持原值)。
          position: DecorationPosition.foreground,
          child: SizedBox(height: FundLensTokens.rowHeight, child: widget.child),
        ),
      ),
    );
  }
}
