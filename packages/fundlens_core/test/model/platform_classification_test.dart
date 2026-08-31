import 'package:fundlens_core/fundlens_core.dart';
import 'package:test/test.dart';

void main() {
  group('classifyPlatformHolding', () {
    test('同花顺持仓页全部是场内基金:ETF + 权益类', () {
      final c = classifyPlatformHolding(SourcePlatform.ths, null);
      expect(c.instrumentType, InstrumentType.etf);
      expect(c.assetClass, AssetClass.equity);
    });

    test('支付宝「稳健理财」标签归为固收类场外基金', () {
      final c = classifyPlatformHolding(SourcePlatform.alipay, '基金 稳健理财');
      expect(c.instrumentType, InstrumentType.offExchangeFund);
      expect(c.assetClass, AssetClass.fixedIncome);
    });

    test('支付宝「进阶理财」标签归为权益类场外基金', () {
      final c = classifyPlatformHolding(SourcePlatform.alipay, '基金 进阶理财');
      expect(c.instrumentType, InstrumentType.offExchangeFund);
      expect(c.assetClass, AssetClass.equity);
    });

    test('支付宝无标签或标签未识别时保持未分类,由人工确认', () {
      for (final tags in [null, '', '基金', '活钱管理']) {
        final c = classifyPlatformHolding(SourcePlatform.alipay, tags);
        expect(c.instrumentType, InstrumentType.offExchangeFund);
        expect(c.assetClass, AssetClass.other, reason: 'tags=$tags');
      }
    });

    test('手动录入不预设分类', () {
      final c = classifyPlatformHolding(SourcePlatform.manual, null);
      expect(c.assetClass, AssetClass.other);
    });
  });
}
