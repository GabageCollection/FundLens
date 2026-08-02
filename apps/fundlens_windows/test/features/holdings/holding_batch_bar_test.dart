import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/data_engine/data_engine_client.dart';
import 'package:fundlens_windows/features/holdings/holding_actions.dart';
import 'package:fundlens_windows/features/holdings/holding_batch_bar.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/market/quote.dart';
import 'package:fundlens_windows/market/quote_refresh_service.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

import 'holding_detail_drawer_test.dart' show RecordingHoldingRepository;

final _now = DateTime.utc(2026, 7, 20);

Holding batchHolding(String id, {AssetClass assetClass = AssetClass.equity}) {
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: assetClass,
    productName: '产品$id',
    productCode: '110011',
    currency: 'CNY',
    quantity: DecimalValue.parse('100'),
    currentPrice: DecimalValue.parse('1.0'),
    currentValue: DecimalValue.parse('100'),
    valuationMethod: ValuationMethod.automaticQuote,
    valuationDate: _now,
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: _now,
    updatedAt: _now,
  );
}

/// 调用即抛异常的行情引擎 fake:模拟行情引擎整体不可用。
/// 抛 Error 而非 Exception:`QuoteRefreshService._fetchQuotes` 只吞 Exception,
/// Error 会穿透到 refresh 抛出,由 HoldingActions.refreshQuotes 捕获转为 null。
final class _FailingEngine implements DataEngineClient {
  @override
  Future<Map<String, Object?>> call(
    String method,
    Map<String, Object?> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    throw StateError('engine down');
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> close() async {}
}

/// 空操作行情缓存:失败路径不会走到写入。
final class _NoopQuoteCache implements QuoteCacheStore {
  @override
  Future<void> upsertAll(List<CachedQuote> quotes) async {}
}

Future<ProviderContainer> pumpBatchBar(
  WidgetTester tester, {
  required RecordingHoldingRepository repo,
  Set<String> selection = const {},
  Future<String?> Function(String suggestedName)? savePath,
  QuoteRefreshService? refreshService,
}) async {
  final container = ProviderContainer(overrides: [
    holdingRepositoryProvider.overrideWithValue(repo),
    if (refreshService != null)
      quoteRefreshServiceProvider.overrideWithValue(refreshService),
    if (savePath != null) holdingSavePathProvider.overrideWithValue(savePath),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: FundLensTheme.light,
        home: const Scaffold(body: HoldingBatchBar()),
      ),
    ),
  );
  await tester.pump();
  container.read(holdingSelectionProvider.notifier).state = selection;
  await tester.pump();
  return container;
}

void main() {
  testWidgets('无选择时不显示,有选择时显示计数', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a')]);
    await pumpBatchBar(tester, repo: repo);
    expect(find.textContaining('已选'), findsNothing);

    await pumpBatchBar(tester, repo: repo, selection: {'a'});
    expect(find.text('已选 1 项'), findsOneWidget);
    for (final action in ['修改资产类别', '修改来源平台', '刷新行情', '导出', '删除', '取消选择']) {
      expect(find.text(action), findsOneWidget, reason: action);
    }
  });

  testWidgets('修改资产类别:事务内逐条 upsert 并标记人工修正', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a'), batchHolding('b')]);
    await pumpBatchBar(tester, repo: repo, selection: {'a', 'b'});

    await tester.tap(find.text('修改资产类别'));
    await tester.pumpAndSettle();
    expect(find.text('黄金'), findsOneWidget);
    await tester.tap(find.text('黄金'));
    await tester.pumpAndSettle();

    expect(repo.upserted, hasLength(2));
    for (final h in repo.upserted) {
      expect(h.assetClass, AssetClass.gold);
      expect(h.fieldProvenance['assetClass']!.kind, ProvenanceKind.userCorrected);
    }
    expect(find.text('已更新 2 项持仓'), findsOneWidget);
  });

  testWidgets('导出:经保存路径接缝写出 CSV 并提示', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a')]);
    final dir = Directory.systemTemp.createTempSync('fundlens-export-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/out.csv';
    await pumpBatchBar(
      tester,
      repo: repo,
      selection: {'a'},
      savePath: (suggested) async => path,
    );

    // 真实文件 IO 需在 runAsync zone 中启动:testWidgets 的 FakeAsync 下,
    // tap 事件回调栈里发起的磁盘写永不完成,故直接调用按钮回调并轮询
    // 文件写入完成(UI 行为与 tap 等价——同一 onPressed 回调)。
    await tester.runAsync(() async {
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '导出'))
          .onPressed!
          .call();
      final file = File(path);
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        if (file.existsSync() && file.lengthSync() > 0) break;
      }
    });
    await tester.pumpAndSettle();

    final content = File(path).readAsStringSync();
    expect(content, contains('产品名称'));
    expect(content, contains('产品a'));
    expect(find.textContaining('已导出'), findsOneWidget);
  });

  testWidgets('删除:二次确认后删除并清空选择', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a'), batchHolding('b')]);
    final container = await pumpBatchBar(
      tester,
      repo: repo,
      selection: {'a', 'b'},
    );

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('确定删除选中的 2 项持仓吗?此操作不可撤销。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(repo.deletedIds, [
      ['a', 'b'],
    ]);
    expect(container.read(holdingSelectionProvider), isEmpty);
    expect(find.text('已删除 2 项持仓'), findsOneWidget);
  });

  testWidgets('刷新行情:服务未接线时禁用', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a')]);
    await pumpBatchBar(tester, repo: repo, selection: {'a'});
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '刷新行情'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('刷新行情:引擎异常时提示重试,不显示 0 计数汇报', (tester) async {
    final repo = RecordingHoldingRepository([batchHolding('a')]);
    final failingService = QuoteRefreshService(
      engine: _FailingEngine(),
      holdings: repo,
      quoteCache: _NoopQuoteCache(),
      clock: () => _now,
    );
    await pumpBatchBar(
      tester,
      repo: repo,
      selection: {'a'},
      refreshService: failingService,
    );

    await tester.tap(find.text('刷新行情'));
    await tester.pumpAndSettle();

    // 刷新失败:提示重试,不得把失败伪装成"更新 0 · 保留 0 · 失败 0"。
    expect(find.text('操作失败:请重试'), findsOneWidget);
    expect(find.textContaining('行情:更新'), findsNothing);
  });
}
