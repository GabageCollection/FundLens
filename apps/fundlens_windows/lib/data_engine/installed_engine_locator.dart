import 'dart:io';

import 'package:path/path.dart' as p;

import 'local_engine_process.dart';
import 'process_data_engine_client.dart';

/// Locates the data engine bundled with an installed FundLens build.
///
/// In an installed layout the engine lives at
/// `<install-dir>/fundlens_engine/fundlens_engine.exe`, next to
/// `FundLens.exe`. The locator resolves only that exact location: it never
/// searches `PATH` and never uses the user's own Python installation. When
/// the bundled engine is absent the app is running in development mode and
/// [locate] returns null so callers can fall back to the dev adapter.
final class InstalledEngineLocator {
  const InstalledEngineLocator({this.resolvedExecutable});

  /// Absolute path of the running app executable; defaults to
  /// [Platform.resolvedExecutable]. Injectable for tests.
  final String? resolvedExecutable;

  static const engineDirectoryName = 'fundlens_engine';
  static const engineExecutableName = 'fundlens_engine.exe';

  /// Returns the bundled engine executable path, or null when this is not an
  /// installed bundle (or the bundle layout fails verification).
  String? locate() {
    final appExe = resolvedExecutable ?? Platform.resolvedExecutable;
    final installDir = p.normalize(p.absolute(p.dirname(appExe)));
    final candidate = p.normalize(p.absolute(
      p.join(installDir, engineDirectoryName, engineExecutableName),
    ));
    if (!File(candidate).existsSync()) return null;
    // Verify the candidate really sits inside the install directory after
    // resolving symlinks, so a planted link cannot point the app at an
    // executable elsewhere on the machine.
    try {
      final canonicalInstall = Directory(installDir).resolveSymbolicLinksSync();
      final canonicalCandidate = File(candidate).resolveSymbolicLinksSync();
      if (!p.isWithin(canonicalInstall, canonicalCandidate)) return null;
    } on FileSystemException {
      return null;
    }
    return candidate;
  }
}

/// Starts the bundled engine executable as a supervised child process.
final class InstalledEngineProcessAdapter implements ProcessAdapter {
  const InstalledEngineProcessAdapter({required this.executablePath});

  /// Path previously returned by [InstalledEngineLocator.locate].
  final String executablePath;

  @override
  Future<EngineProcessHandle> start() async {
    final process = await Process.start(
      executablePath,
      const [],
      workingDirectory: p.dirname(executablePath),
    );
    return IoEngineProcessHandle(process);
  }
}
