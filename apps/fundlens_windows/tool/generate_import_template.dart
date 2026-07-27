// Generates the bundled Excel import template with the same `excel` package
// the parser uses, guaranteeing the shipped file decodes in-app.
// Run from apps/fundlens_windows: dart run tool/generate_import_template.dart
import 'dart:io';

import 'package:excel/excel.dart';

const header = [
  'source_platform',
  'product_name',
  'product_code',
  'instrument_type',
  'current_value',
  'holding_profit',
  'cumulative_profit',
  'quantity',
  'current_price',
  'cost_price',
  'currency',
  'platform_tags',
  'note',
];

const sample = [
  '支付宝',
  '脱敏纯债基金A',
  '000001',
  '场外基金',
  '78,347.87',
  '+428.96',
  '1,888.88',
  '',
  '',
  '',
  'CNY',
  '基金|稳健理财',
  '示例行（脱敏合成数据）',
];

void main() {
  final excel = Excel.createExcel();
  final sheet = excel['holdings'];
  excel.setDefaultSheet('holdings');
  sheet.appendRow([for (final h in header) TextCellValue(h)]);
  sheet.appendRow([for (final v in sample) TextCellValue(v)]);
  final bytes = excel.encode();
  if (bytes == null) {
    stderr.writeln('excel.encode() returned null');
    exitCode = 1;
    return;
  }
  for (final path in [
    'assets/import-templates/fundlens-import-template.xlsx',
    '../../docs/import-template/fundlens-import-template.xlsx',
  ]) {
    File(path).writeAsBytesSync(bytes);
    stdout.writeln('written $path (${bytes.length} bytes)');
  }
}
