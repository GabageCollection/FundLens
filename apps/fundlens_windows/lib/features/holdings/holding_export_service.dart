import 'dart:convert';
import 'dart:io';

import 'package:fundlens_core/fundlens_core.dart';

import 'holding_filters.dart';
import 'holding_status.dart';

/// Exports the currently visible (sorted/filtered) holdings to CSV.
///
/// The file always starts with a UTF-8 BOM so spreadsheet tools detect the
/// encoding, uses Chinese headers, and writes decimal values as their
/// canonical strings — no re-computation or rounding happens here.
final class HoldingExportService {
  const HoldingExportService();

  static const headers = [
    '产品名称',
    '产品代码',
    '来源',
    '产品形态',
    '资产类别',
    '币种',
    '份额',
    '现价',
    '成本金额',
    '当前金额',
    '持仓盈亏',
    '持仓收益率',
    '估值日期',
    '估值方式',
    '数据出处',
    '备注',
  ];

  static const _bom = [0xEF, 0xBB, 0xBF];

  Future<File> exportCsv(List<Holding> rows, String path) async {
    final lines = [
      _row(headers),
      for (final holding in rows) _row(_fields(holding)),
    ];
    final buffer = StringBuffer(lines.join('\r\n'))..write('\r\n');
    final file = File(path);
    await file.writeAsBytes([
      ..._bom,
      ...utf8.encode(buffer.toString()),
    ]);
    return file;
  }

  List<String> _fields(Holding h) {
    return [
      h.productName,
      h.productCode ?? '',
      HoldingLabels.sourcePlatform[h.sourcePlatform]!,
      HoldingLabels.instrumentType[h.instrumentType]!,
      HoldingLabels.assetClass[h.assetClass]!,
      h.currency,
      h.quantity?.canonical ?? '',
      h.currentPrice?.canonical ?? '',
      h.costAmount?.canonical ?? '',
      h.currentValue.canonical,
      h.holdingProfit?.canonical ?? '',
      h.holdingReturn?.canonical ?? '',
      HoldingValueFormatter.date(h.valuationDate) == '—'
          ? ''
          : HoldingValueFormatter.date(h.valuationDate),
      HoldingLabels.valuationMethod[h.valuationMethod]!,
      HoldingLabels.dataOrigin[h.dataOrigin]!,
      h.note ?? '',
    ];
  }

  String _row(List<String> fields) => fields.map(_escape).join(',');

  String _escape(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
