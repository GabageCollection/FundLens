import 'package:fundlens_core/fundlens_core.dart';

import 'import_draft_persistence.dart';

/// 合并多页 OCR 结果后的自动去重。
///
/// 滚动截屏相邻两页常有重叠,同一持仓会被识别两次;识别受损的残缺行
/// (名称缺失、个别字段乱码)也可能是某完整行的重复。这些副本不该留给
/// 用户手工删除:
///
/// - 完全重复:名称相同且数值签名一致 → 保留首次出现的行;
/// - 残缺重复:名称缺失但数值签名(≥2 个数值字段)与某保留的完整行
///   一致 → 视为同一持仓的受损副本,自动去除;
/// - 数值签名不足两个字段的行不参与去重,防止只有金额巧合相同被误删。
///
/// 响应级阻断问题的 holding_index 随移除重排;去除行为追加一条 info
/// 级问题保持透明(用户能看到,但不需要操作)。
Map<String, Object?> dedupeOcrResponse(Map<String, Object?> response) {
  final rows = [
    for (final raw in response['rows'] as List? ?? const []) importAsMap(raw),
  ];
  final issues = [
    for (final raw in response['issues'] as List? ?? const []) importAsMap(raw),
  ];

  final seenFullSignatures = <String>{};
  final completeNumericSignatures = <String>{};
  final damagedRows = <(int, String)>[];
  final removed = <int>{};

  for (var i = 0; i < rows.length; i++) {
    final signature = _numericSignature(rows[i]);
    if (signature == null) continue;
    final name = _nameOf(rows[i]);
    if (name.isEmpty) {
      // 残缺行延后再判:它依赖所有完整行的数值签名,与出现顺序无关。
      damagedRows.add((i, signature));
      continue;
    }
    if (!seenFullSignatures.add('$name|$signature')) {
      removed.add(i);
    } else {
      completeNumericSignatures.add(signature);
    }
  }
  for (final (index, signature) in damagedRows) {
    if (completeNumericSignatures.contains(signature)) removed.add(index);
  }

  if (removed.isEmpty) {
    return {...response, 'duplicate_auto_removed': 0};
  }

  int remap(int index) => index - removed.where((r) => r < index).length;
  final keptRows = [
    for (var i = 0; i < rows.length; i++)
      if (!removed.contains(i)) rows[i],
  ];
  final keptIssues = <Map<String, Object?>>[];
  for (final issue in issues) {
    final index = (issue['holding_index'] as num?)?.toInt();
    if (index != null && removed.contains(index)) continue; // 随行一起移除
    keptIssues.add(
      index == null ? issue : {...issue, 'holding_index': remap(index)},
    );
  }
  keptIssues.add(
    <String, Object?>{
      'code': 'ocr.duplicate_auto_removed',
      'field': '',
      'severity': 'info',
      'message': '识别结果中有 ${removed.length} 行与前面重复的持仓（滚动截屏相邻页'
          '重叠或识别受损的副本），已自动去除，无需处理',
      'holding_index': null,
    },
  );
  return {
    ...response,
    'rows': keptRows,
    'issues': keptIssues,
    'duplicate_auto_removed': removed.length,
  };
}

// 签名不含持有收益:识别受损行的盈亏最常乱码(实测 598.70 → 02869),
// 而名称+金额+数量+成本已足以区分不同持仓。
const _signatureFields = <String>['current_value', 'quantity', 'cost_price'];

String _nameOf(Map<String, Object?> row) {
  final field = importAsMap(importAsMap(row['fields'])['product_name']);
  return (field['raw_text'] as String? ?? '').replaceAll(' ', '').trim();
}

/// 数值签名:参与字段的解析值串联,不足两个字段返回 null(不参与去重)。
String? _numericSignature(Map<String, Object?> row) {
  final parts = <String>[];
  for (final name in _signatureFields) {
    final amount = _amountOf(row, name);
    if (amount != null) parts.add('$name=${amount.canonical}');
  }
  return parts.length >= 2 ? parts.join('|') : null;
}

DecimalValue? _amountOf(Map<String, Object?> row, String field) {
  final normalized = importAsMap(row['normalized'])[field] as String?;
  if (normalized != null) {
    final parsed = parseImportAmount(normalized);
    if (parsed != null) return parsed;
  }
  final rawText = importAsMap(importAsMap(row['fields'])[field])['raw_text'];
  return rawText is String ? parseImportAmount(rawText) : null;
}
