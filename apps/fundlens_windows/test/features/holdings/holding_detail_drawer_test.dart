import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holding_detail_drawer.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final _now = DateTime.utc(2026, 7, 20, 10, 30);

Holding drawerHolding({
  String id = 'h-1',
  String? productCode = '110011',
  DecimalValue? costAmount,
  DecimalValue? cumulativeProfit,
  String? note = '定投中',
  List<String> platformTags = const ['工资账户'],
  Map<String, FieldProvenance> fieldProvenance = const {
    'currentValue': FieldProvenance(kind: ProvenanceKind.original, source: '导入'),
  },
}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: '测试基金',
    productCode: productCode,
    currency: 'CNY',
    quantity: DecimalValue.parse('1000'),
    currentPrice: DecimalValue.parse('1.5'),
    currentValue: DecimalValue.parse('1500'),
    costAmount: costAmount ?? DecimalValue.parse('1200'),
    holdingProfit: DecimalValue.parse('300'),
    holdingReturn: DecimalValue.parse('0.25'),
    cumulativeProfit: cumulativeProfit,
    valuationMethod: ValuationMethod.automaticQuote,
    valuationDate: DateTime.utc(2026, 7, 19),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: fieldProvenance,
    platformTags: platformTags,
    note: note,
    createdAt: _now,
    updatedAt: _now,
  );
}

/// 记录写操作的 Fake 仓库。
final class RecordingHoldingRepository implements HoldingRepository {
  RecordingHoldingRepository(this._holdings);

  final List<Holding> _holdings;
  final List<Holding> upserted = [];
  final List<List<String>> deletedIds = [];

  @override
  Stream<List<Holding>> watchAll() => Stream.value(List.unmodifiable(_holdings));

  @override
  Future<List<Holding>> getAll() async => List.unmodifiable(_holdings);

  @override
  Future<void> upsert(Holding holding) async {
    upserted.add(holding);
    _holdings
      ..removeWhere((h) => h.id == holding.id)
      ..add(holding);
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    deletedIds.add(ids);
    _holdings.removeWhere((h) => ids.contains(h.id));
  }

  @override
  Future<void> replacePlatform(
    SourcePlatform platform, List<Holding> holdings) async {}

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();
}

Future<ProviderContainer> pumpDrawer(
  WidgetTester tester, {
  required RecordingHoldingRepository repo,
  String holdingId = 'h-1',
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(repo),
    portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
  ]);
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: Scaffold(body: HoldingDetailDrawer(holdingId: holdingId)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('抽屉分节渲染', () {
    testWidgets('六分节齐全,关键值正确', (tester) async {
      await pumpDrawer(tester, repo: RecordingHoldingRepository([drawerHolding()]));
      // 注意:来源平台/当前金额同时是分节标题与行标签,故用 findsWidgets。
      for (final title in ['基本信息', '来源平台', '当前金额', '成本与收益', '数据来源']) {
        expect(find.text(title), findsWidgets, reason: title);
      }
      expect(find.text('测试基金'), findsWidgets);
      expect(find.text('支付宝'), findsOneWidget);
      expect(find.text('¥1,500.00'), findsOneWidget);
      // 占比 = 1500 ÷ 1500 = 100%。
      expect(find.text('100.00%'), findsOneWidget);
      expect(find.text('+25.00%'), findsOneWidget);
      expect(find.text('工资账户'), findsOneWidget);
      expect(find.text('原始确认'), findsOneWidget);
      // '最后更新' 分节在列表底部,900px 视口内需滚动到可见。
      // ('最后更新' 同时是分节标题与行标签,故不能用作 scrollUntilVisible 的唯一目标。)
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(find.text('最后更新'), findsWidgets);
      // 操作按钮。
      expect(find.text('编辑'), findsOneWidget);
      expect(find.text('刷新行情'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('缺失文案:无代码未填写,无累计盈亏不适用,含累计脚注', (tester) async {
      await pumpDrawer(
        tester,
        repo: RecordingHoldingRepository([
          drawerHolding(productCode: null, note: null),
        ]),
      );
      expect(find.text('未填写'), findsWidgets);
      expect(find.text('不适用'), findsOneWidget);
      expect(find.text('累计盈亏只展示,不纳入当前盈亏汇总。'), findsOneWidget);
    });
  });

  group('行级动作', () {
    testWidgets('编辑:打开编辑对话框,保存后显示已保存 Toast', (tester) async {
      final repo = RecordingHoldingRepository([drawerHolding()]);
      await pumpDrawer(tester, repo: repo);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      // 编辑对话框打开(标题为"编辑持仓")。
      expect(find.text('编辑持仓'), findsOneWidget);
      // 直接保存(初始值合法)。
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(repo.upserted, hasLength(1));
      expect(find.text('已保存'), findsOneWidget);
    });

    testWidgets('刷新行情:服务未接线时按钮禁用', (tester) async {
      await pumpDrawer(tester, repo: RecordingHoldingRepository([drawerHolding()]));
      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '刷新行情'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('删除:二次确认后删除并关闭抽屉', (tester) async {
      final repo = RecordingHoldingRepository([drawerHolding()]);
      // 用真实 showGeneralDialog 路径验证关闭。
      final container = ProviderContainer(overrides: [
        holdingRepositoryProvider.overrideWithValue(repo),
        portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
      ]);
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: FundLensTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showHoldingDetailDrawer(context, 'h-1'),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(find.text('基本信息'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      // 二次确认对话框,明示产品名。
      expect(find.textContaining('测试基金'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();
      expect(repo.deletedIds, [
        ['h-1'],
      ]);
      // 抽屉关闭,Toast 出现。
      expect(find.text('基本信息'), findsNothing);
      expect(find.text('已删除'), findsOneWidget);
    });
  });
}
