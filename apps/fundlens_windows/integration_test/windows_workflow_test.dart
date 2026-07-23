import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/app/fundlens_app.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/holdings/holding_export_service.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holdings_page.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/market/quote.dart';
import 'package:fundlens_windows/market/quote_refresh_service.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/import_review/import_review_harness.dart';

/// In-memory snapshot repository: creation freezes the current holdings of
/// the paired holding repository. Rows are immutable; deletion drops them.
final class WorkflowSnapshotRepository implements SnapshotRepository {
  WorkflowSnapshotRepository(this._holdings);

  final WorkflowHoldingRepository _holdings;
  final List<PortfolioSnapshot> snapshots = [];
  var _nextId = 0;

  @override
  Future<String> createFromCurrent({required String label}) async {
    final id = 'wf-${_nextId++}';
    snapshots.add(
      PortfolioSnapshot(
        id: id,
        label: label,
        createdAt: DateTime.now().toUtc(),
        holdings: [
          for (final h in _holdings.holdings)
            SnapshotHolding(
              holdingId: h.id,
              productName: h.productName,
              productCode: h.productCode,
              instrumentType: h.instrumentType,
              assetClass: h.assetClass,
              sourcePlatform: h.sourcePlatform,
              quantity: h.quantity,
              currentPrice: h.currentPrice,
              currentValue: h.currentValue,
              costAmount: h.costAmount,
              holdingProfit: h.holdingProfit,
              dailyProfit: h.dailyProfit,
              cumulativeProfit: h.cumulativeProfit,
              valuationDate: h.valuationDate,
              fieldProvenance: h.fieldProvenance,
            ),
        ],
      ),
    );
    return id;
  }

  @override
  Future<PortfolioSnapshot> getById(String id) async =>
      snapshots.firstWhere((s) => s.id == id);

  @override
  Future<List<PortfolioSnapshot>> getAll() async => List.of(snapshots);

  @override
  Future<void> deleteById(String id) async {
    snapshots.removeWhere((s) => s.id == id);
  }
}

final class _MemQuoteCacheStore implements QuoteCacheStore {
  final List<CachedQuote> quotes = [];

  @override
  Future<void> upsertAll(List<CachedQuote> next) async {
    quotes.addAll(next);
  }
}

/// In-memory holding repository whose watch stream re-emits after every
/// mutation, mirroring the Drift repository's live query behavior.
final class WorkflowHoldingRepository implements HoldingRepository {
  final List<Holding> holdings = [];
  late final StreamController<List<Holding>> _controller =
      StreamController<List<Holding>>.broadcast(onListen: _emit);

  void _emit() {
    if (!_controller.isClosed) _controller.add(List.of(holdings));
  }

  @override
  Future<void> upsert(Holding holding) async {
    holdings.removeWhere((h) => h.id == holding.id);
    holdings.add(holding);
    _emit();
  }

  @override
  Future<void> replacePlatform(
    SourcePlatform platform,
    List<Holding> next,
  ) async {
    holdings.removeWhere((h) => h.sourcePlatform == platform);
    holdings.addAll(next);
    _emit();
  }

  @override
  Future<void> deleteByIds(List<String> ids) async {
    holdings.removeWhere((h) => ids.contains(h.id));
    _emit();
  }

  @override
  Future<T> inTransaction<T>(Future<T> Function() action) => action();

  @override
  Stream<List<Holding>> watchAll() => _controller.stream;

  @override
  Future<List<Holding>> getAll() async => List.of(holdings);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'windows workflow: manual add → OCR import → resolve → commit → '
    'refresh → snapshots → compare → export',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final holdingRepository = WorkflowHoldingRepository();
      final snapshotRepository = WorkflowSnapshotRepository(holdingRepository);
      final engine = FakeDataEngineClient();
      final picker = FakeImportFilePicker()
        ..screenshots = const [
          PickedImportFile(name: 'alipay.png', path: 'originals/alipay.png'),
        ];
      final quoteCache = _MemQuoteCacheStore();

      // Synthetic Alipay partial screenshot: the current_value field is
      // low-confidence and unparseable, producing one blocking issue that
      // the user resolves by typing the correct amount.
      engine.responses['ocr.parse_screenshots'] = alipayOcrResponse(
        productName: '支付宝基金',
        currentValue: '7B,347.87',
        confidence: 0.62,
        rowIssues: [blockingIssueJson()],
      );
      engine.responses['market.fetch_quotes'] = {
        'quotes': [
          {
            'product_code': '000001',
            'provider': 'fake-provider',
            'status': 'fresh',
            'value': '2.00',
            'valuation_date': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            holdingRepositoryProvider.overrideWithValue(holdingRepository),
            snapshotRepositoryProvider.overrideWithValue(snapshotRepository),
            portfolioCalculatorProvider
                .overrideWithValue(PortfolioCalculator()),
            dataQualityCalculatorProvider
                .overrideWithValue(DataQualityCalculator()),
            dataEngineClientProvider.overrideWithValue(engine),
            importFilePickerProvider.overrideWithValue(picker),
            screenshotTempStoreProvider
                .overrideWithValue(FakeScreenshotTempStore()),
            importDraftStoreProvider
                .overrideWithValue(InMemoryImportDraftStore()),
            quoteRefreshServiceProvider.overrideWithValue(
              QuoteRefreshService(
                engine: engine,
                holdings: holdingRepository,
                quoteCache: quoteCache,
                clock: DateTime.now,
              ),
            ),
          ],
          child: const FundLensApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FundLensApp)),
      );

      const navLabels = [
        '资产总览',
        '资产分析',
        '全部持仓',
        '历史快照',
        '导入与识别',
        '设置与备份',
      ];

      Future<void> gotoPage(int index) async {
        await tester.tap(find.text(navLabels[index]));
        await tester.pumpAndSettle();
      }

      Future<void> addHolding({
        required String name,
        required String amount,
        String? assetClassLabel,
        String? code,
        String? quantity,
        String? price,
      }) async {
        await tester.tap(find.text('添加持仓'));
        await tester.pumpAndSettle();
        if (assetClassLabel != null) {
          await tester
              .tap(find.byType(DropdownButtonFormField<AssetClass>));
          await tester.pumpAndSettle();
          await tester.tap(find.text(assetClassLabel).last);
          await tester.pumpAndSettle();
        }
        await tester.enterText(
          find.widgetWithText(TextFormField, '产品名称'),
          name,
        );
        if (code != null) {
          await tester.enterText(
            find.widgetWithText(TextFormField, '产品代码'),
            code,
          );
        }
        if (quantity != null) {
          await tester.enterText(
            find.widgetWithText(TextFormField, '份额'),
            quantity,
          );
        }
        if (price != null) {
          await tester.enterText(
            find.widgetWithText(TextFormField, '现价'),
            price,
          );
        }
        await tester.enterText(
          find.widgetWithText(TextFormField, '当前金额'),
          amount,
        );
        await tester.tap(find.text('保存'));
        await tester.pumpAndSettle();
      }

      // 1. Add a manual deposit and a quote-eligible fund.
      // First navigation uses the keyboard (Ctrl+3) to prove shortcut access.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('添加持仓'), findsOneWidget);
      await addHolding(name: '测试存款', amount: '50000', assetClassLabel: '存款');
      await addHolding(
        name: '测试基金',
        amount: '150',
        assetClassLabel: '权益',
        code: '000001',
        quantity: '100',
        price: '1.5',
      );
      expect(find.text('测试存款'), findsOneWidget);
      expect(find.text('测试基金'), findsOneWidget);

      // 2. Import a synthetic Alipay partial screenshot.
      await gotoPage(4); // 导入与识别
      await tester.tap(find.text('导入截图'));
      await tester.pumpAndSettle();
      expect(find.text('部分持仓'), findsOneWidget);
      // The blocking issue disables commit before resolution.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '确认写入'),
            )
            .onPressed,
        isNull,
      );

      // 3. Resolve the low-confidence field and commit.
      await tester.enterText(
        find.byKey(const ValueKey('ocr-field-current_value-0')),
        '78347.87',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认写入'));
      await tester.pumpAndSettle();
      expect(find.text('写入完成'), findsOneWidget);
      expect(
        holdingRepository.holdings.any((h) => h.productName == '支付宝基金'),
        isTrue,
      );

      // 4. Refresh quotes from the settings page.
      await gotoPage(5); // 设置与备份
      await tester.scrollUntilVisible(
        find.text('手动刷新行情'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('手动刷新行情'));
      await tester.pumpAndSettle();
      expect(find.textContaining('更新 1 条'), findsOneWidget);
      expect(quoteCache.quotes, hasLength(1));
      final refreshed = holdingRepository.holdings
          .firstWhere((h) => h.productCode == '000001');
      expect(refreshed.currentValue.canonical, '200');

      // 5. Save two snapshots.
      await gotoPage(3); // 历史快照
      for (final label in ['第一次', '第二次']) {
        await tester.tap(find.text('新建快照'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, label);
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
      }
      expect(find.text('第一次'), findsOneWidget);
      expect(find.text('第二次'), findsOneWidget);

      // 6. Compare them: delta is labelled as amount change only.
      expect(find.text('资产金额变化'), findsOneWidget);
      expect(find.textContaining('快照收益'), findsNothing);

      // 7. Export the filtered holdings.
      container.read(holdingFilterProvider.notifier).state =
          const HoldingFilterState(assetClasses: {AssetClass.equity});
      await tester.pumpAndSettle();
      final visible = container.read(visibleHoldingsProvider);
      expect(visible.map((h) => h.productName), ['测试基金']);
      final exportFile = await const HoldingExportService().exportCsv(
        visible,
        '${Directory.systemTemp.path}/fundlens_workflow_export.csv',
      );
      final bytes = await exportFile.readAsBytes();
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      await exportFile.delete();

      // No overflow, unhandled exception, network call or real engine.
      expect(engine.calls, isNot(contains('product.match_candidates')));
      expect(tester.takeException(), isNull);
    },
  );
}
