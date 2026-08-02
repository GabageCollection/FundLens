import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:fundlens_core/fundlens_core.dart';

import 'import_models.dart';

/// A raw, not-yet-mapped tabular sheet: headings plus data rows, with all
/// trailing fully-empty rows stripped. This is the input to
/// [TabularImportParser.guessColumnMapping] and
/// [TabularImportParser.parseTable] — the two-phase field-mapping workflow.
final class TabularTable {
  const TabularTable({required this.headings, required this.dataRows});

  final List<String> headings;
  final List<List<String>> dataRows;
}

/// Parses CSV and Excel holdings into an [ImportDraft].
///
/// Accepts both canonical English and Chinese column headings, rejects
/// duplicate columns, parses amounts with thousands separators through
/// [DecimalValue] (never `double`), preserves unknown columns in
/// [DraftHolding.metadata], and reports blocking issues for missing product
/// name / current value or invalid signs.
///
/// Supports two entry modes:
/// - one-shot `parseCsv` / `parseExcel` (legacy, used by tests and the
///   bundled template check), and
/// - two-phase `parseCsvTable` / `parseExcelTable` → `guessColumnMapping`
///   → `parseTable`, which lets the UI show the raw sheet and let the user
///   correct the mapping before any row becomes a holding.
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

  /// Phase 1a — reads a CSV string into a raw [TabularTable]. Trailing
  /// fully-empty rows are dropped; headings keep their raw cell text.
  TabularTable parseCsvTable(
    String content, {
    SourcePlatform fallbackPlatform = SourcePlatform.manual,
  }) {
    final rows = const CsvDecoder(dynamicTyping: false)
        .convert(content)
        .map((row) => row.map((cell) => cell.toString().trim()).toList())
        .toList();
    return _toTable(rows);
  }

  /// Phase 1b — reads an Excel file into a raw [TabularTable], using the
  /// first non-empty sheet (or [sheetName] when given). Throws
  /// [FormatException] when the bytes are not a readable xlsx file; callers
  /// surface that as a blocking issue in the UI.
  TabularTable parseExcelTable(
    List<int> bytes, {
    String? sheetName,
    SourcePlatform fallbackPlatform = SourcePlatform.manual,
  }) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      throw FormatException('无法读取 Excel 文件: $e');
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
      throw const FormatException('Excel 文件为空');
    }

    final rows = sheet.rows
        .map(
          (row) => row
              .map((cell) => (cell?.value?.toString() ?? '').trim())
              .toList(),
        )
        .toList();
    return _toTable(rows);
  }

  /// Phase 2a — guesses the system-field mapping for [headings] using the
  /// alias tables. Only unambiguous aliases are mapped; everything else
  /// stays `null` for the user to choose. Returns `column index -> field`.
  Map<String, int> guessColumnMapping(List<String> headings) {
    final mapping = <String, int>{};
    final seenFields = <String>{};
    for (var i = 0; i < headings.length; i++) {
      final raw = headings[i];
      if (raw.isEmpty) continue;
      final normalized = raw.toLowerCase();
      for (final entry in _columnAliases.entries) {
        if (entry.value.any((alias) => alias.toLowerCase() == normalized)) {
          if (seenFields.add(entry.key)) mapping[entry.key] = i;
          break;
        }
      }
    }
    return mapping;
  }

  /// Phase 2b — builds an [ImportDraft] from a raw [table] under the
  /// confirmed [mapping] (`system field -> column index`). Required fields
  /// that map to nothing produce a blocking `import.missing_column` issue;
  /// two fields mapped to the same column produce a blocking
  /// `import.duplicate_mapping` issue; unmapped columns are preserved in
  /// [DraftHolding.metadata].
  ImportDraft parseTable(
    TabularTable table,
    Map<String, int> mapping, {
    SourcePlatform fallbackPlatform = SourcePlatform.manual,
    DataOrigin origin = DataOrigin.csv,
  }) {
    final duplicateTarget = <int, String>{};
    for (final entry in mapping.entries) {
      final existing = duplicateTarget.putIfAbsent(entry.value, () => entry.key);
      if (existing != entry.key) {
        return ImportDraft(
          holdings: const [],
          issues: [
            DataIssue(
              code: 'import.duplicate_mapping',
              field: entry.key,
              severity: IssueSeverity.blocking,
              message: '多个系统字段映射到同一列 ${table.headings[entry.value]}',
            ),
          ],
        );
      }
    }

    for (final required in _requiredColumns) {
      if (!mapping.containsKey(required)) {
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

    return _parseRows(table, mapping, origin, fallbackPlatform);
  }

  /// Fields a parsed holding must be able to fill from a mapped column.
  static const _requiredColumns = ['productName', 'currentValue'];

  ImportDraft parseCsv(
    String content, {
    SourcePlatform fallbackPlatform = SourcePlatform.manual,
  }) {
    final rows = const CsvDecoder(dynamicTyping: false)
        .convert(content)
        .map((row) => row.map((cell) => cell.toString().trim()).toList())
        .toList();
    return _parseRowsLegacy(rows, DataOrigin.csv, fallbackPlatform);
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
    return _parseRowsLegacy(rows, DataOrigin.excel, fallbackPlatform);
  }

  ImportDraft _parseRowsLegacy(
    List<List<String>> rows,
    DataOrigin origin,
    SourcePlatform fallbackPlatform,
  ) {
    final table = _toTable(rows);
    if (table.dataRows.isEmpty && table.headings.isEmpty) {
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

    // Auto-mapping path keeps the legacy duplicate-column check: the same raw
    // heading twice, or two aliases resolving to one system field, is a
    // blocking error rather than a silently dropped column.
    final mapping = <String, int>{};
    final seenRaw = <String>{};
    final seenFields = <String>{};
    for (var i = 0; i < table.headings.length; i++) {
      final raw = table.headings[i];
      if (raw.isEmpty) continue;
      final normalized = raw.toLowerCase();
      if (!seenRaw.add(normalized)) {
        return _duplicateColumn(raw);
      }
      for (final entry in _columnAliases.entries) {
        if (entry.value.any((alias) => alias.toLowerCase() == normalized)) {
          if (!seenFields.add(entry.key)) {
            return _duplicateColumn(raw);
          }
          mapping[entry.key] = i;
          break;
        }
      }
    }

    return parseTable(
      table,
      mapping,
      origin: origin,
      fallbackPlatform: fallbackPlatform,
    );
  }

  /// Builds a raw [TabularTable] from decoded spreadsheet rows: strips
  /// trailing fully-empty rows and splits off the heading row.
  TabularTable _toTable(List<List<String>> rows) {
    final dataRows = rows.toList();
    while (dataRows.isNotEmpty && dataRows.last.every((cell) => cell.isEmpty)) {
      dataRows.removeLast();
    }
    if (dataRows.isEmpty) {
      return const TabularTable(headings: [], dataRows: []);
    }
    return TabularTable(
      headings: dataRows.first,
      dataRows: dataRows.sublist(1),
    );
  }

  /// Builds holdings from a raw [table] under a confirmed [mapping]
  /// (`system field -> column index`). Required-column and duplicate-mapping
  /// checks live in [parseTable]; this method only turns rows into holdings,
  /// preserving unmapped columns in [DraftHolding.metadata].
  ImportDraft _parseRows(
    TabularTable table,
    Map<String, int> mapping,
    DataOrigin origin,
    SourcePlatform fallbackPlatform,
  ) {
    if (table.dataRows.isEmpty) {
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

    final columnField = List<String?>.filled(table.headings.length, null);
    for (final entry in mapping.entries) {
      if (entry.value < table.headings.length) {
        columnField[entry.value] = entry.key;
      }
    }

    final holdings = <DraftHolding>[];
    final issues = <DataIssue>[];
    for (var holdingIndex = 0;
        holdingIndex < table.dataRows.length;
        holdingIndex++) {
      final row = table.dataRows[holdingIndex];
      if (row.every((cell) => cell.isEmpty)) continue;

      final fields = <String, String>{};
      final metadata = <String, String>{};
      for (var i = 0; i < table.headings.length; i++) {
        final value = i < row.length ? row[i] : '';
        final field = columnField[i];
        if (field != null) {
          fields[field] = value;
        } else if (table.headings[i].isNotEmpty && value.isNotEmpty) {
          metadata[table.headings[i]] = value;
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
