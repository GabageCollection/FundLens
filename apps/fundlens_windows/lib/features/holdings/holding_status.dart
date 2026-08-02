import 'package:fundlens_core/fundlens_core.dart';

/// 持仓数据状态(数据状态列与筛选器共用)。
///
/// 派生优先级见 [deriveHoldingDataStatus];文案全部使用 muted 文字,
/// 不使用高饱和色块。
enum HoldingDataStatus { incomplete, noQuote, staleQuote, missingCost, normal }

/// 数据状态的中文标签。
const holdingDataStatusLabels = <HoldingDataStatus, String>{
  HoldingDataStatus.incomplete: '未填写',
  HoldingDataStatus.noQuote: '暂无行情',
  HoldingDataStatus.staleQuote: '等待更新',
  HoldingDataStatus.missingCost: '缺少成本',
  HoldingDataStatus.normal: '正常',
};

bool _isQuoteBased(Holding h) {
  return h.valuationMethod == ValuationMethod.automaticQuote ||
      h.valuationMethod == ValuationMethod.quantityTimesPrice;
}

/// 派生单条持仓的数据状态,优先级从上到下(高优先级先命中):
///
/// 1. 未填写:用户提供的必填字段缺失(名称/币种/金额为负/行情类缺代码或份额)。
/// 2. 暂无行情:行情类缺少现价或估值日期(行情侧数据,不归入"未填写")。
/// 3. 等待更新:自动行情持仓不在本次刷新集合中。
/// 4. 缺少成本:无有效成本,无法纳入收益统计。
/// 5. 正常。
HoldingDataStatus deriveHoldingDataStatus(
  Holding holding, {
  required Set<String> freshQuoteHoldingIds,
}) {
  if (holding.productName.trim().isEmpty ||
      holding.currency.trim().isEmpty ||
      holding.currentValue.isNegative) {
    return HoldingDataStatus.incomplete;
  }
  if (holding.valuationMethod == ValuationMethod.automaticQuote &&
      (holding.productCode == null ||
          holding.productCode!.trim().isEmpty ||
          holding.quantity == null)) {
    return HoldingDataStatus.incomplete;
  }
  if (holding.valuationMethod == ValuationMethod.quantityTimesPrice &&
      holding.quantity == null) {
    return HoldingDataStatus.incomplete;
  }
  if (_isQuoteBased(holding) &&
      (holding.currentPrice == null || holding.valuationDate == null)) {
    return HoldingDataStatus.noQuote;
  }
  if (holding.valuationMethod == ValuationMethod.automaticQuote &&
      !freshQuoteHoldingIds.contains(holding.id)) {
    return HoldingDataStatus.staleQuote;
  }
  if (holding.effectiveCostAmount == null) {
    return HoldingDataStatus.missingCost;
  }
  return HoldingDataStatus.normal;
}

/// 持仓的有效收益率:优先取平台值,否则由 盈亏÷有效成本 推导。
DecimalValue? holdingEffectiveReturn(Holding holding) {
  if (holding.holdingReturn != null) return holding.holdingReturn;
  final cost = holding.effectiveCostAmount;
  final profit = holding.currentFloatingProfit;
  if (cost == null || cost.isZero || profit == null) return null;
  return profit.divide(cost);
}

/// 份额单元格文案。
String holdingQuantityText(Holding h) {
  if (h.valuationMethod == ValuationMethod.manualAmount) return '不适用';
  if (h.quantity == null) return '暂无行情';
  return HoldingValueFormatter.number(h.quantity);
}

/// 现价单元格文案。
String holdingPriceText(Holding h) {
  if (h.valuationMethod == ValuationMethod.manualAmount) return '不适用';
  if (h.currentPrice == null) return '暂无行情';
  return HoldingValueFormatter.number(h.currentPrice);
}

/// 覆盖成本单元格文案。
String holdingCostText(Holding h) {
  if (h.costAmount == null) return '缺少成本';
  return HoldingValueFormatter.amount(h.costAmount);
}

/// 持仓盈亏单元格文案(红绿由样式层处理,此处只管数值与符号)。
String holdingProfitText(Holding h) {
  final profit = h.currentFloatingProfit;
  if (profit == null) return '缺少成本';
  return HoldingValueFormatter.signedAmount(profit);
}

/// 持仓收益率单元格文案。
String holdingReturnText(Holding h) {
  final value = holdingEffectiveReturn(h);
  if (value == null) return '缺少成本';
  return HoldingValueFormatter.signedPercent(value);
}

/// 估值日期单元格文案。
String holdingValuationDateText(Holding h) {
  if (h.valuationDate == null) {
    return _isQuoteBased(h) ? '暂无行情' : '不适用';
  }
  return HoldingValueFormatter.date(h.valuationDate);
}

/// 资产占比单元格文案;组合总额为 0 时由调用方传 null。
String holdingShareText(DecimalValue? share) {
  if (share == null) return '不适用';
  return HoldingValueFormatter.percent(share);
}

/// 表格数值格式化。从 holding_grid.dart 原样迁移,并新增 [percent]。
///
/// 行组件不计算金融指标,只渲染 [Holding] 上已有的值。
abstract final class HoldingValueFormatter {
  /// `1234567.8` → `1,234,567.80`;负值保留负号。金额固定至少两位小数。
  static String amount(DecimalValue? value) {
    if (value == null) return '—';
    return _grouped(value.canonical, padFractionToTwo: true);
  }

  /// 不带强制小数的千分位数值(份额、价格)。
  static String number(DecimalValue? value) {
    if (value == null) return '—';
    return _grouped(value.canonical);
  }

  /// 带符号百分比:`0.125` → `+12.50%`。始终带 +/-,盈亏不靠颜色区分。
  static String signedPercent(DecimalValue? value) {
    if (value == null) return '—';
    final canonical = value.canonical;
    final parsed = double.tryParse(canonical);
    if (parsed == null) return '—';
    final percent = parsed * 100;
    final sign = percent < 0 ? '-' : '+';
    return '$sign${percent.abs().toStringAsFixed(2)}%';
  }

  /// 无符号百分比(资产占比):`0.1234` → `12.34%`。
  static String percent(DecimalValue? value) {
    if (value == null) return '—';
    final parsed = double.tryParse(value.canonical);
    if (parsed == null) return '—';
    return '${(parsed * 100).toStringAsFixed(2)}%';
  }

  /// 带符号金额(盈亏)。
  static String signedAmount(DecimalValue? value) {
    if (value == null) return '—';
    if (value.isNegative) return amount(value);
    return '+${amount(value)}';
  }

  static String date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toUtc();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 整数部分按千分位分组;`padFractionToTwo` 时金额小数不足两位补零。
  static String _grouped(String canonical, {bool padFractionToTwo = false}) {
    final negative = canonical.startsWith('-');
    final body = negative ? canonical.substring(1) : canonical;
    final dot = body.indexOf('.');
    final integer = dot == -1 ? body : body.substring(0, dot);
    var fraction = dot == -1 ? '' : body.substring(dot);
    if (padFractionToTwo) {
      if (fraction.isEmpty) {
        fraction = '.00';
      } else if (fraction.length == 2) {
        fraction = '${fraction}0';
      }
    }
    final buffer = StringBuffer();
    for (var i = 0; i < integer.length; i++) {
      final remaining = integer.length - i;
      buffer.write(integer[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }
    return '${negative ? '-' : ''}$buffer$fraction';
  }
}
