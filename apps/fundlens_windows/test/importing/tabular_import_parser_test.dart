import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/importing/import_models.dart';
import 'package:fundlens_windows/importing/tabular_import_parser.dart';

void main() {
  const parser = TabularImportParser();

  group('TabularImportParser CSV', () {
    test('CSV parser maps decimals and preserves platform tags', () {
      final draft = parser.parseCsv(
        'source_platform,product_name,current_value,holding_profit,platform_tags\n'
        '支付宝,脱敏纯债基金A,78347.87,428.96,基金|稳健理财',
      );
      expect(draft.issues, isEmpty);
      expect(draft.holdings.single.currentValue.canonical, '78347.87');
      expect(draft.holdings.single.platformTags, ['基金', '稳健理财']);
      expect(draft.holdings.single.sourcePlatform, SourcePlatform.alipay);
      expect(draft.holdings.single.dataOrigin, DataOrigin.csv);
    });

    test('accepts Chinese headings and thousands separators without double', () {
      final draft = parser.parseCsv(
        '来源平台,产品名称,产品代码,当前金额,持有收益,累计收益\n'
        '支付宝,脱敏纯债基金A,000001,"78,347.87",+428.96,"1,888.88"',
      );
      expect(draft.issues, isEmpty);
      final holding = draft.holdings.single;
      expect(holding.currentValue.canonical, '78347.87');
      expect(holding.holdingProfit?.canonical, '428.96');
      expect(holding.cumulativeProfit?.canonical, '1888.88');
      expect(holding.productCode, '000001');
    });

    test('rejects duplicate columns with a blocking issue', () {
      final draft = parser.parseCsv(
        '产品名称,产品名称,当前金额\n'
        '脱敏基金A,脱敏基金B,100',
      );
      expect(draft.holdings, isEmpty);
      expect(
        draft.issues.single.code,
        'import.duplicate_column',
      );
      expect(draft.issues.single.severity, IssueSeverity.blocking);
    });

    test('preserves unknown columns in draft metadata', () {
      final draft = parser.parseCsv(
        '产品名称,当前金额,渠道备注\n'
        '脱敏基金A,100,客户经理赠送',
      );
      expect(draft.issues, isEmpty);
      expect(
        draft.holdings.single.metadata,
        containsPair('渠道备注', '客户经理赠送'),
      );
    });

    test('missing product name creates a blocking issue', () {
      final draft = parser.parseCsv(
        '产品名称,当前金额\n'
        ',100',
      );
      expect(draft.holdings, isEmpty);
      final issue = draft.issues.single;
      expect(issue.code, 'import.missing_product_name');
      expect(issue.severity, IssueSeverity.blocking);
      expect(issue.holdingIndex, 0);
    });

    test('missing current value creates a blocking issue', () {
      final draft = parser.parseCsv(
        '产品名称,当前金额\n'
        '脱敏基金A,',
      );
      expect(draft.holdings, isEmpty);
      final issue = draft.issues.single;
      expect(issue.code, 'import.missing_current_value');
      expect(issue.severity, IssueSeverity.blocking);
    });

    test('negative current value creates a blocking sign issue', () {
      final draft = parser.parseCsv(
        '产品名称,当前金额\n'
        '脱敏基金A,-100',
      );
      expect(draft.holdings, isEmpty);
      final issue = draft.issues.single;
      expect(issue.code, 'import.invalid_sign');
      expect(issue.severity, IssueSeverity.blocking);
    });

    test('unparseable amount creates a blocking issue without double fallback', () {
      final draft = parser.parseCsv(
        '产品名称,当前金额\n'
        '脱敏基金A,abc',
      );
      expect(draft.holdings, isEmpty);
      expect(
        draft.issues.single.severity,
        IssueSeverity.blocking,
      );
    });

    test('missing required heading creates a blocking issue', () {
      final draft = parser.parseCsv('产品名称,持有收益\n脱敏基金A,10');
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
  });

  group('TabularImportParser Excel', () {
    test('parses an xlsx sheet with Chinese headings', () {
      final excel = Excel.createExcel();
      final sheet = excel['持仓'];
      sheet.appendRow([
        TextCellValue('来源平台'),
        TextCellValue('产品名称'),
        TextCellValue('当前金额'),
        TextCellValue('持有收益'),
      ]);
      sheet.appendRow([
        TextCellValue('同花顺'),
        TextCellValue('脱敏沪深300ETF'),
        TextCellValue('78,347.87'),
        TextCellValue('+428.96'),
      ]);
      final bytes = excel.encode()!;

      final draft = parser.parseExcel(bytes);

      expect(draft.issues, isEmpty);
      final holding = draft.holdings.single;
      expect(holding.sourcePlatform, SourcePlatform.ths);
      expect(holding.productName, '脱敏沪深300ETF');
      expect(holding.currentValue.canonical, '78347.87');
      expect(holding.holdingProfit?.canonical, '428.96');
      expect(holding.dataOrigin, DataOrigin.excel);
    });

    test('corrupt excel bytes surface as a blocking issue', () {
      final draft = parser.parseExcel(utf8.encode('not an xlsx'));
      expect(draft.holdings, isEmpty);
      expect(
        draft.issues.single.severity,
        IssueSeverity.blocking,
      );
    });
  });
}
