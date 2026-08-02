import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_grid.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';
import 'package:fundlens_windows/theme/fundlens_tokens.dart';

final _now = DateTime.utc(2026, 7, 1);

Holding gridHolding({
  required String id,
  String name = '产品',
  DecimalValue? currentValue,
  DecimalValue? quantity,
  DecimalValue? currentPrice,
  DecimalValue? costAmount,
  DecimalValue? holdingProfit,
  ValuationMethod valuationMethod = ValuationMethod.automaticQuote,
  DateTime? valuationDate,
  bool noPrice = false,
  bool noDate = false,
}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: name,
    productCode: '110011',
    currency: 'CNY',
    quantity: quantity ?? DecimalValue.parse('1000'),
    currentPrice: noPrice ? null : (currentPrice ?? DecimalValue.parse('1.5')),
    currentValue: currentValue ?? DecimalValue.parse('1500'),
    costAmount: costAmount,
    holdingProfit: holdingProfit,
    valuationMethod: valuationMethod,
    valuationDate: noDate ? null : (valuationDate ?? _now),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

List<Holding> generateGridHoldings(int count) {
  return [
    for (var i = 0; i < count; i++)
      gridHolding(
        id: 'h-$i',
        name: '产品${i.toString().padLeft(4, '0')}',
        currentValue: DecimalValue.parse('${1000 + i}'),
      ),
  ];
}

class GridHarness extends StatefulWidget {
  const GridHarness({
    super.key,
    required this.holdings,
    this.totalValue,
    this.onRowTap,
  });

  final List<Holding> holdings;
  final DecimalValue? totalValue;
  final void Function(Holding holding)? onRowTap;

  @override
  State<GridHarness> createState() => _GridHarnessState();
}

class _GridHarnessState extends State<GridHarness> {
  HoldingSort _sort = HoldingSort.initial;
  Set<String> _selected = const {};

  @override
  Widget build(BuildContext context) {
    // 模拟页面层 visibleHoldingsProvider:按当前排序应用比较器。
    final sorted = [...widget.holdings]..sort(holdingComparator(_sort));
    return MaterialApp(
      theme: FundLensTheme.light,
      home: Scaffold(
        body: HoldingGrid(
          holdings: sorted,
          totalValue: widget.totalValue ?? DecimalValue.parse('100000'),
          freshQuoteHoldingIds: {for (final h in widget.holdings) h.id},
          sort: _sort,
          onSortChanged: (sort) => setState(() => _sort = sort),
          selectedIds: _selected,
          onSelectedChanged: (id, selected) => setState(() {
            _selected = {..._selected}
              ..remove(id)
              ..addAll(selected ? [id] : const <String>[]);
          }),
          onSelectAllChanged: (all) => setState(() {
            _selected =
                all ? {for (final h in widget.holdings) h.id} : const <String>{};
          }),
          onRowTap: widget.onRowTap,
        ),
      ),
    );
  }
}

Future<void> pumpGrid(
  WidgetTester tester, {
  required List<Holding> holdings,
  Size size = const Size(1440, 900),
  DecimalValue? totalValue,
  void Function(Holding holding)? onRowTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GridHarness(
    holdings: holdings,
    totalValue: totalValue,
    onRowTap: onRowTap,
  ));
  await tester.pump();
}

void main() {
  group('列宽分配 resolveHoldingColumnLayout', () {
    test('宽容器:列分满宽度且不滚动', () {
      final layout = resolveHoldingColumnLayout(1600);
      expect(layout.scrollable, isFalse);
      final total = kHoldingCheckboxWidth +
          layout.nameWidth +
          layout.columnWidths.fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1600, 0.01));
      expect(layout.columnWidths.length, 11);
    });

    test('窄容器:取最小宽度并横向滚动', () {
      final layout = resolveHoldingColumnLayout(700);
      expect(layout.scrollable, isTrue);
      expect(layout.nameWidth, kHoldingNameMinWidth);
    });
  });

  group('表格渲染', () {
    testWidgets('表头含全部 12 个字段', (tester) async {
      await pumpGrid(tester, holdings: generateGridHoldings(3));
      for (final label in [
        '产品名称', '资产类别', '来源平台', '当前金额', '资产占比', '份额',
        '现价', '覆盖成本', '持仓盈亏', '持仓收益率', '估值日期', '数据状态',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('1920 宽度无溢出,数据状态列可见', (tester) async {
      await pumpGrid(
        tester,
        holdings: generateGridHoldings(5),
        size: const Size(1920, 1080),
      );
      expect(find.text('数据状态'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('1280 宽度可横向滚动,名称列固定', (tester) async {
      await pumpGrid(
        tester,
        holdings: generateGridHoldings(5),
        size: const Size(1280, 720),
      );
      expect(find.text('产品0000'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('holding-grid-hscroll')),
        const Offset(-600, 0),
      );
      await tester.pump();
      // 横向滚动后名称列(冻结区)仍然可见。
      expect(find.text('产品0000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2000 行只构建少量行组件(虚拟滚动)', (tester) async {
      await pumpGrid(
        tester,
        holdings: generateGridHoldings(2000),
        size: const Size(1280, 720),
      );
      expect(
        tester.widgetList(find.byType(HoldingGridRowView)).length,
        lessThan(100),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('缺失数据文案', () {
    testWidgets('缺成本/不适用/暂无行情分行显示', (tester) async {
      await pumpGrid(tester, holdings: [
        // 无成本 → 覆盖成本/盈亏/收益率 缺少成本。
        gridHolding(id: 'a', name: '无成本产品'),
        // 手动金额类 → 份额/现价 不适用。
        gridHolding(
          id: 'b',
          name: '手动产品',
          valuationMethod: ValuationMethod.manualAmount,
        ),
        // 行情类缺价 → 现价 暂无行情,数据状态 暂无行情。
        gridHolding(id: 'c', name: '缺价产品', noPrice: true),
      ]);
      expect(find.text('缺少成本'), findsWidgets);
      expect(find.text('不适用'), findsWidgets);
      expect(find.text('暂无行情'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('组合总额为 0 时占比显示不适用', (tester) async {
      await pumpGrid(
        tester,
        holdings: [gridHolding(id: 'a')],
        totalValue: DecimalValue.zero,
      );
      expect(find.text('不适用'), findsOneWidget);
    });
  });

  group('排序表头', () {
    testWidgets('点击当前金额表头:降序→升序→默认三态循环', (tester) async {
      await pumpGrid(tester, holdings: [
        gridHolding(
          id: 'small', name: '小额', currentValue: DecimalValue.parse('10')),
        gridHolding(
          id: 'big', name: '大额', currentValue: DecimalValue.parse('99')),
      ]);
      // 默认当前金额降序:大额在上。
      expect(
        tester.getTopLeft(find.text('大额')).dy,
        lessThan(tester.getTopLeft(find.text('小额')).dy),
      );
      // 第一次点击:反转为升序。
      await tester.tap(find.byKey(const ValueKey('sort-currentValue')));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('小额')).dy,
        lessThan(tester.getTopLeft(find.text('大额')).dy),
      );
      // 第二次点击:回到默认(降序)。
      await tester.tap(find.byKey(const ValueKey('sort-currentValue')));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('大额')).dy,
        lessThan(tester.getTopLeft(find.text('小额')).dy),
      );
    });

    testWidgets('点击名称表头:按名称升序', (tester) async {
      // 注:名称排序为 Dart code-unit 序(A < B),与 HoldingSort.label
      // 的 'A → Z' 文案一致;中文按 code unit 比较,故用 A/B 验证。
      await pumpGrid(tester, holdings: [
        gridHolding(id: 'a', name: 'B产品'),
        gridHolding(id: 'b', name: 'A产品'),
      ]);
      await tester.tap(find.byKey(const ValueKey('sort-name')));
      await tester.pump();
      expect(
        tester.getTopLeft(find.text('A产品')).dy,
        lessThan(tester.getTopLeft(find.text('B产品')).dy),
      );
    });
  });

  group('复选框与行交互', () {
    testWidgets('表头全选/取消全选', (tester) async {
      await pumpGrid(tester, holdings: generateGridHoldings(3));
      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pump();
      for (final h in generateGridHoldings(3)) {
        final checkbox = tester.widget<Checkbox>(
          find.byKey(ValueKey('select-${h.id}')),
        );
        expect(checkbox.value, isTrue);
      }
      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pump();
      final first = tester.widget<Checkbox>(
        find.byKey(const ValueKey('select-h-0')),
      );
      expect(first.value, isFalse);
    });

    testWidgets('行点击触发 onRowTap,复选框点击不触发', (tester) async {
      Holding? tapped;
      await pumpGrid(
        tester,
        holdings: [gridHolding(id: 'a', name: '目标产品')],
        onRowTap: (h) => tapped = h,
      );
      await tester.tap(find.text('目标产品'));
      await tester.pump();
      expect(tapped?.id, 'a');

      tapped = null;
      await tester.tap(find.byKey(const ValueKey('select-a')));
      await tester.pump();
      expect(tapped, isNull);
    });
  });

  group('盈亏红绿/状态列 muted/零值中性着色', () {
    testWidgets('盈利红、亏损绿、缺成本与状态列 muted、零值默认墨色', (tester) async {
      await pumpGrid(tester, holdings: [
        // 盈利行:成本 980,盈亏 +20。
        gridHolding(
          id: 'profit',
          name: '盈利产品',
          currentValue: DecimalValue.parse('1000'),
          costAmount: DecimalValue.parse('980'),
          holdingProfit: DecimalValue.parse('20'),
        ),
        // 亏损行:盈亏 -3.2。
        gridHolding(
          id: 'loss',
          name: '亏损产品',
          currentValue: DecimalValue.parse('1000'),
          costAmount: DecimalValue.parse('1000'),
          holdingProfit: DecimalValue.parse('-3.2'),
        ),
        // 缺成本行:无成本也无盈亏 → 覆盖成本/盈亏/收益率/数据状态列
        // 均显示"缺少成本",但只有数据状态列是 muted。
        gridHolding(id: 'nocost', name: '无成本产品'),
        // 零值行:盈亏为 0,既不红也不绿,保持默认墨色。
        gridHolding(
          id: 'zero',
          name: '零值产品',
          currentValue: DecimalValue.parse('1000'),
          costAmount: DecimalValue.parse('1000'),
          holdingProfit: DecimalValue.zero,
        ),
      ]);

      // 1. 盈利行持仓盈亏文本为 profit 红。
      final profitText = tester.widget<Text>(find.text('+20.00'));
      expect(profitText.style?.color, FundLensTokens.profit);

      // 2. 亏损行持仓盈亏文本为 loss 绿。
      final lossText = tester.widget<Text>(find.text('-3.20'));
      expect(lossText.style?.color, FundLensTokens.loss);

      // 3. 数据状态列 muted:三行"正常"全部 muted;"缺少成本"四处
      // (覆盖成本/持仓盈亏/持仓收益率/数据状态)中仅数据状态列为 muted。
      final normalTexts = tester.widgetList<Text>(find.text('正常')).toList();
      expect(normalTexts.length, 3);
      for (final t in normalTexts) {
        expect(t.style?.color, FundLensTokens.muted, reason: '状态"正常"');
      }
      final missingCostTexts =
          tester.widgetList<Text>(find.text('缺少成本')).toList();
      expect(missingCostTexts.length, 4);
      expect(
        missingCostTexts
            .where((t) => t.style?.color == FundLensTokens.muted)
            .length,
        1,
        reason: '数据状态列的"缺少成本"应为 muted,其余单元格保持默认墨色',
      );

      // 4. 零值行盈亏文本为默认墨色(非 profit/loss)。
      final zeroText = tester.widget<Text>(find.text('+0.00'));
      expect(zeroText.style?.color, FundLensTokens.ink);
      expect(zeroText.style?.color, isNot(FundLensTokens.profit));
      expect(zeroText.style?.color, isNot(FundLensTokens.loss));

      expect(tester.takeException(), isNull);
    });
  });
}
