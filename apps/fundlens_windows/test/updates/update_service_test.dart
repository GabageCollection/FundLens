import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/updates/update_checker.dart';
import 'package:fundlens_windows/updates/update_service.dart';

void main() {
  group('UpdateService.downloadVerifiedAndLaunch', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('update_service_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    UpdateManifest manifestFor(List<int> bytes) => UpdateManifest(
          version: '1.1.0',
          url: 'https://example.com/FundLens-Setup.exe',
          sha256: sha256.convert(bytes).toString(),
          notes: '',
        );

    test('launches the installer when the digest matches', () async {
      final bytes = List<int>.generate(1024, (i) => i % 251);
      String? launchedPath;
      double? lastProgress;
      final service = UpdateService(
        tempDirectory: tempDir,
        downloader: (url, destination, onProgress) async {
          await destination.writeAsBytes(bytes);
          onProgress(bytes.length, bytes.length);
        },
        launcher: (path) async => launchedPath = path,
      );

      final file = await service.downloadVerifiedAndLaunch(
        manifestFor(bytes),
        onProgress: (progress) => lastProgress = progress,
      );

      expect(await file.readAsBytes(), bytes);
      expect(launchedPath, file.path);
      expect(lastProgress, 1.0);
    });

    test('deletes the download and throws when the digest mismatches',
        () async {
      final service = UpdateService(
        tempDirectory: tempDir,
        downloader: (url, destination, onProgress) async {
          await destination.writeAsBytes(const [1, 2, 3]);
        },
        launcher: (_) async => fail('must not launch a corrupt installer'),
      );
      final tampered = UpdateManifest(
        version: '1.1.0',
        url: 'https://example.com/FundLens-Setup.exe',
        sha256: sha256.convert(const [9, 9, 9]).toString(),
        notes: '',
      );

      await expectLater(
        service.downloadVerifiedAndLaunch(tampered),
        throwsA(isA<UpdateIntegrityException>()),
      );
      expect(await tempDir.list().isEmpty, isTrue);
    });
  });
}
