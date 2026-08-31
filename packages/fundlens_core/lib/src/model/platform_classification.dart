import 'holding.dart';

/// 平台来源推断出的默认分类:工具类型 + 资产类别。
///
/// 只是导入时的初值,用户可在审核界面之后的持仓管理中调整;
/// 分类不影响金额计算,只影响资产结构分析的分桶。
typedef PlatformClassification = ({
  InstrumentType instrumentType,
  AssetClass assetClass,
});

/// 按平台与平台标签推断持仓的默认分类。
///
/// - 同花顺持仓页只展示场内品种,全部归为 ETF / 权益类;
/// - 支付宝名称下方的标签行区分「稳健理财」(固收)与「进阶理财」(权益),
///   标签缺失或未识别时保持 [AssetClass.other],由审核界面提示人工确认;
/// - 手动录入不做任何预设。
PlatformClassification classifyPlatformHolding(
  SourcePlatform platform,
  String? platformTags,
) {
  switch (platform) {
    case SourcePlatform.ths:
      return (instrumentType: InstrumentType.etf, assetClass: AssetClass.equity);
    case SourcePlatform.alipay:
      final tags = platformTags ?? '';
      if (tags.contains('稳健理财')) {
        return (
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: AssetClass.fixedIncome,
        );
      }
      if (tags.contains('进阶理财')) {
        return (
          instrumentType: InstrumentType.offExchangeFund,
          assetClass: AssetClass.equity,
        );
      }
      return (
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.other,
      );
    case SourcePlatform.manual:
      return (
        instrumentType: InstrumentType.offExchangeFund,
        assetClass: AssetClass.other,
      );
  }
}
