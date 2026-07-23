import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/application/app_dependencies.dart';
import 'package:fundlens_windows/features/snapshots/snapshot_deletion.dart';
import 'package:fundlens_windows/features/snapshots/snapshots_page.dart';
import 'package:fundlens_windows/storage/snapshot_repository.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

final class FakeSnapshotRepository implements SnapshotRepository {
  FakeSnapshotRepository(this.snapshots);

  final List<PortfolioSnapshot> snapshots;
  String? lastCreatedLabel;

  @override
  Future<List<PortfolioSnapshot>> getAll() async => snapshots;

  @override
  Future<PortfolioSnapshot> getById(String id) async =>
      snapshots.firstWhere((s) => s.id == id);

  @override
  Future<String> createFromCurrent({required String label}) async {
    lastCreatedLabel = label;
    snapshots.add(PortfolioSnapshot(
      id: 's-created',
      label: label,
      createdAt: DateTime.utc(2026, 7, 20),
      holdings: const [],
    ));
    return 's-created';
  }

  @override
  Future<void> deleteById(String id) async {
    snapshots.removeWhere((s) => s.id == id);
  }
}

SnapshotHolding snapshotHolding({
  required String holdingId,
  required String productName,
  required String currentValue,
}) {
  return SnapshotHolding(
    holdingId: holdingId,
    productName: productName,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    sourcePlatform: SourcePlatform.alipay,
    currentValue: DecimalValue.parse(currentValue),
    fieldProvenance: const {},
  );
}

PortfolioSnapshot snapshotJune() => PortfolioSnapshot(
      id: 's-june',
      label: '六月末',
      createdAt: DateTime.utc(2026, 6, 30),
      holdings: [
        snapshotHolding(
          holdingId: 'h-1',
          productName: '基金甲',
          currentValue: '1000.00',
        ),
      ],
    );

PortfolioSnapshot snapshotJuly() => PortfolioSnapshot(
      id: 's-july',
      label: '七月中',
      createdAt: DateTime.utc(2026, 7, 15),
      holdings: [
        snapshotHolding(
          holdingId: 'h-2',
          productName: '基金乙',
          currentValue: '2000.00',
        ),
      ],
    );

Widget snapshotHarness({
  required FakeSnapshotRepository repository,
  Future<void> Function(String id)? onDelete,
}) {
  return ProviderScope(
    overrides: [
      snapshotRepositoryProvider.overrideWithValue(repository),
      if (onDelete != null) snapshotDeletionProvider.overrideWithValue(onDelete),
    ],
    child: MaterialApp(
      theme: FundLensTheme.light,
      home: const SnapshotsPage(),
    ),
  );
}

void main() {
  testWidgets('snapshot comparison labels the delta as amount change',
      (tester) async {
    final repository = FakeSnapshotRepository([snapshotJune(), snapshotJuly()]);
    await tester.pumpWidget(snapshotHarness(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('资产金额变化'), findsOneWidget);
    expect(find.textContaining('快照收益'), findsNothing);
  });

  testWidgets('comparison is disabled with fewer than two snapshots',
      (tester) async {
    final repository = FakeSnapshotRepository([snapshotJune()]);
    await tester.pumpWidget(snapshotHarness(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('至少需要两个快照才能比较'), findsOneWidget);
    expect(find.text('资产金额变化'), findsNothing);
  });

  testWidgets('added and removed holdings carry badges', (tester) async {
    final repository = FakeSnapshotRepository([snapshotJune(), snapshotJuly()]);
    await tester.pumpWidget(snapshotHarness(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('新增'), findsOneWidget);
    expect(find.text('移除'), findsOneWidget);
    expect(find.text('基金甲'), findsOneWidget);
    expect(find.text('基金乙'), findsOneWidget);
    expect(find.text('+1,000.00'), findsWidgets);
  });

  testWidgets('creating a snapshot asks for a label first', (tester) async {
    final repository = FakeSnapshotRepository([snapshotJune(), snapshotJuly()]);
    await tester.pumpWidget(snapshotHarness(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新建快照'));
    await tester.pumpAndSettle();
    expect(find.text('快照标签'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '七月末');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(repository.lastCreatedLabel, '七月末');
    expect(find.text('七月末'), findsOneWidget);
  });

  testWidgets('deletion names the date and label and requires confirmation',
      (tester) async {
    final repository = FakeSnapshotRepository([snapshotJune(), snapshotJuly()]);
    final deleted = <String>[];
    await tester.pumpWidget(snapshotHarness(
      repository: repository,
      onDelete: (id) async => deleted.add(id),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('七月中'), findsWidgets);
    expect(find.textContaining('2026-07-15'), findsWidgets);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(deleted, ['s-july']);
  });
}
