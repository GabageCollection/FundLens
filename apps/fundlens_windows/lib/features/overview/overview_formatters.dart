import 'package:fundlens_core/fundlens_core.dart';

import '../analysis/analysis_labels.dart' show formatAmount;

/// 总览页展示层格式化函数。
///
/// 只在渲染边界把精确的 [DecimalValue] 转成字符串,不做任何领域计算。

/// 带币种符号和千位分隔的金额:`¥246,675.75`,负数为 `-¥880.00`。
String formatCurrency(DecimalValue value) {
  if (value.isNegative) {
    final abs = DecimalValue.parse(value.value.abs().toString());
    return '-¥${formatAmount(abs)}';
  }
  return '¥${formatAmount(value)}';
}

/// 带显式 `+`/`-` 符号的金额:`+¥1,000.00` / `-¥880.00`。
/// 符号必须与颜色同时出现(国内习惯:红盈利、绿亏损),不能只靠颜色。
String formatSignedCurrency(DecimalValue value) {
  if (value.isNegative) return formatCurrency(value);
  return '+${formatCurrency(value)}';
}

/// [formatCurrency] 的 double 版本,仅供动画中间帧使用。
String formatCurrencyDouble(double value) {
  final abs = value.abs();
  final whole = abs.truncate();
  final frac = ((abs - whole) * 100).round().toString().padLeft(2, '0');
  final grouped = whole.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  final body = '¥$grouped.$frac';
  return value.isNegative ? '-$body' : body;
}

/// [formatSignedCurrency] 的 double 版本,仅供动画中间帧使用。
String formatSignedCurrencyDouble(double value) =>
    value.isNegative ? formatCurrencyDouble(value) : '+${formatCurrencyDouble(value)}';

/// 占比的 double 版本(如 0.452 -> 45.2%),仅供动画中间帧使用。
String formatShareDouble(double value) =>
    '${(value * 100).toStringAsFixed(1)}%';

String _two(int value) => value.toString().padLeft(2, '0');

/// “数据截至”时间:`2026-07-31 14:05`。
String formatAsOf(DateTime at) =>
    '${at.year}-${_two(at.month)}-${_two(at.day)} '
    '${_two(at.hour)}:${_two(at.minute)}';
