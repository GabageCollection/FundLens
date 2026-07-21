import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract test: the shared protocol v1 fixtures must carry a valid
/// JSON-RPC envelope that the Dart client accepts (mirrors the Python
/// `test_schema_fixtures.py` checks on the Dart side).
void main() {
  final fixturesDir = Directory('../../schemas/fixtures');

  group('engine protocol v1 fixtures (Dart contract)', () {
    test('fixtures exist and parse as JSON objects', () {
      final files = fixturesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(files.length, greaterThanOrEqualTo(3));
      for (final file in files) {
        final decoded = jsonDecode(file.readAsStringSync());
        expect(decoded, isA<Map<String, dynamic>>(), reason: file.path);
      }
    });

    test('every fixture declares the version-one envelope', () {
      for (final file in fixturesDir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.json')) continue;
        final envelope =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        expect(envelope['jsonrpc'], '2.0', reason: file.path);
        expect(envelope['schema_version'], 1, reason: file.path);
        expect(envelope['id'], isA<String>(), reason: file.path);
        expect((envelope['id'] as String), isNotEmpty, reason: file.path);
        // Exactly one of result/error, matching the strict envelope.
        final hasResult = envelope.containsKey('result');
        final hasError = envelope.containsKey('error');
        expect(hasResult != hasError, isTrue, reason: file.path);
        if (hasResult) {
          expect(envelope['result'], isA<Map<String, dynamic>>(),
              reason: file.path);
        }
        if (hasError) {
          final error = envelope['error'] as Map<String, dynamic>;
          expect(error.keys,
              containsAll(['code', 'message', 'retryable', 'details']),
              reason: file.path);
        }
      }
    });
  });
}
