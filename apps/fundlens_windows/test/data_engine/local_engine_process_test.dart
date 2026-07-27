import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/data_engine/local_engine_process.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalEngineProcessAdapter environment', () {
    test('points PADDLE_PDX_CACHE_HOME at engine/models so the dev engine '
        'reuses the models staged by build_engine.ps1 instead of '
        're-downloading them into the user cache', () {
      const adapter =
          LocalEngineProcessAdapter(engineDirectory: 'D:/repo/engine');
      final env = adapter.debugProcessEnvironment(const {});
      expect(
        p.normalize(env['PADDLE_PDX_CACHE_HOME']!),
        p.normalize(p.join('D:/repo/engine', 'models')),
      );
      expect(env['PYTHONPATH'], 'src');
    });

    test('keeps an explicit user PADDLE_PDX_CACHE_HOME (mirrors the '
        'runtime-hook setdefault semantics)', () {
      const adapter =
          LocalEngineProcessAdapter(engineDirectory: 'D:/repo/engine');
      final env = adapter.debugProcessEnvironment(
        const {'PADDLE_PDX_CACHE_HOME': 'C:/custom-cache'},
      );
      expect(env['PADDLE_PDX_CACHE_HOME'], 'C:/custom-cache');
    });
  });
}
