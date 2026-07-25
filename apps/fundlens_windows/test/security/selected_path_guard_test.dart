import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/security/selected_path_guard.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SelectedPathGuard', () {
    const guard = SelectedPathGuard();

    test('resolves dot segments and returns an absolute path', () {
      final base = Directory.systemTemp.path;
      final input = p.join(base, 'sub', '..', 'shot.png');

      final result = guard.canonicalize(input);

      expect(p.isAbsolute(result), isTrue);
      expect(result, p.canonicalize(p.join(base, 'shot.png')));
      expect(result, isNot(contains('..')));
    });

    test('makes relative paths absolute', () {
      final result = guard.canonicalize('shot.png');

      expect(p.isAbsolute(result), isTrue);
      expect(result, p.canonicalize('shot.png'));
    });

    test('normalizes separator style consistently', () {
      final base = Directory.systemTemp.path;
      final forward = p.join(base, 'a.png').replaceAll('\\', '/');
      final backward = p.join(base, 'a.png').replaceAll('/', '\\');

      expect(guard.canonicalize(forward), guard.canonicalize(backward));
    });

    test('rejects empty and blank paths', () {
      expect(() => guard.canonicalize(''), throwsArgumentError);
      expect(() => guard.canonicalize('   '), throwsArgumentError);
    });

    test('canonicalizeAll maps every selected path', () {
      final base = Directory.systemTemp.path;
      final inputs = [
        p.join(base, 'one.png'),
        p.join(base, 'sub', '..', 'two.png'),
      ];

      final results = guard.canonicalizeAll(inputs);

      expect(results, [
        p.canonicalize(p.join(base, 'one.png')),
        p.canonicalize(p.join(base, 'two.png')),
      ]);
    });
  });
}
