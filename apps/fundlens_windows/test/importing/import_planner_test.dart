import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/importing/import_planner.dart';

Holding _holding(
  String id,
  SourcePlatform platform, {
  String? productCode,
  String productName = '产品',
  InstrumentType instrumentType = InstrumentType.offExchangeFund,
  String currentValue = '1000',
}) =>
    Holding(
      id: id,
      sourcePlatform: platform,
      instrumentType: instrumentType,
      assetClass: AssetClass.fixedIncome,
      productName: productName,
      productCode: productCode,
      currency: 'CNY',
      currentValue: DecimalValue.parse(currentValue),
      valuationMethod: ValuationMethod.manualAmount,
      dataOrigin: DataOrigin.manual,
      fieldProvenance: const {},
      createdAt: DateTime.utc(2026, 7, 19),
      updatedAt: DateTime.utc(2026, 7, 19),
    );

DraftHolding _draft({
  String? productCode,
  String productName = '产品',
  InstrumentType instrumentType = InstrumentType.offExchangeFund,
  String currentValue = '1000',
  SourcePlatform sourcePlatform = SourcePlatform.alipay,
}) =>
    DraftHolding(
      sourcePlatform: sourcePlatform,
      productName: productName,
      productCode: productCode,
      instrumentType: instrumentType,
      assetClass: AssetClass.fixedIncome,
      currentValue: DecimalValue.parse(currentValue),
      dataOrigin: DataOrigin.csv,
    );

void main() {
  var nextId = 0;
  late ImportPlanner planner;

  setUp(() {
    nextId = 0;
    planner = ImportPlanner(
      idGenerator: () => 'generated-${nextId++}',
      clock: () => DateTime.utc(2026, 7, 21),
    );
  });

  test('full import proposes removals only for the same platform', () {
    final alipayOld = _holding(
      'alipay-old',
      SourcePlatform.alipay,
      productName: '已下架基金',
    );
    final thsOld = _holding('ths-old', SourcePlatform.ths);
    final manualOld = _holding('manual-old', SourcePlatform.manual);
    final alipayNew = _draft();

    final plan = planner.plan(
      mode: ImportMode.full,
      platform: SourcePlatform.alipay,
      current: [alipayOld, thsOld, manualOld],
      incoming: [alipayNew],
    );

    expect(plan.canCommit, isTrue);
    expect(plan.removeIds, [alipayOld.id]);
    expect(plan.unchangedIds, containsAll([thsOld.id, manualOld.id]));
    expect(plan.inserts.single.productName, '产品');
    expect(plan.inserts.single.id, 'generated-0');
  });

  test('partial mode never proposes removals', () {
    final alipayOld = _holding('alipay-old', SourcePlatform.alipay);

    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [alipayOld],
      incoming: const [],
    );

    expect(plan.removeIds, isEmpty);
    expect(plan.unchangedIds, contains(alipayOld.id));
  });

  test('same platform exact product code wins over name matching', () {
    final byCode = _holding(
      'by-code',
      SourcePlatform.alipay,
      productCode: '000001',
      productName: '旧名字',
    );
    final byName = _holding(
      'by-name',
      SourcePlatform.alipay,
      productName: '脱敏基金A',
    );

    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [byCode, byName],
      incoming: [
        _draft(productCode: '000001', productName: '脱敏基金A'),
      ],
    );

    expect(plan.canCommit, isTrue);
    expect(plan.inserts, isEmpty);
    expect(plan.updates.single.id, 'by-code');
    expect(plan.unchangedIds, contains('by-name'));
  });

  test('code match on a different platform does not match', () {
    final thsHolding = _holding(
      'ths-1',
      SourcePlatform.ths,
      productCode: '000001',
    );

    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [thsHolding],
      incoming: [_draft(productCode: '000001')],
    );

    expect(plan.inserts, hasLength(1));
    expect(plan.updates, isEmpty);
    expect(plan.unchangedIds, contains('ths-1'));
  });

  test('normalized name plus instrument type matches without code', () {
    final existing = _holding(
      'existing',
      SourcePlatform.alipay,
      productName: '脱敏 基金Ａ（Ａ类）',
    );

    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [existing],
      incoming: [_draft(productName: '脱敏 基金Ａ（Ａ类）')],
    );

    expect(plan.updates.single.id, 'existing');
    expect(plan.inserts, isEmpty);
  });

  test('name match with different instrument type inserts instead', () {
    final existing = _holding(
      'existing',
      SourcePlatform.alipay,
      productName: '脱敏基金A',
      instrumentType: InstrumentType.etf,
    );

    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [existing],
      incoming: [
        _draft(
          productName: '脱敏基金A',
          instrumentType: InstrumentType.offExchangeFund,
        ),
      ],
    );

    expect(plan.inserts, hasLength(1));
    expect(plan.updates, isEmpty);
  });

  test('name-only ambiguity creates a blocking issue', () {
    final a = _holding(
      'a',
      SourcePlatform.alipay,
      productName: '脱敏基金A',
      instrumentType: InstrumentType.etf,
    );
    final b = _holding(
      'b',
      SourcePlatform.alipay,
      productName: '脱敏基金A',
      instrumentType: InstrumentType.lof,
    );

    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [a, b],
      incoming: [_draft(productName: '脱敏基金A')],
    );

    expect(plan.canCommit, isFalse);
    expect(
      plan.issues.any(
        (i) =>
            i.code == 'import.ambiguous_name' &&
            i.severity == IssueSeverity.blocking,
      ),
      isTrue,
    );
    expect(plan.inserts, isEmpty);
    expect(plan.updates, isEmpty);
  });

  test('updates keep the existing id and refresh the imported values', () {
    final existing = _holding(
      'existing',
      SourcePlatform.alipay,
      productCode: '000001',
      currentValue: '5000',
    );

    final plan = planner.plan(
      platform: SourcePlatform.alipay,
      current: [existing],
      incoming: [
        _draft(productCode: '000001', currentValue: '9000'),
      ],
    );

    final update = plan.updates.single;
    expect(update.id, 'existing');
    expect(update.currentValue.canonical, '9000');
    expect(update.createdAt, existing.createdAt);
    expect(update.updatedAt, DateTime.utc(2026, 7, 21));
  });
}
