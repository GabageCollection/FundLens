import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/importing/import_planner.dart';

Holding _existing({
  String id = 'existing',
  SourcePlatform platform = SourcePlatform.alipay,
  String productCode = '000001',
  String productName = '脱敏基金A',
  String currentValue = '1000',
  String? quantity,
  String? holdingProfit,
  String? costAmount,
}) =>
    Holding(
      id: id,
      sourcePlatform: platform,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.fixedIncome,
      productName: productName,
      productCode: productCode,
      currency: 'CNY',
      currentValue: DecimalValue.parse(currentValue),
      quantity: quantity == null ? null : DecimalValue.parse(quantity),
      holdingProfit: holdingProfit == null
          ? null
          : DecimalValue.parse(holdingProfit),
      costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: DataOrigin.manual,
      fieldProvenance: const {},
      createdAt: DateTime.utc(2026, 7, 19),
      updatedAt: DateTime.utc(2026, 7, 19),
    );

DraftHolding _incoming({
  String? productCode = '000001',
  String productName = '脱敏基金A',
  String currentValue = '500',
  String? quantity,
  String? holdingProfit,
  String? costAmount,
  SourcePlatform sourcePlatform = SourcePlatform.alipay,
}) =>
    DraftHolding(
      sourcePlatform: sourcePlatform,
      productName: productName,
      productCode: productCode,
      instrumentType: InstrumentType.offExchangeFund,
      assetClass: AssetClass.fixedIncome,
      currentValue: DecimalValue.parse(currentValue),
      quantity: quantity == null ? null : DecimalValue.parse(quantity),
      holdingProfit: holdingProfit == null
          ? null
          : DecimalValue.parse(holdingProfit),
      costAmount: costAmount == null ? null : DecimalValue.parse(costAmount),
      dataOrigin: DataOrigin.csv,
    );

void main() {
  late ImportPlanner planner;

  setUp(() {
    planner = ImportPlanner(
      idGenerator: () => 'generated-0',
      clock: () => DateTime.utc(2026, 7, 21),
    );
  });

  test('无 resolution 时重复行默认覆盖更新(保持既有行为)', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [_existing(currentValue: '1000')],
      incoming: [_incoming(currentValue: '500')],
    );
    expect(plan.updates.single.currentValue.canonical, '500');
    expect(plan.skipped, isEmpty);
  });

  test('overwrite 覆盖匹配行的全部金额', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [_existing(currentValue: '1000')],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.overwrite},
    );
    expect(plan.updates.single.currentValue.canonical, '500');
    expect(plan.skipped, isEmpty);
  });

  test('merge 把金额与份额合并到现有行', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [
        _existing(
          currentValue: '1000',
          quantity: '100',
          holdingProfit: '50',
          costAmount: '950',
        ),
      ],
      incoming: [
        _incoming(
          currentValue: '500',
          quantity: '50',
          holdingProfit: '10',
          costAmount: '490',
        ),
      ],
      resolutions: {0: DuplicateResolution.merge},
    );
    final update = plan.updates.single;
    expect(update.id, 'existing');
    expect(update.currentValue.canonical, '1500');
    expect(update.quantity?.canonical, '150');
    expect(update.holdingProfit?.canonical, '60');
    expect(update.costAmount?.canonical, '1440');
  });

  test('merge 对 null 字段按原值保留', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [_existing(currentValue: '1000')],
      incoming: [_incoming(currentValue: '500', holdingProfit: '10')],
      resolutions: {0: DuplicateResolution.merge},
    );
    final update = plan.updates.single;
    expect(update.currentValue.canonical, '1500');
    expect(update.holdingProfit?.canonical, '10');
    expect(update.quantity, isNull);
  });

  test('显式 merge 决议允许跨平台同名合并(与检查面板疑似重复一致)', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [
        _existing(platform: SourcePlatform.manual, currentValue: '1000'),
      ],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.merge},
    );
    final update = plan.updates.single;
    expect(update.id, 'existing');
    expect(update.currentValue.canonical, '1500');
    expect(plan.inserts, isEmpty);
  });

  test('显式 overwrite 决议允许跨平台同名覆盖', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [
        _existing(platform: SourcePlatform.manual, currentValue: '1000'),
      ],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.overwrite},
    );
    final update = plan.updates.single;
    expect(update.id, 'existing');
    expect(update.currentValue.canonical, '500');
    expect(plan.inserts, isEmpty);
  });

  test('keepBoth 即使匹配也作为新行插入,现有行保持不变', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [_existing(currentValue: '1000')],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.keepBoth},
    );
    expect(plan.updates, isEmpty);
    expect(plan.inserts.single.currentValue.canonical, '500');
    expect(plan.inserts.single.id, isNot('existing'));
    expect(plan.unchangedIds, contains('existing'));
  });

  test('skip 跳过该行,不新增不更新不删除,计入 skipped', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [_existing(currentValue: '1000')],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.skip},
    );
    expect(plan.updates, isEmpty);
    expect(plan.inserts, isEmpty);
    expect(plan.removeIds, isEmpty);
    expect(plan.skipped, hasLength(1));
    expect(plan.skipped.single.productName, '脱敏基金A');
  });

  test('skip 的新行不进入任何写入集合', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: const [],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.skip},
    );
    expect(plan.inserts, isEmpty);
    expect(plan.updates, isEmpty);
    expect(plan.skipped, hasLength(1));
  });

  test('merge 的未匹配新行退化为普通插入', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: const [],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.merge},
    );
    expect(plan.inserts, hasLength(1));
    expect(plan.updates, isEmpty);
  });

  test('keepBoth 的未匹配新行仍为普通插入', () {
    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: const [],
      incoming: [_incoming(currentValue: '500')],
      resolutions: {0: DuplicateResolution.keepBoth},
    );
    expect(plan.inserts, hasLength(1));
  });
}
