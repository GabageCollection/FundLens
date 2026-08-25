import 'package:fundlens_core/fundlens_core.dart';

import '../../importing/import_models.dart';
import 'import_draft_persistence.dart';

/// Result of turning one `ocr.parse_screenshots` response into a draft.
final class OcrDraftResult {
  const OcrDraftResult({required this.draft, required this.rows});

  final ImportDraft draft;

  /// OCR rows with per-field confidence and crop rectangles.
  final List<OcrRow> rows;
}

/// Builds an [ImportDraft] from the merged engine OCR response.
///
/// A row without a recognizable amount is never silently zeroed: it gets a
/// blocking issue so the user must fill in the amount before committing.
OcrDraftResult buildDraftFromOcr(
  Map<String, Object?> response,
  String template,
) {
  final platform = template == 'alipay'
      ? SourcePlatform.alipay
      : SourcePlatform.ths;
  final rows = <OcrRow>[];
  final holdings = <DraftHolding>[];
  final issues = <DataIssue>[];

  final rawRows = response['rows'] as List? ?? const [];
  for (var i = 0; i < rawRows.length; i++) {
    final rawRow = importAsMap(rawRows[i]);
    final fields = <String, OcrFieldValue>{
      for (final entry in importAsMap(rawRow['fields']).entries)
        entry.key: OcrFieldValue.fromJson(importAsMap(entry.value)),
    };
    rows.add(
      OcrRow(
        index: i,
        pageIndex: (rawRow['page_index'] as num?)?.toInt() ?? 0,
        fields: fields,
      ),
    );

    for (final rawIssue in rawRow['issues'] as List? ?? const []) {
      issues.add(importIssueFromJson(importAsMap(rawIssue)));
    }

    final normalized = importAsMap(rawRow['normalized']);
    DecimalValue? amountOf(String field) {
      final normalizedValue = normalized[field] as String?;
      if (normalizedValue != null) {
        final parsed = parseImportAmount(normalizedValue);
        if (parsed != null) return parsed;
      }
      final rawText = fields[field]?.rawText;
      return rawText == null ? null : parseImportAmount(rawText);
    }

    final currentValue = amountOf('current_value');
    if (currentValue == null) {
      // 缺失金额不静默记 0:生成阻断问题,字段级提示补填后才允许提交。
      issues.add(
        DataIssue(
          code: 'import.missing_amount',
          field: 'current_value',
          severity: IssueSeverity.blocking,
          message: '未识别到金额，请补填当前金额',
          holdingIndex: holdings.length,
        ),
      );
    }
    holdings.add(
      DraftHolding(
        sourcePlatform: platform,
        productName: fields['product_name']?.rawText ?? '',
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.other,
        currentValue: currentValue ?? DecimalValue.parse('0'),
        quantity: amountOf('quantity'),
        costPrice: amountOf('cost_price'),
        holdingProfit: amountOf('holding_profit'),
        cumulativeProfit: amountOf('cumulative_profit'),
        dataOrigin: DataOrigin.ocr,
      ),
    );
  }

  for (final rawIssue in response['issues'] as List? ?? const []) {
    issues.add(importIssueFromJson(importAsMap(rawIssue)));
  }

  return OcrDraftResult(
    draft: ImportDraft(holdings: holdings, issues: issues),
    rows: rows,
  );
}
