// 页面改造后完整回归集成测试（2026-08-03）。
//
// 覆盖 15 步用户流程 + 真实加密备份/恢复链路 + 四种窗口尺寸布局验证。
// 数据全部为脱敏合成数据；引擎为 Fake，不发起任何网络请求。
// 参照 windows_workflow_test.dart 的 Provider override 模式。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/app/fundlens_app.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/application/portfolio_providers.dart';
import 'package:fundlens_windows/application/portfolio_state.dart';
import 'package:fundlens_windows/backup/backup_format.dart';
import 'package:fundlens_windows/backup/backup_service.dart';
import 'package:fundlens_windows/backup/database_restore_service.dart';
import 'package:fundlens_windows/backup/pointycastle_backup_cipher.dart';
import 'package:fundlens_windows/backup/backup_cipher.dart';
import 'package:fundlens_windows/features/holdings/holding_actions.dart';
import 'package:fundlens_windows/features/holdings/holding_detail_drawer.dart';
import 'package:fundlens_windows/features/holdings/holding_editor_dialog.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_grid.dart';
import 'package:fundlens_windows/features/import_review/import_review_controller.dart';
import 'package:fundlens_windows/features/settings/backup_section.dart';
import 'package:fundlens_windows/market/quote.dart';
import 'package:fundlens_windows/market/quote_refresh_service.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/app_settings_repository.dart';
import 'package:fundlens_windows/storage/database_opener.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:integration_test/integration_test.dart';

import '../test/backup/backup_test_harness.dart';
import '../test/features/import_review/import_review_harness.dart';

/// 内存持仓仓库：每次变更后向 watch 流重新发送全量列表，
/// 模拟 Drift 仓库的实时查询行为；记录 upsert 次数用于防重复提交断言。
final class WorkflowHoldingRepository implements HoldingRepository {
  WorkflowHoldingRepository([List<Holding>? initial])
    : holdings = List.of(initial ?? const <Holding>[]);

  final List<Holding> holdings;
  int upsertCount = 0;
  late final StreamController<List<Holding>> _controller =
      StreamController<List<Holding>>.broadcast(onListen: _emit);

  void _emit() {
    if (!_controller.isClosed) _controller.add(List.of(holdings));
  }

  @override
  Future<void> upsert(Holding holding) async {
    upsertCount++;
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

/// 内存快照仓库：创建时冻结当前持仓；行不可变，删除即丢弃。
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

/// 记录型假备份服务：只记录调用，不写磁盘。
final class _RecordingBackupService implements BackupService {
  final List<({String destination, String password})> calls = [];
  bool failCreate = false;

  @override
  Future<void> create(String destination, String password) async {
    if (failCreate) throw const BackupFailedException('injected failure');
    calls.add((destination: destination, password: password));
  }
}

/// 记录型假恢复服务：prepareRestore 返回固定摘要，confirm 记录调用。
final class _RecordingRestoreService implements DatabaseRestoreService {
  final List<String> prepared = [];
  final List<String> confirmed = [];
  final List<String> cancelled = [];

  @override
  Future<RestoreSession> prepareRestore(String source, String password) async {
    prepared.add(source);
    return RestoreSession(
      tempDir: '/temp/stage',
      candidatePath: '/temp/stage/candidate.db',
      databaseKeyHex: '0' * 64,
      summary: RestoreSummary(
        createdAtUtc: DateTime.utc(2026, 7, 20),
        holdingCount: 7,
        snapshotCount: 3,
        schemaVersion: 1,
      ),
    );
  }

  @override
  Future<void> confirmRestore(RestoreSession session) async {
    confirmed.add(session.tempDir);
  }

  @override
  Future<void> cancelRestore(RestoreSession session) async {
    cancelled.add(session.tempDir);
  }

  @override
  Future<void> restore(String source, String password) async {
    final session = await prepareRestore(source, password);
    await confirmRestore(session);
  }
}

final class _FakeBackupFilePicker implements BackupFilePicker {
  String? savePath;
  String? openPath;

  @override
  Future<String?> pickBackupSaveLocation() async => savePath;

  @override
  Future<String?> pickBackupFile() async => openPath;
}

final class _FakeSettingsRepository implements AppSettingsRepository {
  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> getAll() async => Map.of(values);

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// 脱敏合成持仓工厂（手动/预置数据用）。
Holding makeHolding({
  required String id,
  required String name,
  String? code,
  String? quantity,
  required String amount,
  AssetClass assetClass = AssetClass.other,
  InstrumentType type = InstrumentType.offExchangeFund,
  SourcePlatform platform = SourcePlatform.alipay,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: platform,
    instrumentType: type,
    assetClass: assetClass,
    productName: name,
    currency: 'CNY',
    productCode: code,
    quantity: quantity == null ? null : DecimalValue.parse(quantity),
    currentValue: DecimalValue.parse(amount),
    valuationMethod: ValuationMethod.manualAmount,
    dataOrigin: DataOrigin.manual,
    fieldProvenance: {
      if (code != null)
        'productCode': const FieldProvenance(
          kind: ProvenanceKind.original,
          source: 'user',
        ),
      if (quantity != null)
        'quantity': const FieldProvenance(
          kind: ProvenanceKind.original,
          source: 'user',
        ),
    },
    createdAt: now,
    updatedAt: now,
  );
}

/// 含三行数据的合成 CSV：正常行、与预置持仓同名的重复行、金额无法解析的异常行。
String syntheticCsvV1() {
  return [
    'source_platform,product_name,product_code,instrument_type,current_value,holding_profit,quantity,current_price,currency,platform_tags,note',
    '支付宝,纯债基金A,000001,场外基金,"78,347.87",+428.96,100,1.5,CNY,基金|稳健理财,',
    '支付宝,旧基金,000002,场外基金,"2,000.00",+200.00,10,180,CNY,权益,',
    '支付宝,异常基金,000003,场外基金,abc,0,10,3,CNY,,',
  ].join('\n');
}

/// 修正版 CSV：异常行金额改为可解析数字，其余不变。
String syntheticCsvV2() {
  return [
    'source_platform,product_name,product_code,instrument_type,current_value,holding_profit,quantity,current_price,currency,platform_tags,note',
    '支付宝,纯债基金A,000001,场外基金,"78,347.87",+428.96,100,1.5,CNY,基金|稳健理财,',
    '支付宝,旧基金,000002,场外基金,"2,000.00",+200.00,10,180,CNY,权益,',
    '支付宝,异常基金,000003,场外基金,888.00,0,10,3,CNY,,',
  ].join('\n');
}

PickedImportFile _csvFile(String content) => PickedImportFile(
  name: 'holdings.csv',
  path: 'originals/holdings.csv',
  bytes: Uint8List.fromList(utf8.encode(content)),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const navLabels = [
    '资产总览',
    '资产分析',
    '全部持仓',
    '历史快照',
    '导入与识别',
    '设置与备份',
  ];

  /// 组装回归场景的完整 Provider override 集合。
  ({
    ProviderScope scope,
    WorkflowHoldingRepository holdings,
    WorkflowSnapshotRepository snapshots,
    FakeDataEngineClient engine,
    FakeImportFilePicker picker,
    _MemQuoteCacheStore quoteCache,
    _RecordingBackupService backupService,
    _RecordingRestoreService restoreService,
  }) buildScenario({List<Holding> initialHoldings = const []}) {
    final holdings = WorkflowHoldingRepository(initialHoldings);
    final snapshots = WorkflowSnapshotRepository(holdings);
    final engine = FakeDataEngineClient()
      ..responses['market.fetch_quotes'] = {
        'quotes': [
          {
            'product_code': '000001',
            'provider': 'fake-provider',
            'status': 'fresh',
            'value': '2.00',
            'valuation_date': DateTime.now().toUtc().toIso8601String(),
          },
          {
            'product_code': '000003',
            'provider': 'fake-provider',
            'status': 'failed',
            'value': null,
            'error_code': 'provider_unavailable',
            'valuation_date': DateTime.now().toUtc().toIso8601String(),
          },
        ],
      };
    final picker = FakeImportFilePicker()..csvFile = _csvFile(syntheticCsvV1());
    final quoteCache = _MemQuoteCacheStore();
    final backupService = _RecordingBackupService();
    final restoreService = _RecordingRestoreService();
    final backupPicker = _FakeBackupFilePicker()
      ..savePath = 'C:/out/regression-backup'
      ..openPath = 'C:/out/regression-backup.fundlens-backup';

    final scope = ProviderScope(
      overrides: [
        holdingRepositoryProvider.overrideWithValue(holdings),
        snapshotRepositoryProvider.overrideWithValue(snapshots),
        portfolioCalculatorProvider.overrideWithValue(PortfolioCalculator()),
        dataQualityCalculatorProvider.overrideWithValue(DataQualityCalculator()),
        dataEngineClientProvider.overrideWithValue(engine),
        importFilePickerProvider.overrideWithValue(picker),
        screenshotTempStoreProvider.overrideWithValue(FakeScreenshotTempStore()),
        importDraftStoreProvider.overrideWithValue(InMemoryImportDraftStore()),
        importRecordStoreProvider.overrideWithValue(InMemoryImportRecordStore()),
        quoteRefreshServiceProvider.overrideWithValue(
          QuoteRefreshService(
            engine: engine,
            holdings: holdings,
            quoteCache: quoteCache,
            clock: DateTime.now,
          ),
        ),
        backupServiceProvider.overrideWithValue(backupService),
        databaseRestoreServiceProvider.overrideWithValue(restoreService),
        backupFilePickerProvider.overrideWithValue(backupPicker),
        backupFileSystemProvider.overrideWithValue(InMemoryBackupFileSystem()),
        appSettingsRepositoryProvider.overrideWithValue(_FakeSettingsRepository()),
      ],
      child: const FundLensApp(),
    );
    return (
      scope: scope,
      holdings: holdings,
      snapshots: snapshots,
      engine: engine,
      picker: picker,
      quoteCache: quoteCache,
      backupService: backupService,
      restoreService: restoreService,
    );
  }

  testWidgets('15 步完整回归：导入→分析→编辑→快照→行情→备份恢复→撤销', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final scenario = buildScenario();
    final holdings = scenario.holdings;
    final engine = scenario.engine;
    final picker = scenario.picker;

    await tester.pumpWidget(scenario.scope);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(FundLensApp)),
    );

    // IndexedStack 令六页同时存活，导航标签与页面标题同名文本会多匹配；
    // 侧栏渲染在树中最先，故取 .first。
    Future<void> gotoPage(int index) async {
      await tester.tap(find.text(navLabels[index]).first);
      await tester.pumpAndSettle();
    }

    // 持仓行在总览页「最高持仓」中同名，须在持仓表格内精确定位。
    Finder holdingRow(String name) => find.descendant(
      of: find.byType(HoldingGrid),
      matching: find.text(name),
    );
    // 编辑对话框内容须限定在对话框子树内（工具栏筛选下拉同为
    // DropdownButtonFormField<AssetClass>）。
    Finder inEditor(Finder matching) => find.descendant(
      of: find.byType(HoldingEditorDialog),
      matching: matching,
    );

    // 防溢出/未捕获异常横切检查。
    void expectNoExceptions(String step) {
      final error = tester.takeException();
      expect(error, isNull, reason: '步骤「$step」出现异常: $error');
    }

    // SnackBar 显示期间会遮挡底部按钮；等待其按默认时长消失。
    Future<void> waitForToastToClear() async {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    // ========== 1. 从空数据启动应用 ==========
    expect(container.read(portfolioStateProvider), isA<PortfolioEmpty>());
    for (final label in navLabels) {
      expect(find.text(label), findsWidgets, reason: '六页导航 $label 应存在');
    }
    expect(holdings.holdings, isEmpty);
    expectNoExceptions('1 空数据启动');

    // 先手动添加一条旧基金，作为后续重复记录匹配的现有持仓。
    await gotoPage(2); // 全部持仓
    await tester.tap(find.text('添加持仓'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '产品名称'),
      '旧基金',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '当前金额'),
      '500.00',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(holdings.holdings, hasLength(1));
    expect(holdings.holdings.single.productName, '旧基金');
    // 保存成功的 Toast 会遮挡底部内容，等待消失后再继续。
    await waitForToastToClear();
    expectNoExceptions('1b 手动添加持仓');

    // ========== 2. 导入 CSV ==========
    await gotoPage(4); // 导入与识别
    await tester.tap(find.text('从 CSV 文件导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('点击选择或拖拽文件到此处'));
    await tester.pumpAndSettle();

    // ========== 3. 检查字段映射 ==========
    expect(find.text('字段映射'), findsOneWidget);
    expect(find.text('确认映射'), findsOneWidget);
    expect(find.text('产品名称'), findsWidgets);
    expect(find.text('当前金额'), findsWidgets);
    expectNoExceptions('3 字段映射');

    // ========== 4. 处理重复和异常记录 ==========
    // 字段映射面板内容较长，底部按钮在 1440×900 视口外，先滚动到可见。
    await tester.ensureVisible(find.text('确认映射'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认映射'));
    await tester.pumpAndSettle();
    // 检查面板标志性摘要（向导进度条上也有「确认导入」文本，故不计数）。
    expect(find.text('即将新增'), findsOneWidget);
    expect(find.text('疑似重复'), findsOneWidget);
    expect(find.text('异常金额'), findsOneWidget);
    // 阻断问题存在时提交按钮禁用。
    final commitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '确认导入'),
    );
    expect(commitButton.onPressed, isNull, reason: '异常金额应阻断提交');
    expectNoExceptions('4 检查面板');

    // 处理重复：与预置「旧基金」同名且来源平台不同（手动 vs 支付宝），
    // 检查面板给出逐条决议下拉。DropdownButton 收起时选项文本处于
    // Offstage，无法直接按文本定位，须先展开菜单再选取「合并金额」。
    final resolutionDropdown = find.byKey(const ValueKey('resolution-1'));
    await tester.ensureVisible(resolutionDropdown);
    await tester.pumpAndSettle();
    expect(resolutionDropdown, findsOneWidget, reason: '重复记录应给出决议下拉');
    await tester.tap(resolutionDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('合并金额').last);
    await tester.pumpAndSettle();
    // 重复处理仅生效于可提交路径；异常金额仍在阻断 → 仍禁用。
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认导入'))
          .onPressed,
      isNull,
    );
    // 失败/阻断操作不得破坏原数据：仓库仍只有预置的一条。
    expect(holdings.holdings, hasLength(1));
    expect(holdings.holdings.single.currentValue.canonical, '500');
    expectNoExceptions('4b 阻断处理');

    // 异常行无法在检查面板直接编辑 → 返回来源选择，改用修正版 CSV 重新导入。
    await tester.ensureVisible(find.text('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    // 字段映射页重建后滚动位置重置，返回按钮再次在视口外。
    await tester.ensureVisible(find.text('返回'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    // 返回后停留在来源页（已选来源的 banner 形态，非初始卡片），
    // 上传区仍在，可直接重新选择文件。
    expect(find.text('点击选择或拖拽文件到此处'), findsOneWidget);

    // ========== 5. 确认导入（修正版 CSV） ==========
    picker.csvFile = _csvFile(syntheticCsvV2());
    await tester.tap(find.text('点击选择或拖拽文件到此处'));
    await tester.pumpAndSettle();
    expect(find.text('字段映射'), findsOneWidget);
    await tester.ensureVisible(find.text('确认映射'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认映射'));
    await tester.pumpAndSettle();
    // 异常已修复：检查面板的「异常金额」tile 是常驻 label（数值变 0 条），
    // 阻断解除由下方提交按钮 enabled 断言验证。
    // 返回向导清空了 resolutions，重复决议回到默认「覆盖现有」；
    // 此处重新选择「合并金额」，验证决议确实生效（旧基金 500+2000）。
    final resolutionDropdown2 = find.byKey(const ValueKey('resolution-1'));
    await tester.ensureVisible(resolutionDropdown2);
    await tester.pumpAndSettle();
    await tester.tap(resolutionDropdown2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('合并金额').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认导入'))
          .onPressed,
      isNotNull,
      reason: '异常修复后应可提交',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认导入'));
    await tester.pumpAndSettle();

    // 写入完成 + 无重复记录（恰好 3 条）。
    expect(find.text('导入完成'), findsOneWidget);
    expect(holdings.holdings, hasLength(3));
    final byName = {for (final h in holdings.holdings) h.productName: h};
    expect(byName['纯债基金A']!.currentValue.canonical, '78347.87');
    expect(byName['旧基金']!.currentValue.canonical, '2500'); // 500 + 2000 合并
    expect(byName['异常基金']!.currentValue.canonical, '888');
    // 防重复提交：确认导入按钮已消失，无法再次点击。
    // （向导进度条上的「确认导入」标签仍在，故按按钮类型断言。）
    expect(find.widgetWithText(FilledButton, '确认导入'), findsNothing);
    expectNoExceptions('5 确认导入');

    // ========== 6. 查看资产总览 ==========
    await gotoPage(0);
    expect(find.text('总资产'), findsWidgets);
    final summary = container.read(portfolioSummaryProvider);
    expect(summary.totalValue.canonical, '81735.87');
    // 各资产类别金额之和 = 总资产（占比合计 100%）。
    final classSum = summary.byAssetClass.values
        .fold(DecimalValue.zero, (a, b) => a + b);
    expect(classSum.canonical, summary.totalValue.canonical);
    // 页面刷新数据保持：总览 → 分析 → 返回总览，金额不变。
    await gotoPage(1);
    await gotoPage(0);
    expect(
      container.read(portfolioSummaryProvider).totalValue.canonical,
      '81735.87',
    );
    expectNoExceptions('6 资产总览');

    // ========== 7. 切换三个分析维度 ==========
    await gotoPage(1);
    // 用 Tab 控件精确定位，避免与其他页同名文本（如设置页「资产类别」）冲突。
    for (final tab in ['资产类别', '产品类型', '来源平台']) {
      await tester.tap(find.widgetWithText(Tab, tab));
      await tester.pumpAndSettle();
      // 图表行文本为「{名称} 金额 {金额}」组合，无独立「资产金额」文案；
      // 以分析页固定结论区标题断言维度页已按当前 Tab 渲染。
      expect(find.text('分析结论'), findsWidgets);
      expectNoExceptions('7 分析维度 $tab');
    }
    // 三维度金额合计一致且等于总资产。
    final analysisSummary = container.read(portfolioSummaryProvider);
    final dimSums = [
      analysisSummary.byAssetClass.values.fold(
        DecimalValue.zero,
        (a, b) => a + b,
      ),
      analysisSummary.byInstrumentType.values.fold(
        DecimalValue.zero,
        (a, b) => a + b,
      ),
      analysisSummary.bySource.values.fold(
        DecimalValue.zero,
        (a, b) => a + b,
      ),
    ];
    for (final dimSum in dimSums) {
      expect(dimSum.canonical, '81735.87');
    }
    expectNoExceptions('7b 三维度合计');

    // ========== 8. 搜索、筛选和排序持仓 ==========
    await gotoPage(2);
    // 搜索：只看纯债基金A。
    final searchField = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.hintText ?? '').contains('搜索'),
    );
    await tester.enterText(searchField, '纯债');
    await tester.pumpAndSettle();
    var visible = container.read(visibleHoldingsProvider);
    expect(visible.map((h) => h.productName), ['纯债基金A']);
    // 清空搜索。
    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();
    // 筛选：导入数据全部为「其他」类别。
    container.read(holdingFilterProvider.notifier).state = const HoldingFilterState(
      assetClasses: {AssetClass.other},
    );
    await tester.pumpAndSettle();
    visible = container.read(visibleHoldingsProvider);
    expect(visible, hasLength(3));
    // 排序：当前金额降序。
    container.read(holdingFilterProvider.notifier).state = const HoldingFilterState(
      sort: HoldingSort(HoldingSortField.currentValue, false),
    );
    await tester.pumpAndSettle();
    visible = container.read(visibleHoldingsProvider);
    expect(
      visible.map((h) => h.productName).toList(),
      ['纯债基金A', '旧基金', '异常基金'],
    );
    // 排序：当前金额升序。
    container.read(holdingFilterProvider.notifier).state = const HoldingFilterState(
      sort: HoldingSort(HoldingSortField.currentValue, true),
    );
    await tester.pumpAndSettle();
    visible = container.read(visibleHoldingsProvider);
    expect(
      visible.map((h) => h.productName).toList(),
      ['异常基金', '旧基金', '纯债基金A'],
    );
    // 恢复默认筛选。
    container.read(holdingFilterProvider.notifier).state =
        const HoldingFilterState();
    await tester.pumpAndSettle();
    expectNoExceptions('8 搜索筛选排序');

    // ========== 9. 编辑一条持仓 ==========
    await tester.tap(holdingRow('纯债基金A'));
    await tester.pumpAndSettle();
    // 持仓行点击打开右侧详情抽屉，「编辑」按钮在抽屉内（非编辑对话框）。
    await tester.tap(
      find.descendant(
        of: find.byType(HoldingDetailDrawer),
        matching: find.text('编辑'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      inEditor(find.widgetWithText(TextFormField, '当前金额')),
      '79000.00',
    );
    // 顺带把类别改为「固收」，供后续类别筛选验证区分度。
    await tester.tap(
      inEditor(find.byType(DropdownButtonFormField<AssetClass>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('固收').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(inEditor(find.text('保存')));
    await tester.pumpAndSettle();
    await tester.tap(inEditor(find.text('保存')));
    await tester.pumpAndSettle();
    await waitForToastToClear();
    expect(
      holdings.holdings
          .singleWhere((h) => h.productName == '纯债基金A')
          .currentValue
          .canonical,
      '79000',
    );
    expect(
      holdings.holdings
          .singleWhere((h) => h.productName == '纯债基金A')
          .assetClass,
      AssetClass.fixedIncome,
    );
    // 编辑后总资产精确更新：81735.87 − 78347.87 + 79000 = 82388。
    expect(
      container.read(portfolioSummaryProvider).totalValue.canonical,
      '82388',
    );
    // 类别筛选现在有区分度：固收 1 条、其他 2 条。
    container.read(holdingFilterProvider.notifier).state = const HoldingFilterState(
      assetClasses: {AssetClass.fixedIncome},
    );
    await tester.pumpAndSettle();
    expect(
      container.read(visibleHoldingsProvider).map((h) => h.productName),
      ['纯债基金A'],
    );
    container.read(holdingFilterProvider.notifier).state =
        const HoldingFilterState();
    await tester.pumpAndSettle();
    expectNoExceptions('9 编辑持仓');
    // 编辑对话框关闭后详情抽屉仍在（右侧 400px），点击左侧遮罩关闭，
    // 否则抽屉会遮挡后续导航。
    await tester.tapAt(const Offset(80, 450));
    await tester.pumpAndSettle();

    // ========== 10. 创建两个快照 ==========
    // 快照一：编辑后状态（82388）。
    await gotoPage(3); // 历史快照
    await tester.tap(find.text('新建快照'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '第一次');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    // 快照二之前再编辑一条（异常基金 888 → 1000），使两次快照产生差额。
    await gotoPage(2);
    await tester.tap(holdingRow('异常基金'));
    await tester.pumpAndSettle();
    // 同步骤 9：行点击打开详情抽屉，「编辑」在抽屉内。
    await tester.tap(
      find.descendant(
        of: find.byType(HoldingDetailDrawer),
        matching: find.text('编辑'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      inEditor(find.widgetWithText(TextFormField, '当前金额')),
      '1000.00',
    );
    await tester.ensureVisible(inEditor(find.text('保存')));
    await tester.pumpAndSettle();
    await tester.tap(inEditor(find.text('保存')));
    await tester.pumpAndSettle();
    await waitForToastToClear();
    expect(
      container.read(portfolioSummaryProvider).totalValue.canonical,
      '82500',
    );
    // 关闭详情抽屉再导航。
    await tester.tapAt(const Offset(80, 450));
    await tester.pumpAndSettle();
    await gotoPage(3);
    await tester.tap(find.text('新建快照'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '第二次');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('第一次'), findsOneWidget);
    expect(find.text('第二次'), findsOneWidget);
    final snapshotList = container.read(snapshotsProvider).value;
    expect(snapshotList, hasLength(2));
    final firstTotal = snapshotList!
        .firstWhere((s) => s.label == '第一次')
        .holdings
        .fold(DecimalValue.zero, (a, h) => a + h.currentValue);
    // 快照一冻结在 82388，不被后续编辑影响。
    expect(firstTotal.canonical, '82388');
    expectNoExceptions('10 快照创建');

    // ========== 11. 比较两个快照 ==========
    expect(find.text('资产金额变化'), findsOneWidget);
    final secondTotal = snapshotList
        .firstWhere((s) => s.label == '第二次')
        .holdings
        .fold(DecimalValue.zero, (a, h) => a + h.currentValue);
    expect(secondTotal.canonical, '82500');
    expect(find.textContaining('快照收益'), findsNothing);
    expectNoExceptions('11 快照比较');

    // ========== 12. 刷新行情 ==========
    await gotoPage(5); // 设置与备份
    await tester.scrollUntilVisible(
      find.text('手动刷新行情'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('手动刷新行情'));
    await tester.pumpAndSettle();
    // 成功 1 条（纯债基金A 100 份 × 2.00 = 200）、失败 1 条（异常基金保留原值）。
    // 手动刷新路径不写持久化 lastAttemptUtc，本会话结果由会话内
    // attempt 呈现（修复于 market_settings_section._lastRefreshText）。
    expect(find.textContaining('更新 1 条'), findsOneWidget);
    expect(scenario.quoteCache.quotes, hasLength(1));
    final refreshed = holdings.holdings.singleWhere(
      (h) => h.productName == '纯债基金A',
    );
    expect(refreshed.currentValue.canonical, '200');
    // 失败保留上次有效值，不用零替代。
    final failedHolding = holdings.holdings.singleWhere(
      (h) => h.productName == '异常基金',
    );
    expect(failedHolding.currentValue.canonical, '1000');
    expectNoExceptions('12 行情刷新');

    // ========== 13. 创建加密备份 ==========
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('backup-create-button')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(
      find.byKey(const ValueKey('backup-create-password')),
      '回归测试密码',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('backup-create-confirm')),
      '回归测试密码',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backup-create-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('备份已创建'), findsOneWidget);
    expect(scenario.backupService.calls, hasLength(1));
    expect(
      scenario.backupService.calls.single.destination,
      'C:/out/regression-backup.fundlens-backup',
    );
    expect(scenario.backupService.calls.single.password, '回归测试密码');
    await waitForToastToClear();
    expectNoExceptions('13 加密备份');

    // ========== 14. 恢复备份 ==========
    await tester.enterText(
      find.byKey(const ValueKey('backup-restore-password')),
      '回归测试密码',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backup-restore-button')));
    await tester.pumpAndSettle();
    // 恢复摘要确认对话框。
    expect(find.text('恢复备份'), findsOneWidget);
    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();
    expect(find.text('恢复完成。'), findsOneWidget);
    expect(scenario.restoreService.prepared, hasLength(1));
    expect(scenario.restoreService.confirmed, hasLength(1));
    expectNoExceptions('14 恢复备份');

    // ========== 15. 撤销一次导入 ==========
    await gotoPage(4); // 导入与识别
    await tester.tap(find.text('撤销本次导入'));
    await tester.pumpAndSettle();
    // 撤销最近一次导入：插入行（纯债基金A、异常基金）被删除，
    // 更新行（旧基金）恢复合并前数值 500。
    expect(holdings.holdings, hasLength(1));
    expect(holdings.holdings.single.productName, '旧基金');
    expect(holdings.holdings.single.currentValue.canonical, '500');
    // 历史快照不可变：撤销不影响已保存的两个快照。
    expect(container.read(snapshotsProvider).value, hasLength(2));
    // 撤销后回到来源选择（已选来源的 banner 形态，上传区可直接重选文件）。
    expect(find.text('点击选择或拖拽文件到此处'), findsOneWidget);
    expectNoExceptions('15 撤销导入');

    // 引擎调用记录：仅允许行情获取与重复候选匹配（引擎提议、用户显式
    // 确认），未触发任何其他真实引擎依赖。
    expect(
      engine.calls.where(
        (m) =>
            m != 'market.fetch_quotes' &&
            m != 'product.match_candidates',
      ),
      isEmpty,
      reason: '回归流程不应调用其他引擎方法',
    );
  });

  // ========== 真实加密备份 → 修改 → 恢复链路 ==========
  // 使用真实 sqlite3mc 加密文件库、真实 Argon2id+AES-256-GCM 密码器与真实文件系统。
  testWidgets('真实加密备份 → 修改 → 恢复：数据回到备份点', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('fundlens-backup-e2e-');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final dbFile = File('${tempDir.path}/live.db');
    final keyHex = 'aa' * 32; // 64 位十六进制数据库密钥。
    final db = AppDatabase(openEncryptedDatabase(dbFile, keyHex));
    final lifecycle = DriftDatabaseLifecycle(databaseFile: dbFile, database: db);
    final keyStore = InMemoryDatabaseKeyStore(keyHex);
    final cipher = PointyCastleBackupCipher();
    const files = IoBackupFileSystem();
    final backupService = BackupService(
      databasePath: dbFile.path,
      lifecycle: lifecycle,
      keyStore: keyStore,
      cipher: cipher,
      files: files,
    );
    final restoreService = DatabaseRestoreService(
      databasePath: dbFile.path,
      lifecycle: lifecycle,
      keyStore: keyStore,
      cipher: cipher,
      files: files,
      inspector: const SqliteBackupDatabaseInspector(),
      supportedSchemaVersion: db.schemaVersion,
      recoveryDirectoryPath: '${tempDir.path}/restore-recovery',
    );

    final holdingsRepo = DriftHoldingRepository(db);
    final snapshotsRepo = DriftSnapshotRepository(db);

    // 备份点数据：两条持仓 + 一个快照。
    await holdingsRepo.upsert(
      makeHolding(
        id: 'e2e-a',
        name: '纯债基金A',
        code: '000001',
        quantity: '100',
        amount: '78347.87',
      ),
    );
    await holdingsRepo.upsert(
      makeHolding(id: 'e2e-b', name: '旧基金', amount: '2500'),
    );
    await snapshotsRepo.createFromCurrent(label: '备份点');
    expect(await snapshotsRepo.getAll(), hasLength(1));

    // 创建加密备份并校验容器结构。
    final backupPath = '${tempDir.path}/regression$kFundLensBackupExtension';
    await backupService.create(backupPath, '回归测试密码-2026');
    final bytes = await File(backupPath).readAsBytes();
    expect(
      bytes.sublist(0, kFundLensBackupMagic.length),
      kFundLensBackupMagic,
      reason: '备份容器必须以魔数开头',
    );
    // 明文密码不得出现在密文中（抽查 UTF-8 编码）。
    final passwordBytes = utf8.encode('回归测试密码-2026');
    final plaintextPasswordOccurs = _bytesContains(bytes, passwordBytes);
    expect(plaintextPasswordOccurs, isFalse, reason: '备份不得包含明文密码');

    // 修改：删除一条、新增一条。
    await holdingsRepo.deleteByIds(['e2e-b']);
    await holdingsRepo.upsert(
      makeHolding(id: 'e2e-c', name: '新基金', amount: '5000'),
    );
    final mutated = await holdingsRepo.getAll();
    expect(mutated, hasLength(2));
    expect(mutated.any((h) => h.id == 'e2e-b'), isFalse);

    // 恢复备份：数据回到备份点。
    await restoreService.restore(backupPath, '回归测试密码-2026');
    // 恢复会关闭并重开物理数据库，必须从新的 lifecycle 重建仓库。
    final restoredHoldings = DriftHoldingRepository(
      lifecycle.currentDatabase,
    );
    final restoredSnapshots = DriftSnapshotRepository(
      lifecycle.currentDatabase,
    );
    final all = await restoredHoldings.getAll();
    expect(all, hasLength(2));
    expect(
      all.map((h) => h.id),
      containsAll(['e2e-a', 'e2e-b']),
      reason: '恢复后应回到备份点持仓，修改被回滚',
    );
    expect(all.any((h) => h.id == 'e2e-c'), isFalse);
    final restoredTotal = all.fold(
      DecimalValue.zero,
      (acc, h) => acc + h.currentValue,
    );
    expect(restoredTotal.canonical, '80847.87');
    expect(await restoredSnapshots.getAll(), hasLength(1));

    // 错误密码必须被拒绝，且不破坏现有数据。
    await expectLater(
      restoreService.restore(backupPath, '错误密码'),
      throwsA(isA<BackupAuthenticationException>()),
    );
    final afterWrongPassword = await restoredHoldings.getAll();
    expect(afterWrongPassword, hasLength(2));
    expect(
      afterWrongPassword.map((h) => h.id),
      containsAll(['e2e-a', 'e2e-b']),
    );

    await lifecycle.currentDatabase.close();
  });

  // ========== 四种窗口尺寸布局验证（阶段 3） ==========
  const layoutSizes = [
    Size(1920, 1080),
    Size(1440, 900),
    Size(1366, 768),
    Size(1280, 720),
  ];

  for (final size in layoutSizes) {
    testWidgets('布局无溢出 $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final initial = [
        makeHolding(
          id: 'l1',
          name: '纯债基金A',
          code: '000001',
          quantity: '100',
          amount: '78347.87',
          assetClass: AssetClass.fixedIncome,
        ),
        makeHolding(
          id: 'l2',
          name: '旧基金',
          amount: '2500',
          assetClass: AssetClass.equity,
        ),
        makeHolding(
          id: 'l3',
          name: '异常基金',
          code: '000003',
          quantity: '10',
          amount: '888',
        ),
      ];
      final scenario = buildScenario(initialHoldings: initial);
      await tester.pumpWidget(scenario.scope);
      await tester.pumpAndSettle();

      for (final label in navLabels) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: '页面「$label」在 $size 出现布局溢出或异常: $error',
        );
      }
    });
  }
}

/// 判断 [haystack] 是否包含 [needle] 子序列。
bool _bytesContains(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
