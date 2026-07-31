import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:fundlens_windows/features/overview/overview_formatters.dart';

void main() {
  group('formatCurrency', () {
    test('金额带币种符号和千位分隔', () {
      expect(
        formatCurrency(DecimalValue.parse('246675.75')),
        '¥246,675.75',
      );
    });

    test('整数金额补两位小数', () {
      expect(formatCurrency(DecimalValue.parse('52340')), '¥52,340.00');
    });

    test('零金额', () {
      expect(formatCurrency(DecimalValue.zero), '¥0.00');
    });

    test('负金额带负号', () {
      expect(formatCurrency(DecimalValue.parse('-880.00')), '-¥880.00');
    });
  });

  group('formatSignedCurrency', () {
    test('正收益带 + 号', () {
      expect(
        formatSignedCurrency(DecimalValue.parse('1000.00')),
        '+¥1,000.00',
      );
    });

    test('负收益带 - 号', () {
      expect(
        formatSignedCurrency(DecimalValue.parse('-880.00')),
        '-¥880.00',
      );
    });

    test('零值视为非负,带 + 号', () {
      expect(formatSignedCurrency(DecimalValue.zero), '+¥0.00');
    });
  });

  group('formatAsOf', () {
    test('格式为 YYYY-MM-DD HH:mm', () {
      expect(
        formatAsOf(DateTime(2026, 7, 31, 14, 5)),
        '2026-07-31 14:05',
      );
    });

    test('月日时分补零', () {
      expect(formatAsOf(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
    });
  });
}
