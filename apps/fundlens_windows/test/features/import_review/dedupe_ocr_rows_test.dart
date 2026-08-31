import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/features/import_review/dedupe_ocr_rows.dart';

Map<String, Object?> _field(String name, String rawText) {
  return <String, Object?>{
    'name': name,
    'raw_text': rawText,
    'confidence': 0.98,
    'page_index': 0,
    'crop': const [0, 0, 100, 40],
  };
}

Map<String, Object?> _row({
  String? name,
  required String value,
  String? profit,
  String? quantity,
  String? cost,
  int pageIndex = 0,
}) {
  final fields = <String, Object?>{
    'current_value': _field('current_value', value),
    if (name != null) 'product_name': _field('product_name', name),
    if (profit != null) 'holding_profit': _field('holding_profit', profit),
    if (quantity != null) 'quantity': _field('quantity', quantity),
    if (cost != null) 'cost_price': _field('cost_price', cost),
  };
  return <String, Object?>{
    'page_index': pageIndex,
    'fields': fields,
    'normalized': <String, Object?>{'current_value': value.replaceAll(',', '')},
    'issues': const <Object?>[],
  };
}

Map<String, Object?> _issue(int? holdingIndex) {
  return <String, Object?>{
    'code': 'import.cost_mismatch',
    'field': 'derived_cost',
    'severity': 'blocking',
    'message': 'mismatch',
    'holding_index': holdingIndex,
  };
}

void main() {
  group('dedupeOcrResponse', () {
    test('跨页完全重复的持仓自动去除后出现的副本', () {
      final response = <String, Object?>{
        'rows': [
          _row(name: '标普ETF', value: '7,362.00', profit: '598.70', quantity: '3600', cost: '1.879'),
          _row(name: '纳指', value: '15,818.70', profit: '511.40', quantity: '6700', cost: '2.285'),
          _row(name: '标普ETF', value: '7,362.00', profit: '598.70', quantity: '3600', cost: '1.879', pageIndex: 1),
        ],
        'issues': <Object?>[],
      };
      final result = dedupeOcrResponse(response);
      final rows = result['rows'] as List;
      expect(rows, hasLength(2));
      // 保留首次出现的行
      expect((rows.first as Map)['page_index'], 0);
      expect(result['duplicate_auto_removed'], 1);
    });

    test('名称缺失的残缺行数值签名与完整行一致时自动去除', () {
      // 真实场景:第 2 页标普ETF 名称区损坏(识别为空、盈亏乱码 02869),
      // 但金额/数量/成本与第 1 页完整行一致。
      final response = <String, Object?>{
        'rows': [
          _row(name: '标普ETF', value: '7,362.00', profit: '598.70', quantity: '3600', cost: '1.879'),
          _row(value: '7,362.00', profit: '02869', quantity: '3600', cost: '1.879', pageIndex: 1),
        ],
        'issues': <Object?>[
          _issue(1), // 残缺行的阻断问题随它一起移除
        ],
      };
      final result = dedupeOcrResponse(response);
      expect(result['rows'], hasLength(1));
      // 残缺行自身的阻断问题随之移除,只留下自动去除的 info 提示
      final issues = result['issues'] as List;
      expect(issues, hasLength(1));
      expect((issues.single as Map)['code'], 'ocr.duplicate_auto_removed');
      expect((issues.single as Map)['severity'], 'info');
      expect(result['duplicate_auto_removed'], 1);
    });

    test('残缺行找不到数值一致的完整行时保留,由人工补填', () {
      final response = <String, Object?>{
        'rows': [
          _row(name: '纳指', value: '15,818.70', quantity: '6700', cost: '2.285'),
          _row(value: '9,999.00', quantity: '100', cost: '1.0', pageIndex: 1),
        ],
        'issues': <Object?>[],
      };
      final result = dedupeOcrResponse(response);
      expect(result['rows'], hasLength(2));
      expect(result['duplicate_auto_removed'], 0);
    });

    test('数值签名不足两个字段的行不参与去除,防止误删', () {
      final response = <String, Object?>{
        'rows': [
          _row(name: '基金A', value: '1,000.00'),
          _row(name: '基金B', value: '1,000.00'),
        ],
        'issues': <Object?>[],
      };
      final result = dedupeOcrResponse(response);
      expect(result['rows'], hasLength(2));
    });

    test('响应级问题的 holding_index 随移除重排', () {
      final response = <String, Object?>{
        'rows': [
          _row(name: '基金A', value: '1,000.00', quantity: '100', cost: '10'),
          _row(name: '基金A', value: '1,000.00', quantity: '100', cost: '10', pageIndex: 1),
          _row(name: '基金B', value: '2,000.00', quantity: '200', cost: '10'),
        ],
        'issues': <Object?>[
          _issue(0), // 保留行,不变
          _issue(1), // 被移除行,丢弃
          _issue(2), // 前移一行 → 1
        ],
      };
      final result = dedupeOcrResponse(response);
      expect(result['rows'], hasLength(2));
      final issues = result['issues'] as List;
      expect(issues, hasLength(3));
      expect((issues[0] as Map)['holding_index'], 0);
      expect((issues[1] as Map)['holding_index'], 1);
      expect((issues[2] as Map)['code'], 'ocr.duplicate_auto_removed');
    });

    test('千分位与完整写法金额视为同一数值', () {
      final response = <String, Object?>{
        'rows': [
          _row(name: '基金A', value: '7,362.00', quantity: '3600', cost: '1.879'),
          _row(name: '基金A', value: '7362.00', quantity: '3600', cost: '1.879', pageIndex: 1),
        ],
        'issues': <Object?>[],
      };
      expect(dedupeOcrResponse(response)['rows'], hasLength(1));
    });
  });
}
