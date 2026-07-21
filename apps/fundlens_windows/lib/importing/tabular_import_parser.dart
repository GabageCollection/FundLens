import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:fundlens_core/fundlens_core.dart';

import 'import_models.dart';

/// Parses CSV and Excel holdings into an [ImportDraft].
///
/// Accepts both canonical English and Chinese column headings, rejects
/// duplicate columns, parses amounts with thousands separators through
/// [DecimalValue] (never `double`), preserves unknown columns in
/// [DraftHolding.metadata], and reports blocking issues for missing product
/// name / current value or invalid signs.
final class TabularImportParser {
  const TabularImportParser();

  static const _columnAliases = <String, List<String>>{
    'sourcePlatform': ['source_platform', '来源平台', '平台'],
    'productName': ['product_name', '产品名称', '名称'],
    'productCode': ['product_code', '产品代码', '代码', '基金代码'],
    'instrumentType': ['instrument_type', '产品类型', '类型'],
    'currentValue': ['current_value', '当前金额', '市值'],
    'holdingProfit': ['holding_profit', '持有收益', '持仓收益'],
    'cumulativeProfit': ['cumulative_profit', '累计收益'],
    'quantity': ['quantity', '持仓数量', '份额'],
    'currentPrice': ['current_price', '现价', '最新价'],
    'costPrice': ['cost_price', '成本价'],
    'costAmount': ['cost_amount', '成本金额', '持仓成本'],
    'currency': ['currency', '币种'],
    'platformTags': ['platform_tags', '平台标签', '标签'],
    'note': ['note', '备注'],
  };

  static const _platformAliases = <String, SourcePlatform>{
    'alipay': SourcePlatform.alipay,
    '支付宝': SourcePlatform.alipay,
    'ths': SourcePlatform.ths,
    '同花顺': SourcePlatform.ths,
    'manual': SourcePlatform.manual,
    '手动': SourcePlatform.manual,
    '手动录入': SourcePlatform.manual,
  };

  static const _instrumentTypeAliases = <String, InstrumentType>{
    'off_exchange_fund': InstrumentType.offExchangeFund,
    'offexchangefund': InstrumentType.offExchangeFund,
    '场外基金': InstrumentType.offExchangeFund,
    '基金': InstrumentType.offExchangeFund,
    'etf': InstrumentType.etf,
    'lof': InstrumentType.lof,
    'reit': InstrumentType.reit,
    'reits': InstrumentType.reit,
    'stock': InstrumentType.stock,
    '股票': InstrumentType.stock,
    'cash_management': InstrumentType.cashManagement,
    '货币基金': InstrumentType.cashManagement,
    '现金管理': InstrumentType.cashManagement,
    'bank_deposit': InstrumentType.bankDeposit,
    '银行存款': InstrumentType.bankDeposit,
    '存款': InstrumentType.bankDeposit,
    'accumulated_gold': InstrumentType.accumulatedGold,
    '积存金': InstrumentType.accumulatedGold,
    'physical_gold': InstrumentType.physicalGold,
    '实物金': InstrumentType.physicalGold,
  };

  ImportDraft parseCsv(
    String content, {
    SourcePlatform fallbackPlatform = SourcePlatform.manual,
  }) {
    final rows = const CsvDecoder(dynamicTyping: false)
        .convert(content)
        .map((row) => row.map((cell) => cell.toString().trim()).toList())
        .toList();
    return _parseRows(rows, DataOrigin.csv, fallbackPlatform);
  }

  ImportDraft parseExcel(
    List<int> bytes, {
    String? sheetName,
    SourcePlatform fallbackPlatform = SourcePlatform.manual,
  }) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      return ImportDraft(
        holdings: const [],
        issues: [
          DataIssue(
            code: 'import.unreadable_file',
            field: 'file',
            severity: IssueSeverity.blocking,
            message: '无法读取 Excel 文件: $e',
          ),
        ],
      );
    }

    Sheet? sheet;
    if (sheetName != null) {
      sheet = excel.tables[sheetName];
    } else {
      for (final candidate in excel.tables.values) {
        if (candidate.rows.isNotEmpty) {
          sheet = candidate;
          break;
        }
      }
    }
    if (sheet == null) {
      return const ImportDraft(
        holdings: [],
        issues: [
          DataIssue(
            code: 'import.unreadable_file',
            field: 'file',
            severity: IssueSeverity.blocking,
            message: 'Excel 文件为空',
          ),
        ],
      );
    }

    final rows = sheet.rows
        .map(
          (row) => row
              .map((cell) => (cell?.value?.toString() ?? '').trim())
              .toList(),
        )
        .toList();
    return _parseRows(rows, DataOrigin.excel, fallbackPlatform);
  }

  ImportDraft _parseRows(
    List<List<String>> rows,
    DataOrigin origin,
    SourcePlatform fallbackPlatform,
  ) {
    // Drop trailing fully-empty rows.
    final dataRows = rows.toList();
    while (dataRows.isNotEmpty &&
        dataRows.last.every((cell) => cell.isEmpty)) {
      dataRows.removeLast();
    }
    if (dataRows.isEmpty) {
      return const ImportDraft(
        holdings: [],
        issues: [
          DataIssue(
            code: 'import.unreadable_file',
            field: 'file',
            severity: IssueSeverity.blocking,
            message: '文件为空',
          ),
        ],
      );
    }

    final headings = dataRows.first;

    // Map each column index to a canonical field; unknown columns are kept.
    final columnFields = List<String?>.filled(headings.length, null);
    final seenFields = <String, int>{};
    final seenRaw = <String>{};
    for (var i = 0; i < headings.length; i++) {
      final raw = headings[i];
      if (raw.isEmpty) continue;
      final normalized = raw.toLowerCase();
      if (!seenRaw.add(normalized)) {
        return _duplicateColumn(raw);
      }
      for (final entry in _columnAliases.entries) {
        if (entry.value.any((alias) => alias.toLowerCase() == normalized)) {
          if (seenFields.containsKey(entry.key)) {
            return _duplicateColumn(raw);
          }
          seenFields[entry.key] = i;
          columnFields[i] = entry.key;
          break;
        }
      }
    }

    for (final required in ['productName', 'currentValue']) {
      if (!seenFields.containsKey(required)) {
        return ImportDraft(
          holdings: const [],
          issues: [
            DataIssue(
              code: 'import.missing_column',
              field: required,
              severity: IssueSeverity.blocking,
              message: '缺少必需列: $required',
            ),
          ],
        );
      }
    }

    final holdings = <DraftHolding>[];
    final issues = <DataIssue>[];
    for (var rowIndex = 1; rowIndex < dataRows.length; rowIndex++) {
      final row = dataRows[rowIndex];
      final holdingIndex = rowIndex - 1;
      if (row.every((cell) => cell.isEmpty)) continue;

      final fields = <String, String>{};
      final metadata = <String, String>{};
      for (var i = 0; i < headings.length; i++) {
        final value = i < row.length ? row[i] : '';
        final field = columnFields[i];
        if (field != null) {
          fields[field] = value;
        } else if (headings[i].isNotEmpty && value.isNotEmpty) {
          metadata[headings[i]] = value;
        }
      }

      final parsed = _parseHolding(
        fields,
        metadata,
        holdingIndex,
        origin,
        fallbackPlatform,
        issues,
      );
      if (parsed != null) holdings.add(parsed);
    }

    return ImportDraft(holdings: holdings, issues: issues);
  }

  ImportDraft _duplicateColumn(String heading) {
    return ImportDraft(
      holdings: const [],
      issues: [
        DataIssue(
          code: 'import.duplicate_column',
          field: heading,
          severity: IssueSeverity.blocking,
          message: '重复的列: $heading',
        ),
      ],
    );
  }

  DraftHolding? _parseHolding(
    Map<String, String> fields,
    Map<String, String> metadata,
    int holdingIndex,
    DataOrigin origin,
    SourcePlatform fallbackPlatform,
    List<DataIssue> issues,
  ) {
    void blocking(String code, String field, String message) {
      issues.add(
        DataIssue(
          code: code,
          field: field,
          severity: IssueSeverity.blocking,
          message: message,
          holdingIndex: holdingIndex,
        ),
      );
    }

    final productName = fields['productName']?.trim() ?? '';
    if (productName.isEmpty) {
      blocking('import.missing_product_name', 'productName', '产品名称为空');
      return null;
    }

    final rawValue = fields['currentValue']?.trim() ?? '';
    if (rawValue.isEmpty) {
      blocking('import.missing_current_value', 'currentValue', '当前金额为空');
      return null;
    }
    final currentValue = _parseAmount(rawValue);
    if (currentValue == null) {
      blocking('import.invalid_amount', 'currentValue', '当前金额无法解析: $rawValue');
      return null;
    }
    if (currentValue.isNegative) {
      blocking('import.invalid_sign', 'currentValue', '当前金额不得为负: $rawValue');
      return null;
    }

    final platformText = fields['sourcePlatform']?.trim() ?? '';
    SourcePlatform platform = fallbackPlatform;
    if (platformText.isNotEmpty) {
      final parsed = _platformAliases[platformText.toLowerCase()] ??
          _platformAliases[platformText];
      if (parsed == null) {
        blocking(
          'import.unknown_platform',
          'sourcePlatform',
          '未知平台: $platformText',
        );
        return null;
      }
      platform = parsed;
    }

    var instrumentType = InstrumentType.offExchangeFund;
    final typeText = fields['instrumentType']?.trim() ?? '';
    if (typeText.isNotEmpty) {
      final parsed = _instrumentTypeAliases[typeText.toLowerCase()] ??
          _instrumentTypeAliases[typeText];
      if (parsed == null) {
        issues.add(
          DataIssue(
            code: 'import.unknown_instrument_type',
            field: 'instrumentType',
            severity: IssueSeverity.warning,
            message: '未知产品类型，按场外基金处理: $typeText',
            holdingIndex: holdingIndex,
          ),
        );
      } else {
        instrumentType = parsed;
      }
    }

    DecimalValue? optionalAmount(String field, {bool allowNegative = true}) {
      final raw = fields[field]?.trim() ?? '';
      if (raw.isEmpty) return null;
      final parsed = _parseAmount(raw);
      if (parsed == null) {
        blocking('import.invalid_amount', field, '金额无法解析: $raw');
      } else if (!allowNegative && parsed.isNegative) {
        blocking('import.invalid_sign', field, '金额不得为负: $raw');
      }
      return parsed;
    }

    final quantity = optionalAmount('quantity', allowNegative: false);
    final currentPrice = optionalAmount('currentPrice', allowNegative: false);
    final costPrice = optionalAmount('costPrice', allowNegative: false);
    final costAmount = optionalAmount('costAmount', allowNegative: false);
    final holdingProfit = optionalAmount('holdingProfit');
    final cumulativeProfit = optionalAmount('cumulativeProfit');
    if (issues.any(
      (i) =>
          i.holdingIndex == holdingIndex &&
          i.severity == IssueSeverity.blocking,
    )) {
      return null;
    }

    final tags = (fields['platformTags'] ?? '')
        .split('|')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    return DraftHolding(
      sourcePlatform: platform,
      productName: productName,
      productCode: (fields['productCode']?.trim().isEmpty ?? true)
          ? null
          : fields['productCode']!.trim(),
      instrumentType: instrumentType,
      assetClass: AssetClass.other,
      currentValue: currentValue,
      quantity: quantity,
      currentPrice: currentPrice,
      costPrice: costPrice,
      costAmount: costAmount,
      holdingProfit: holdingProfit,
      cumulativeProfit: cumulativeProfit,
      currency: (fields['currency']?.trim().isEmpty ?? true)
          ? 'CNY'
          : fields['currency']!.trim(),
      platformTags: tags,
      note: (fields['note']?.trim().isEmpty ?? true)
          ? null
          : fields['note']!.trim(),
      dataOrigin: origin,
      metadata: metadata,
    );
  }

  /// Parses amounts like `78,347.87`, `1 888.88`, `¥100`, `+428.96` into a
  /// [DecimalValue] without ever going through binary floating point.
  static DecimalValue? _parseAmount(String raw) {
    var cleaned = raw
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('　', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .trim();
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);
    if (cleaned.isEmpty) return null;
    try {
      return DecimalValue.parse(cleaned);
    } on FormatException {
      return null;
    }
  }
}
