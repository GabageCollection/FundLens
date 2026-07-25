import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/security/redacting_logger.dart';

void main() {
  group('RedactingLogger', () {
    final logger = RedactingLogger(
      schemas: {
        'import.failed': {'issue_count'},
        'import.committed': {'holding_count', 'duration_ms'},
      },
    );

    test('logger removes money, OCR text, keys and passwords', () {
      final output = logger.format('import.failed', {
        'amount': '78347.87',
        'ocr_text': '脱敏基金 +428.96',
        'database_key': 'abcd',
        'password': 'secret',
        'issue_count': 2,
      });
      expect(output, isNot(contains('78347.87')));
      expect(output, isNot(contains('脱敏基金')));
      expect(output, isNot(contains('abcd')));
      expect(output, isNot(contains('secret')));
      expect(output, contains('"issue_count":2'));
    });

    test('every always-redacted key is replaced with [REDACTED]', () {
      final output = logger.format('import.failed', {
        'amount': '1.00',
        'value': '2.00',
        'profit': '3.00',
        'ocr_text': 'text',
        'screenshot': 'C:/shots/a.png',
        'database_key': 'ff' * 32,
        'backup_password': 'pw1',
        'password': 'pw2',
        'issue_count': 0,
      });

      final decoded = jsonDecode(output) as Map<String, Object?>;
      final fields = decoded['fields'] as Map<String, Object?>;
      for (final key in RedactingLogger.alwaysRedactedKeys) {
        expect(fields[key], '[REDACTED]', reason: '$key must be redacted');
      }
    });

    test('unknown fields are dropped, never included', () {
      final output = logger.format('import.failed', {
        'issue_count': 1,
        'holdings_dump': 'FundA 1000.00',
        'raw_row': '脱敏基金 +428.96',
      });

      expect(output, isNot(contains('holdings_dump')));
      expect(output, isNot(contains('raw_row')));
      expect(output, isNot(contains('FundA')));
    });

    test('registered fields pass through unchanged', () {
      final output = logger.format('import.committed', {
        'holding_count': 3,
        'duration_ms': 42,
      });

      final decoded = jsonDecode(output) as Map<String, Object?>;
      expect(decoded['event'], 'import.committed');
      final fields = decoded['fields'] as Map<String, Object?>;
      expect(fields, {'holding_count': 3, 'duration_ms': 42});
    });

    test('rejects unregistered event codes', () {
      expect(
        () => logger.format('import.debug', {'issue_count': 1}),
        throwsArgumentError,
      );
    });
  });
}
