import 'package:fundlens_core/fundlens_core.dart';
import 'package:test/test.dart';

SnapshotHolding _sh(
  String id,
  String value, {
  AssetClass assetClass = AssetClass.equity,
  InstrumentType instrumentType = InstrumentType.stock,
  SourcePlatform sourcePlatform = SourcePlatform.manual,
}) => SnapshotHolding(
  holdingId: id,
  productName: id,
  instrumentType: instrumentType,
  assetClass: assetClass,
  sourcePlatform: sourcePlatform,
  currentValue: DecimalValue.parse(value),
  fieldProvenance: const {},
);

PortfolioSnapshot _snapshot(
  String id,
  List<SnapshotHolding> holdings, {
  DateTime? createdAt,
}) => PortfolioSnapshot(
  id: id,
  label: id,
  createdAt: createdAt ?? DateTime.utc(2026, 7, 19),
  holdings: holdings,
);

PortfolioSnapshot _fixture(String id, String value) =>
    _snapshot(id, [_sh('${id}_h', value)]);

void main() {
  test('comparison reports amount change without return language', () {
    final before = _fixture('s1', '100');
    final after = _fixture('s2', '125');
    final diff = SnapshotDiffService().compare(before, after);
    expect(diff.totalAmountChange.canonical, '25');
    expect(diff.metricLabel, '资产金额变化');
  });

  test('added holding reports positive amount change', () {
    final before = _snapshot('before', [_sh('a', '100')]);
    final after = _snapshot('after', [_sh('a', '100'), _sh('b', '50')]);
    final diff = SnapshotDiffService().compare(before, after);
    expect(diff.totalAmountChange.canonical, '50');
    expect(diff.holdingAmountChanges['a']?.canonical, '0');
    expect(diff.holdingAmountChanges['b']?.canonical, '50');
  });

  test('removed holding reports negative amount change', () {
    final before = _snapshot('before', [_sh('a', '100')]);
    final after = _snapshot('after', []);
    final diff = SnapshotDiffService().compare(before, after);
    expect(diff.totalAmountChange.canonical, '-100');
    expect(diff.holdingAmountChanges['a']?.canonical, '-100');
  });

  test('reclassified holding shifts amount between asset classes', () {
    final before = _snapshot('before', [
      _sh('a', '100', assetClass: AssetClass.equity),
    ]);
    final after = _snapshot('after', [
      _sh('a', '100', assetClass: AssetClass.fixedIncome),
    ]);
    final diff = SnapshotDiffService().compare(before, after);
    expect(diff.totalAmountChange.canonical, '0');
    expect(diff.holdingAmountChanges['a']?.canonical, '0');
    expect(diff.assetClassAmountChanges[AssetClass.equity]?.canonical, '-100');
    expect(
      diff.assetClassAmountChanges[AssetClass.fixedIncome]?.canonical,
      '100',
    );
  });
}
