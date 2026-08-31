import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/import_review/import_ocr_draft_builder.dart';

Map<String, Object?> _field(String name, String rawText) {
  return <String, Object?>{
    'name': name,
    'raw_text': rawText,
    'confidence': 0.98,
    'page_index': 0,
    'crop': const [0, 0, 100, 40],
  };
}

Map<String, Object?> _ocrResponse(
  String template, {
  required String productName,
  String? platformTags,
}) {
  final fields = <String, Object?>{
    'product_name': _field('product_name', productName),
    'current_value': _field('current_value', '1,000.00'),
  };
  if (platformTags != null) {
    fields['platform_tags'] = _field('platform_tags', platformTags);
  }
  return <String, Object?>{
    'template': template,
    'rows': [
      <String, Object?>{
        'index': 0,
        'page_index': 0,
        'fields': fields,
        'normalized': const <String, Object?>{'current_value': '1000.00'},
        'issues': const <Object?>[],
      },
    ],
    'issues': const <Object?>[],
  };
}

void main() {
  group('buildDraftFromOcr classification', () {
    test('同花顺持仓全部归为场内基金(ETF)/权益类', () {
      final result = buildDraftFromOcr(
        _ocrResponse('ths', productName: '纳指'),
        'ths',
      );
      final holding = result.draft.holdings.single;
      expect(holding.instrumentType, InstrumentType.etf);
      expect(holding.assetClass, AssetClass.equity);
    });

    test('支付宝「稳健理财」归为固收类场外基金', () {
      final result = buildDraftFromOcr(
        _ocrResponse('alipay', productName: '安心债券A', platformTags: '基金 稳健理财'),
        'alipay',
      );
      final holding = result.draft.holdings.single;
      expect(holding.instrumentType, InstrumentType.offExchangeFund);
      expect(holding.assetClass, AssetClass.fixedIncome);
    });

    test('支付宝「进阶理财」归为权益类场外基金', () {
      final result = buildDraftFromOcr(
        _ocrResponse('alipay', productName: '先锋股票', platformTags: '进阶理财'),
        'alipay',
      );
      expect(result.draft.holdings.single.assetClass, AssetClass.equity);
    });

    test('支付宝标签缺失时保持未分类,由审核界面提示人工确认', () {
      final result = buildDraftFromOcr(
        _ocrResponse('alipay', productName: '未知产品'),
        'alipay',
      );
      expect(result.draft.holdings.single.assetClass, AssetClass.other);
    });
  });
}
