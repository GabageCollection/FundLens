import 'package:fundlens_core/fundlens_core.dart';

import 'analysis_labels.dart';

/// 分析页的三个构成维度,展示形态见 Task 3。
enum AnalysisDimension { assetClass, instrumentType, source }

const dimensionLabels = <AnalysisDimension, String>{
  AnalysisDimension.assetClass: '资产类别',
  AnalysisDimension.instrumentType: '产品类型',
  AnalysisDimension.source: '来源平台',
};

/// 图表中的一行:分组名称、金额、占总资产比例与是否"其他"聚合行。
final class ChartBarRow {
  const ChartBarRow({
    required this.label,
    required this.amount,
    required this.share,
    this.isAggregate = false,
  });

  final String label;

  /// 该分组当前金额(DecimalValue,不在此处转浮点)。
  final DecimalValue amount;

  /// 占总资产比例 0..1。
  final DecimalValue share;

  /// 超过 6 项时占比最小的类别合并为"其他"聚合行。
  final bool isAggregate;
}

/// 按维度生成图表行:零金额过滤 → 金额降序 → ≤6 全显,>6 前 5 + 合并"其他"。
List<ChartBarRow> buildChartRows(
  PortfolioSummary summary,
  AnalysisDimension dimension,
) {
  final raw = <(String, DecimalValue)>[];
  switch (dimension) {
    case AnalysisDimension.assetClass:
      for (final entry in summary.byAssetClass.entries) {
        if (!entry.value.isZero) {
          raw.add((assetClassLabels[entry.key]!, entry.value));
        }
      }
    case AnalysisDimension.instrumentType:
      for (final entry in summary.byInstrumentType.entries) {
        if (!entry.value.isZero) {
          raw.add((instrumentTypeLabels[entry.key]!, entry.value));
        }
      }
    case AnalysisDimension.source:
      for (final entry in summary.bySource.entries) {
        if (!entry.value.isZero) {
          raw.add((sourcePlatformLabels[entry.key]!, entry.value));
        }
      }
  }
  raw.sort((a, b) => b.$2.compareTo(a.$2));

  final total = summary.totalValue;
  DecimalValue shareOf(DecimalValue amount) =>
      total.isZero ? DecimalValue.zero : amount.divide(total);

  if (raw.length <= 6) {
    return [
      for (final (label, amount) in raw)
        ChartBarRow(label: label, amount: amount, share: shareOf(amount)),
    ];
  }
  final kept = raw.take(5).toList();
  final mergedAmount = raw
      .skip(5)
      .fold(DecimalValue.zero, (sum, entry) => sum + entry.$2);
  return [
    for (final (label, amount) in kept)
      ChartBarRow(label: label, amount: amount, share: shareOf(amount)),
    ChartBarRow(
      label: '其他',
      amount: mergedAmount,
      share: shareOf(mergedAmount),
      isAggregate: true,
    ),
  ];
}
