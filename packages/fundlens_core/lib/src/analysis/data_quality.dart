import '../model/decimal_value.dart';
import '../model/holding.dart';

final class DataQualitySummary {
  const DataQualitySummary({
    required this.dataCompleteness,
    required this.quoteFreshness,
  });
  final DecimalValue dataCompleteness;
  final DecimalValue? quoteFreshness;
}

final class DataQualityCalculator {
  DataQualitySummary calculate(
    List<Holding> holdings, {
    required Set<String> freshQuoteHoldingIds,
  }) {
    var requiredFields = 0;
    var completeFields = 0;
    var quotedValue = DecimalValue.zero;
    var freshQuotedValue = DecimalValue.zero;
    for (final h in holdings) {
      // Base required fields for every holding.
      final checks = <bool>[
        h.productName.trim().isNotEmpty,
        h.currency.trim().isNotEmpty,
        !h.currentValue.isNegative,
      ];
      if (h.valuationMethod == ValuationMethod.automaticQuote) {
        checks.addAll([
          h.productCode != null && h.productCode!.trim().isNotEmpty,
          h.quantity != null,
          h.currentPrice != null,
          h.valuationDate != null,
        ]);
        quotedValue += h.currentValue;
        if (freshQuoteHoldingIds.contains(h.id)) {
          freshQuotedValue += h.currentValue;
        }
      } else if (h.valuationMethod == ValuationMethod.quantityTimesPrice) {
        checks.addAll([
          h.quantity != null,
          h.currentPrice != null,
          h.valuationDate != null,
        ]);
      }
      requiredFields += checks.length;
      completeFields += checks.where((value) => value).length;
    }
    return DataQualitySummary(
      dataCompleteness: requiredFields == 0
          ? DecimalValue.zero
          : DecimalValue.parse(
              completeFields.toString(),
            ).divide(DecimalValue.parse(requiredFields.toString())),
      quoteFreshness: quotedValue.isZero
          ? null
          : freshQuotedValue.divide(quotedValue),
    );
  }
}
