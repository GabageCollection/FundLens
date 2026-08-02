import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/importing/import_commit_service.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/storage/app_database.dart';
import 'package:fundlens_windows/storage/holding_repository.dart';

Holding _holding(String id, SourcePlatform platform, String value) => Holding(
  id: id,
  sourcePlatform: platform,
  instrumentType: InstrumentType.offExchangeFund,
  assetClass: AssetClass.fixedIncome,
  productName: '脱敏基金$id',
  currency: 'CNY',
  currentValue: DecimalValue.parse(value),
  valuationMethod: ValuationMethod.manualAmount,
  dataOrigin: DataOrigin.csv,
  fieldProvenance: const {},
  createdAt: DateTime.utc(2026, 7, 19),
  updatedAt: DateTime.utc(2026, 7, 21),
);

DraftHolding _skipped(String name) => DraftHolding(
  sourcePlatform: SourcePlatform.alipay,
  productName: name,
  instrumentType: InstrumentType.offExchangeFund,
  assetClass: AssetClass.fixedIncome,
  currentValue: DecimalValue.parse('1'),
  dataOrigin: DataOrigin.csv,
);

void main() {
  late AppDatabase db;
  late HoldingRepository repo;
  late ImportCommitService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftHoldingRepository(db);
    service = ImportCommitService(repo);
  });

  tearDown(() => db.close());

  Future<Map<String, Holding>> allById() async => {
    for (final h in await repo.getAll()) h.id: h,
  };

  test('commit 返回记录:插入/更新/移除/跳过计数', () async {
    await repo.upsert(_holding('update-me', SourcePlatform.alipay, '300'));
    final plan = ImportPlan(
      inserts: [_holding('new-1', SourcePlatform.alipay, '900')],
      updates: [_holding('update-me', SourcePlatform.alipay, '999')],
      removeIds: const [],
      unchangedIds: const [],
      issues: const [],
      skipped: [_skipped('被跳过基金')],
    );

    final record = await service.commit(plan);

    expect(record.inserted, 1);
    expect(record.updated, 1);
    expect(record.removed, 0);
    expect(record.skippedCount, 1);
    expect(record.insertedHoldings.single.id, 'new-1');
    expect(record.previousUpdates.keys, contains('update-me'));
    expect(record.previousUpdates['update-me']!.currentValue.canonical, '300');
  });

  test('undo 删除插入、恢复更新前的原值', () async {
    await repo.upsert(_holding('update-me', SourcePlatform.alipay, '300'));
    final plan = ImportPlan(
      inserts: [_holding('new-1', SourcePlatform.alipay, '900')],
      updates: [_holding('update-me', SourcePlatform.alipay, '999')],
      removeIds: const [],
      unchangedIds: const [],
      issues: const [],
    );
    final record = await service.commit(plan);
    expect((await allById()).containsKey('new-1'), isTrue);

    await service.undo(record);

    final after = await allById();
    expect(after.containsKey('new-1'), isFalse);
    expect(after['update-me']!.currentValue.canonical, '300');
  });

  test('undo 恢复被移除的持仓', () async {
    await repo.upsert(_holding('remove-me', SourcePlatform.alipay, '200'));
    final plan = ImportPlan(
      inserts: const [],
      updates: const [],
      removeIds: const ['remove-me'],
      unchangedIds: const [],
      issues: const [],
    );
    final record = await service.commit(plan);
    expect((await allById()).containsKey('remove-me'), isFalse);

    await service.undo(record);

    expect((await allById())['remove-me']!.currentValue.canonical, '200');
  });

  test('undo 组合场景:插入+更新+删除一起撤销', () async {
    await repo.upsert(_holding('update-me', SourcePlatform.alipay, '300'));
    await repo.upsert(_holding('remove-me', SourcePlatform.alipay, '200'));
    final plan = ImportPlan(
      inserts: [_holding('new-1', SourcePlatform.alipay, '900')],
      updates: [_holding('update-me', SourcePlatform.alipay, '999')],
      removeIds: const ['remove-me'],
      unchangedIds: const [],
      issues: const [],
    );
    final record = await service.commit(plan);
    expect((await allById()).keys, containsAll(['new-1', 'update-me']));

    await service.undo(record);

    final after = await allById();
    expect(after.keys, isNot(contains('new-1')));
    expect(after['update-me']!.currentValue.canonical, '300');
    expect(after['remove-me']!.currentValue.canonical, '200');
  });
}
