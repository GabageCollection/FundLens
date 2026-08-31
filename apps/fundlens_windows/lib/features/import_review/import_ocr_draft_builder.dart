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
      final issue = importIssueFromJson(importAsMap(rawIssue));
      // 引擎把阻断问题同时放在行级 issues(无 holding_index)和响应级
      // issues(带 holding_index)里;只保留响应级那份,行级阻断副本丢弃,
      // 否则同一问题在「需要处理的数据问题」里显示两次。
      if (issue.severity == IssueSeverity.blocking) continue;
      issues.add(issue);
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
    // 平台默认分类:同花顺全部场内基金(ETF/权益);支付宝按名称下方的
    // 「稳健理财」「进阶理财」标签分桶,标签缺失保持未分类由人工确认。
    final classification = classifyPlatformHolding(
      platform,
      fields['platform_tags']?.rawText,
    );
    holdings.add(
      DraftHolding(
        sourcePlatform: platform,
        productName: fields['product_name']?.rawText ?? '',
        instrumentType: classification.instrumentType,
        assetClass: classification.assetClass,
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
