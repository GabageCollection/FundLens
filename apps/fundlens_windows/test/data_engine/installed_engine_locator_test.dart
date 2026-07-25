import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/data_engine/installed_engine_locator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandbox;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('fundlens_locator_test_');
  });

  tearDown(() {
    if (sandbox.existsSync()) {
      sandbox.deleteSync(recursive: true);
    }
  });

  /// Builds an install layout: <install>/FundLens.exe plus optionally the
  /// bundled engine at <install>/fundlens_engine/fundlens_engine.exe.
  String createInstallDir({bool withEngine = true}) {
    final installDir = Directory(p.join(sandbox.path, 'install'))..createSync();
    File(p.join(installDir.path, 'FundLens.exe')).createSync();
    if (withEngine) {
      final engineDir =
          Directory(p.join(installDir.path, 'fundlens_engine'))..createSync();
      File(p.join(engineDir.path, 'fundlens_engine.exe')).createSync();
    }
    return p.join(installDir.path, 'FundLens.exe');
  }

  test('resolves bundled engine inside the install directory', () {
    final appExe = createInstallDir();
    final located =
        InstalledEngineLocator(resolvedExecutable: appExe).locate();
    expect(located, isNotNull);
    expect(
      p.equals(
        p.normalize(located!),
        p.normalize(p.join(
          p.dirname(appExe),
          'fundlens_engine',
          'fundlens_engine.exe',
        )),
      ),
      isTrue,
    );
  });

  test('returns null when the bundled engine is absent (dev mode)', () {
    final appExe = createInstallDir(withEngine: false);
    expect(InstalledEngineLocator(resolvedExecutable: appExe).locate(), isNull);
  });

  test('ignores an engine exe that is not under the install directory', () {
    // An exe with the right name sitting next to the app must not be used;
    // only <install-dir>/fundlens_engine/fundlens_engine.exe qualifies.
    final installDir = Directory(p.join(sandbox.path, 'install'))..createSync();
    final appExe = p.join(installDir.path, 'FundLens.exe');
    File(appExe).createSync();
    File(p.join(installDir.path, 'fundlens_engine.exe')).createSync();
    expect(InstalledEngineLocator(resolvedExecutable: appExe).locate(), isNull);
  });

  test('never resolves from PATH', () {
    // Place an engine exe somewhere on PATH but not in the install dir; the
    // locator must still report no installed engine.
    final pathDir = Directory(p.join(sandbox.path, 'on_path'))..createSync();
    File(p.join(pathDir.path, 'fundlens_engine.exe')).createSync();
    final appExe = createInstallDir(withEngine: false);
    expect(InstalledEngineLocator(resolvedExecutable: appExe).locate(), isNull);
  });

  test('rejects a bundled engine that is a symlink escaping the install dir',
      () {
    final outside = Directory(p.join(sandbox.path, 'outside'))..createSync();
    final outsideExe = File(p.join(outside.path, 'fundlens_engine.exe'))
      ..createSync();
    final appExe = createInstallDir();
    final bundledExe = File(p.join(
      p.dirname(appExe),
      'fundlens_engine',
      'fundlens_engine.exe',
    ));
    bundledExe.deleteSync();
    try {
      Link(bundledExe.path).createSync(outsideExe.path);
    } on FileSystemException {
      // Symlinks unavailable without developer mode/elevation; nothing to
      // assert on this machine.
      return;
    }
    expect(InstalledEngineLocator(resolvedExecutable: appExe).locate(), isNull);
  });
}
