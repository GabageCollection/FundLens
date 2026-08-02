import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/importing/tabular_import_parser.dart';

void main() {
  const parser = TabularImportParser();

  group('TabularImportParser 两阶段解析', () {
    test('parseCsvTable 返回表头与数据行并去除尾部空行', () {
      final table = parser.parseCsvTable('产品名称,当前金额\n基金A,100\n,\n');
      expect(table.headings, ['产品名称', '当前金额']);
      expect(table.dataRows, hasLength(1));
      expect(table.dataRows.single, ['基金A', '100']);
    });

    test('guessColumnMapping 按中英文别名猜测,未知字段为 null', () {
      final mapping = parser.guessColumnMapping(
        ['基金代码', '产品名称', '市值', '份额', '渠道备注'],
      );
      expect(mapping['productCode'], 0);
      expect(mapping['productName'], 1);
      expect(mapping['currentValue'], 2);
      expect(mapping['quantity'], 3);
      expect(mapping['costPrice'], isNull);
    });

    test('parseTable 按用户确认的映射解析,等价于自动识别结果', () {
      final table = parser.parseCsvTable(
        '产品名称,当前金额,持有收益\n基金A,100,5\n',
      );
      final mapping = parser.guessColumnMapping(table.headings);
      final draft = parser.parseTable(
        table,
        mapping,
        origin: DataOrigin.csv,
      );
      expect(draft.issues, isEmpty);
      final holding = draft.holdings.single;
      expect(holding.productName, '基金A');
      expect(holding.currentValue.canonical, '100');
      expect(holding.holdingProfit?.canonical, '5');
    });

    test('无法识别的必填字段缺失时给出阻断问题', () {
      final table = parser.parseCsvTable('基金名,市值金额\n基金A,100\n');
      final mapping = parser.guessColumnMapping(table.headings);
      expect(mapping['productName'], isNull);
      final draft = parser.parseTable(
        table,
        mapping,
        origin: DataOrigin.csv,
      );
      expect(draft.holdings, isEmpty);
      expect(
        draft.issues.any(
          (i) =>
              i.code == 'import.missing_column' &&
              i.severity == IssueSeverity.blocking,
        ),
        isTrue,
      );
    });

    test('用户手工选择映射后可解析别名之外的表头', () {
      final table = parser.parseCsvTable('基金名,市值金额\n基金A,100\n');
      final draft = parser.parseTable(
        table,
        {'productName': 0, 'currentValue': 1},
        origin: DataOrigin.csv,
      );
      expect(draft.issues, isEmpty);
      expect(draft.holdings.single.productName, '基金A');
      expect(draft.holdings.single.currentValue.canonical, '100');
    });

    test('两个字段映射到同一列给出阻断问题', () {
      final table = parser.parseCsvTable('产品名称,当前金额\n基金A,100\n');
      final draft = parser.parseTable(
        table,
        {'productName': 0, 'currentValue': 0},
        origin: DataOrigin.csv,
      );
      expect(draft.holdings, isEmpty);
      expect(
        draft.issues.single.code,
        'import.duplicate_mapping',
      );
      expect(draft.issues.single.severity, IssueSeverity.blocking);
    });

    test('未映射的列保留在 metadata 中', () {
      final table = parser.parseCsvTable(
        '产品名称,当前金额,渠道备注\n基金A,100,客户经理赠送\n',
      );
      final draft = parser.parseTable(
        table,
        {'productName': 0, 'currentValue': 1},
        origin: DataOrigin.csv,
      );
      expect(
        draft.holdings.single.metadata,
        containsPair('渠道备注', '客户经理赠送'),
      );
    });

    test('parseExcelTable 读取首个非空工作表', () {
      final excel = Excel.createExcel();
      final sheet = excel['持仓'];
      sheet.appendRow([TextCellValue('产品名称'), TextCellValue('当前金额')]);
      sheet.appendRow([TextCellValue('基金A'), TextCellValue('100')]);
      final table = parser.parseExcelTable(excel.encode()!);
      expect(table.headings, ['产品名称', '当前金额']);
      expect(table.dataRows.single, ['基金A', '100']);
    });

    test('parseExcelTable 损坏字节抛出 FormatException', () {
      expect(
        () => parser.parseExcelTable(utf8.encode('not an xlsx')),
        throwsFormatException,
      );
    });
  });
}
