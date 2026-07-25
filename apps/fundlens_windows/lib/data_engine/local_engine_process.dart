import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'process_data_engine_client.dart';

/// [EngineProcessHandle] backed by a real child [Process].
final class IoEngineProcessHandle implements EngineProcessHandle {
  IoEngineProcessHandle(this._process);

  final Process _process;

  @override
  late final Stream<String> stdoutLines = _process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .asBroadcastStream();

  @override
  late final Stream<String> stderrLines = _process.stderr
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .asBroadcastStream();

  @override
  Future<int> get exitFuture => _process.exitCode;

  @override
  void writeLine(String line) {
    _process.stdin.writeln(line);
  }

  @override
  Future<void> kill() async {
    _process.kill();
    await _process.exitCode;
  }
}

/// Starts the local Python data engine (`python -m fundlens_engine`) as a
/// supervised child process.
///
/// The interpreter path defaults to the repository's `engine/.venv`; set the
/// `FUNDLENS_ENGINE_PYTHON` environment variable to override it.
final class LocalEngineProcessAdapter implements ProcessAdapter {
  const LocalEngineProcessAdapter({
    required this.engineDirectory,
    this.pythonExecutable,
  });

  /// Repository `engine/` directory; `src` is added to `PYTHONPATH`.
  final String engineDirectory;

  /// Python interpreter; defaults to the engine venv (`Scripts/python.exe`
  /// on Windows, `bin/python` elsewhere) under [engineDirectory], with the
  /// `FUNDLENS_ENGINE_PYTHON` environment variable taking precedence.
  final String? pythonExecutable;

  String get _resolvedPython {
    final fromEnv = Platform.environment['FUNDLENS_ENGINE_PYTHON'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    if (pythonExecutable != null) return pythonExecutable!;
    final scriptsDir = Platform.isWindows ? 'Scripts' : 'bin';
    final executable = Platform.isWindows ? 'python.exe' : 'python';
    return '$engineDirectory/.venv/$scriptsDir/$executable';
  }

  @override
  Future<EngineProcessHandle> start() async {
    final process = await Process.start(
      _resolvedPython,
      const ['-m', 'fundlens_engine'],
      workingDirectory: engineDirectory,
      environment: {'PYTHONPATH': 'src'},
    );
    return IoEngineProcessHandle(process);
  }
}
