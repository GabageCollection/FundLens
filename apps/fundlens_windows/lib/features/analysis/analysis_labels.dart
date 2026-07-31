import 'package:fundlens_core/fundlens_core.dart';

/// Display labels and presentation formatters for the analysis page.
///
/// Formatting converts exact [DecimalValue] amounts to strings at the render
/// boundary only; no domain calculation happens here.

const assetClassLabels = <AssetClass, String>{
  AssetClass.cash: '现金',
  AssetClass.deposit: '存款',
  AssetClass.equity: '权益',
  AssetClass.fixedIncome: '固收',
  AssetClass.mixed: '混合',
  AssetClass.gold: '黄金',
  AssetClass.other: '其他',
};

const instrumentTypeLabels = <InstrumentType, String>{
  InstrumentType.cashManagement: '现金管理',
  InstrumentType.bankDeposit: '银行存款',
  InstrumentType.stock: '股票',
  InstrumentType.etf: 'ETF',
  InstrumentType.lof: 'LOF',
  InstrumentType.reit: 'REIT',
  InstrumentType.offExchangeFund: '场外基金',
  InstrumentType.accumulatedGold: '积存金',
  InstrumentType.physicalGold: '实物黄金',
};

const sourcePlatformLabels = <SourcePlatform, String>{
  SourcePlatform.alipay: '支付宝',
  SourcePlatform.ths: '同花顺',
  SourcePlatform.manual: '手工录入',
};

/// Groups thousands and keeps exactly two decimals: `12,000.00`.
String formatAmount(DecimalValue value) {
  final negative = value.isNegative;
  final parts = value.canonical.split('.');
  var integer = parts.first;
  if (integer.startsWith('-')) integer = integer.substring(1);
  final grouped = _groupThousands(integer);
  final fraction = parts.length > 1
      ? parts[1].padRight(2, '0').substring(0, 2)
      : '00';
  return '${negative ? '-' : ''}$grouped.$fraction';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

/// One-decimal percentage: `34.9%`.
String formatShare(DecimalValue share) {
  final percent = double.parse(share.canonical) * 100;
  return '${percent.toStringAsFixed(1)}%';
}

/// Signed amount for snapshot deltas, always with `+`/`-`: `+1,000.00`.
String formatSignedAmount(DecimalValue value) {
  if (value.isNegative) return formatAmount(value);
  return '+${formatAmount(value)}';
}

/// 坐标轴紧凑刻度:≥1 万显示 `12.3万`,仅用于渲染。
String formatAxisAmount(DecimalValue value) {
  final number = value.value.toDouble();
  if (number.abs() >= 10000) {
    return '${(number / 10000).toStringAsFixed(1)}万';
  }
  return number.toStringAsFixed(0);
}
