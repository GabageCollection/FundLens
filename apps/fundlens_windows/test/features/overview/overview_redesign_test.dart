import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/overview/overview_page.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

import 'asset_spectrum_test.dart' show FakeHoldingRepository;

final class _FakeSnapshotRepository implements SnapshotRepository {
  _FakeSnapshotRepository(this._snapshots);

  final List<PortfolioSnapshot> _snapshots;

  @override
  Future<List<PortfolioSnapshot>> getAll() async => _snapshots;

  @override
  Future<PortfolioSnapshot> getById(String id) =>
      throw UnimplementedError('unused');

  @override
  Future<String> createFromCurrent({required String label}) async => 'unused';

  @override
  Future<void> deleteById(String id) async {}
}

Holding _holding({
  required String id,
  required AssetClass assetClass,
  required String productName,
  required String currentValue,
  String? costAmount,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.manual,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: productName,
    currency: 'CNY',
    currentValue: DecimalValue.parse(currentValue),
    costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

List<Holding> _defaultHoldings() => [
      _holding(
        id: 'h-1',
        assetClass: AssetClass.equity,
        productName: '稳健成长混合基金',
        currentValue: '52340.00',
        costAmount: '48000.00',
      ),
      _holding(
        id: 'h-2',
        assetClass: AssetClass.fixedIncome,
        productName: '安泰纯债债券基金',
        currentValue: '40120.00',
        costAmount: '41000.00',
      ),
      _holding(
        id: 'h-3',
        assetClass: AssetClass.cash,
        productName: '余额现金管理',
        currentValue: '31000.00',
      ),
    ];

PortfolioSnapshot _snapshot(String id, DateTime at, String total) {
  return PortfolioSnapshot(
    id: id,
    label: id,
    createdAt: at,
    holdings: [
      SnapshotHolding(
        holdingId: '$id-1',
        productName: '产品',
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.equity,
        sourcePlatform: SourcePlatform.manual,
        currentValue: DecimalValue.parse(total),
        costAmount: DecimalValue.parse('90000.00'),
        fieldProvenance: const {},
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  List<Holding>? holdings,
  List<PortfolioSnapshot> snapshots = const [],
  Size size = const Size(1440, 900),
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider
        .overrideWithValue(FakeHoldingRepository(holdings ?? _defaultHoldings())),
    snapshotRepositoryProvider
        .overrideWithValue(_FakeSnapshotRepository(snapshots)),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
    dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const Scaffold(body: OverviewPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('KPI 区', () {
    testWidgets('金额带币种符号和千位分隔', (tester) async {
      await _pump(tester);
      expect(find.text('¥123,460.00'), findsOneWidget);
      expect(find.text('¥89,000.00'), findsOneWidget);
    });

    testWidgets('正负收益同时显示符号与颜色', (tester) async {
      await _pump(tester);
      // 52340-48000=+4340,40120-41000=-880,合计浮动盈亏 +3460。
      expect(find.text('+¥3,460.00'), findsOneWidget);
    });

    testWidgets('每个指标提供 Tooltip 说明', (tester) async {
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == '当前全部持仓金额之和',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == '有成本数据资产的当前金额占总资产的比例',
        ),
        findsOneWidget,
      );
    });

    testWidgets('显示数据截至时间', (tester) async {
      await _pump(tester);
      expect(find.textContaining('数据截至 20'), findsOneWidget);
    });
  });

  group('资产结构带', () {
    testWidgets('分段图例显示类别名称、占比和金额', (tester) async {
      await _pump(tester);
      expect(find.textContaining('权益'), findsWidgets);
      expect(find.textContaining('42.4%'), findsWidgets);
      expect(find.textContaining('¥52,340.00'), findsWidgets);
    });

    testWidgets('Hover 分段显示详细数据 Tooltip', (tester) async {
      await _pump(tester);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').contains('权益'),
        ),
        findsWidgets,
      );
    });

    testWidgets('总金额为 0 时显示明确空状态而不是占位条', (tester) async {
      await _pump(tester, holdings: [
        _holding(
          id: 'h-0',
          assetClass: AssetClass.cash,
          productName: '零金额产品',
          currentValue: '0.00',
        ),
      ]);
      expect(find.textContaining('暂无有效资产数据'), findsOneWidget);
    });
  });

  group('资产净值趋势', () {
    testWidgets('快照不足 2 个时显示引导空状态', (tester) async {
      await _pump(tester, snapshots: [
        _snapshot('s1', DateTime(2026, 7, 1), '100000.00'),
      ]);
      expect(find.text('创建第二个快照后可查看趋势'), findsOneWidget);
    });

    testWidgets('快照足够时显示趋势图与范围切换', (tester) async {
      // 快照日期相对今天:默认范围为近 1 月(30 天),固定绝对日期会随
      // 时间漂移掉出窗口导致图表不渲染。
      final now = DateTime.now();
      await _pump(tester, snapshots: [
        _snapshot('s1', now.subtract(const Duration(days: 20)), '100000.00'),
        _snapshot('s2', now.subtract(const Duration(days: 5)), '110000.00'),
      ]);
      expect(find.text('近1月'), findsOneWidget);
      expect(find.text('近3月'), findsOneWidget);
      expect(find.text('近1年'), findsOneWidget);
      expect(find.text('全部'), findsWidgets);
      expect(find.byKey(const ValueKey('trend-chart')), findsOneWidget);
    });

    testWidgets('悬停趋势图显示十字线数值卡', (tester) async {
      final now = DateTime.now();
      await _pump(tester, snapshots: [
        _snapshot('s1', now.subtract(const Duration(days: 20)), '100000.00'),
        _snapshot('s2', now.subtract(const Duration(days: 5)), '110000.00'),
      ]);
      final chart = find.byKey(const ValueKey('trend-chart'));
      expect(chart, findsOneWidget);

      // 无悬停时没有数值卡(数值卡是独立 Text,与图下摘要的长文本区分)。
      expect(find.text('覆盖成本 ¥90,000.00'), findsNothing);

      // 悬停到图表中心:命中最近的数据点 s2 并显示数值卡。
      final center = tester.getCenter(chart);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: center);
      await tester.pump();
      await gesture.moveTo(center);
      await tester.pump();

      expect(find.text('总资产 ¥110,000.00'), findsOneWidget);
      expect(find.text('覆盖成本 ¥90,000.00'), findsOneWidget);

      // 移出图表后数值卡消失。
      await gesture.moveTo(Offset(center.dx, -100));
      await tester.pump();
      expect(find.text('总资产 ¥110,000.00'), findsNothing);
    });
  });

  group('风险与数据提醒', () {
    testWidgets('提醒包含发现、原因与可执行操作', (tester) async {
      await _pump(tester, holdings: [
        _holding(
          id: 'h-1',
          assetClass: AssetClass.fixedIncome,
          productName: '东方添益债券',
          currentValue: '31800.00',
          costAmount: '30000.00',
        ),
        _holding(
          id: 'h-2',
          assetClass: AssetClass.equity,
          productName: '产品B',
          currentValue: '23000.00',
        ),
        _holding(
          id: 'h-3',
          assetClass: AssetClass.cash,
          productName: '产品C',
          currentValue: '23000.00',
        ),
        _holding(
          id: 'h-4',
          assetClass: AssetClass.gold,
          productName: '产品D',
          currentValue: '22200.00',
        ),
      ]);
      expect(find.textContaining('集中度较高'), findsWidgets);
      expect(find.textContaining('东方添益债券占总资产 31.8%'), findsOneWidget);
      expect(find.text('查看持仓'), findsWidgets);
    });

    testWidgets('无提醒时显示明确的正常状态', (tester) async {
      await _pump(tester, holdings: [
        for (var i = 0; i < 6; i++)
          _holding(
            id: 'h-$i',
            assetClass: AssetClass.equity,
            productName: '产品$i',
            currentValue: '2000.00',
            costAmount: '1800.00',
          ),
      ]);
      expect(find.text('未发现需要处理的数据或风险问题'), findsOneWidget);
    });
  });

  group('最高持仓表格', () {
    testWidgets('显示完整表头', (tester) async {
      await _pump(tester);
      for (final header in ['产品名称', '资产类别', '来源平台', '当前金额', '资产占比', '持仓盈亏']) {
        expect(find.text(header), findsOneWidget, reason: '缺少表头 $header');
      }
    });

    testWidgets('提供查看全部持仓入口', (tester) async {
      await _pump(tester);
      expect(find.text('查看全部持仓'), findsOneWidget);
    });

    testWidgets('持仓行显示平台与占比', (tester) async {
      await _pump(tester);
      expect(find.text('手工录入'), findsWidgets);
      expect(find.text('42.4%'), findsWidgets);
    });
  });

  group('验收', () {
    testWidgets('窄屏堆叠布局不溢出', (tester) async {
      await _pump(tester, size: const Size(800, 900), snapshots: [
        _snapshot('s1', DateTime(2026, 6, 1), '100000.00'),
        _snapshot('s2', DateTime(2026, 7, 1), '110000.00'),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('总资产'), findsOneWidget);
    });
  });
}
