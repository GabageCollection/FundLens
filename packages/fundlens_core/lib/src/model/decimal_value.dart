import 'package:decimal/decimal.dart';

final class DecimalValue implements Comparable<DecimalValue> {
  DecimalValue._(this.value);
  final Decimal value;

  factory DecimalValue.parse(String source) {
    final parsed = Decimal.parse(source);
    return DecimalValue._(parsed == Decimal.zero ? Decimal.zero : parsed);
  }

  static final zero = DecimalValue._(Decimal.zero);
  String get canonical => value.toString();
  DecimalValue operator +(DecimalValue other) =>
      DecimalValue._(value + other.value);
  DecimalValue operator -(DecimalValue other) =>
      DecimalValue._(value - other.value);
  DecimalValue operator *(DecimalValue other) =>
      DecimalValue._(value * other.value);
  DecimalValue divide(DecimalValue other, {int scale = 8}) => DecimalValue._(
    (value / other.value).toDecimal(scaleOnInfinitePrecision: scale),
  );
  bool get isZero => value == Decimal.zero;
  bool get isNegative => value < Decimal.zero;
  @override
  int compareTo(DecimalValue other) => value.compareTo(other.value);
  @override
  bool operator ==(Object other) =>
      other is DecimalValue && value == other.value;
  @override
  int get hashCode => value.hashCode;
}
