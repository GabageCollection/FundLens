import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/l10n/copy_registry.dart';

/// Forbidden wording: allocation advice, transaction verbs and return
/// mislabeling are never allowed in user-facing copy.
const forbiddenPhrases = [
  '再平衡建议',
  '调仓建议',
  '建议买入',
  '建议卖出',
  '快照收益',
  '理想比例',
  '买入',
  '卖出',
  '加仓',
  '减仓',
  '调仓',
  '再平衡',
];

void main() {
  test('localized copy has no advice or return mislabeling', () {
    expect(allChineseCopy, isNotEmpty);
    for (final phrase in forbiddenPhrases) {
      expect(
        allChineseCopy.contains(phrase),
        isFalse,
        reason: 'registry must not contain "$phrase"',
      );
    }
    for (final entry in allChineseCopy) {
      for (final phrase in forbiddenPhrases) {
        expect(
          entry.contains(phrase),
          isFalse,
          reason: 'copy "$entry" contains forbidden "$phrase"',
        );
      }
    }
  });

  test('lib sources contain no forbidden user-facing wording', () {
    final libDir = Directory('lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    expect(dartFiles, isNotEmpty);
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      for (final phrase in forbiddenPhrases) {
        expect(
          content.contains(phrase),
          isFalse,
          reason: '${file.path} contains forbidden "$phrase"',
        );
      }
    }
  });
}
