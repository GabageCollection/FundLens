import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/holdings/holding_export_service.dart';

Holding exportHolding({
  required String id,
  required String name,
  required String currentValue,
  String? quantity,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return Holding(
    id: id,
    sourcePlatform: SourcePlatform.alipay,
    instrumentType: InstrumentType.offExchangeFund,
    assetClass: AssetClass.equity,
    productName: name,
    productCode: '110011',
    currency: 'CNY',
    quantity: quantity == null ? null : DecimalValue.parse(quantity),
    currentValue: DecimalValue.parse(currentValue),
    valuationMethod: ValuationMethod.quantityTimesPrice,
    valuationDate: DateTime.utc(2026, 6, 30),
    dataOrigin: DataOrigin.excel,
    fieldProvenance: const {},
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('holding_export_test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('exportCsv writes UTF-8 BOM, Chinese headers and canonical decimals',
      () async {
    final path = '${dir.path}/holdings.csv';
    final file = await const HoldingExportService().exportCsv(
      [
        exportHolding(
          id: 'h-1',
          name: '易方达蓝筹精选',
          currentValue: '1234.50',
          quantity: '12.500',
        ),
        exportHolding(
          id: 'h-2',
          name: '招商双债',
          currentValue: '1000.00',
        ),
      ],
      path,
    );

    final bytes = await file.readAsBytes();
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final text = utf8.decode(bytes.sublist(3));
    final lines = text.trimRight().split('\r\n');

    expect(lines, hasLength(3));
    expect(
      lines.first,
      '产品名称,产品代码,来源,产品形态,资产类别,币种,份额,现价,成本金额,当前金额,持仓盈亏,持仓收益率,估值日期,估值方式,数据出处,备注',
    );
    // Canonical decimal strings: trailing zeros are normalized away.
    expect(lines[1], contains('1234.5'));
    expect(lines[1], contains('12.5'));
    expect(lines[1], contains('易方达蓝筹精选'));
    expect(lines[1], contains('110011'));
    expect(lines[1], contains('2026-06-30'));
    // Absent decimals render as empty cells, never "null".
    expect(lines[2], isNot(contains('null')));
    expect(lines[2], contains('1000'));
  });

  test('exportCsv exports exactly the given rows in order', () async {
    final path = '${dir.path}/filtered.csv';
    final file = await const HoldingExportService().exportCsv(
      [
        exportHolding(id: 'h-9', name: '产品B', currentValue: '5'),
        exportHolding(id: 'h-1', name: '产品A', currentValue: '10'),
      ],
      path,
    );
    final text = utf8.decode((await file.readAsBytes()).sublist(3));
    final lines = text.trimRight().split('\r\n');
    expect(lines, hasLength(3));
    expect(lines[1].startsWith('产品B,'), isTrue);
    expect(lines[2].startsWith('产品A,'), isTrue);
  });

  test('exportCsv quotes fields containing commas', () async {
    final path = '${dir.path}/quoted.csv';
    final file = await const HoldingExportService().exportCsv(
      [exportHolding(id: 'h-1', name: '甲,乙基金', currentValue: '10')],
      path,
    );
    final text = utf8.decode((await file.readAsBytes()).sublist(3));
    expect(text, contains('"甲,乙基金"'));
  });
}
