import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_filters.dart';
import 'package:fundlens_windows/features/holdings/holding_toolbar.dart';
import 'package:fundlens_windows/theme/fundlens_theme.dart';

Widget harness(Widget child) {
  return MaterialApp(
    theme: FundLensTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('filterButtonSummary', () {
    test('未选中显示完整标签', () {
      expect(
        filterButtonSummary(label: '资产类别', shortLabel: '类别', selectedLabels: const []),
        '资产类别',
      );
    });
    test('选中 1 项显示短标签与值', () {
      expect(
        filterButtonSummary(label: '资产类别', shortLabel: '类别', selectedLabels: const ['权益']),
        '类别:权益',
      );
    });
    test('选中多项显示首值加计数', () {
      expect(
        filterButtonSummary(label: '资产类别', shortLabel: '类别', selectedLabels: const ['权益', '固收']),
        '类别:权益+1',
      );
    });
  });

  group('toggled', () {
    test('添加与移除', () {
      expect(toggled(<String>{}, 'a'), {'a'});
      expect(toggled(<String>{'a'}, 'a'), <String>{});
      expect(toggled(<String>{'a', 'b'}, 'a'), {'b'});
    });
  });

  group('HoldingFilterDropdown', () {
    testWidgets('未选中显示标签,点击条目触发 onToggled 且菜单保持打开', (tester) async {
      String? toggledValue;
      await tester.pumpWidget(harness(
        HoldingFilterDropdown<AssetClass>(
          label: '资产类别',
          shortLabel: '类别',
          options: const [(AssetClass.equity, '权益'), (AssetClass.gold, '黄金')],
          selected: const {},
          onToggled: (v) => toggledValue = v.name,
        ),
      ));
      expect(find.text('资产类别'), findsOneWidget);

      await tester.tap(find.text('资产类别'));
      await tester.pumpAndSettle();
      expect(find.text('权益'), findsOneWidget);

      await tester.tap(find.text('权益'));
      await tester.pump();
      expect(toggledValue, 'equity');
      // 多选菜单点击后不自动关闭。
      expect(find.text('黄金'), findsOneWidget);
    });

    testWidgets('选中态显示摘要文本', (tester) async {
      await tester.pumpWidget(harness(
        HoldingFilterDropdown<AssetClass>(
          label: '资产类别',
          shortLabel: '类别',
          options: const [(AssetClass.equity, '权益'), (AssetClass.gold, '黄金')],
          selected: const {AssetClass.equity, AssetClass.gold},
          onToggled: (_) {},
        ),
      ));
      expect(find.text('类别:权益+1'), findsOneWidget);
    });
  });

  group('HoldingSortMenu', () {
    testWidgets('按钮显示当前排序,菜单选择触发 onSelected', (tester) async {
      // 18 项菜单高约 864,默认 800×600 视口放不下,使用项目重点验证分辨率。
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      HoldingSort? chosen;
      await tester.pumpWidget(harness(
        HoldingSortMenu(
          sort: HoldingSort.initial,
          onSelected: (s) => chosen = s,
        ),
      ));
      expect(find.text('当前金额 · 从高到低'), findsOneWidget);

      await tester.tap(find.text('当前金额 · 从高到低'));
      await tester.pumpAndSettle();
      // 9 字段 × 2 方向 = 18 项。
      expect(find.text('持仓盈亏 · 从低到高'), findsOneWidget);
      await tester.tap(find.text('持仓盈亏 · 从低到高'));
      await tester.pumpAndSettle();
      expect(chosen?.field, HoldingSortField.profit);
      expect(chosen?.ascending, isTrue);
    });
  });

  group('HoldingSearchField', () {
    testWidgets('输入触发 onChanged;外部 query 清空时输入框同步', (tester) async {
      var query = '';
      late StateSetter rebuild;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return harness(
              HoldingSearchField(query: query, onChanged: (v) => query = v),
            );
          },
        ),
      );
      await tester.enterText(find.byType(TextField), '沪深');
      expect(query, '沪深');

      // 外部状态清空(清除筛选) → 输入框文本同步清空。
      rebuild(() => query = '');
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '');
    });
  });
}
