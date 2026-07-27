import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/updates/update_checker.dart';

void main() {
  group('compareVersions', () {
    test('orders dotted numeric versions', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('1.10.0', '1.9.2'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.1', '1.1.0'), 0);
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('ignores build metadata and pre-release suffixes', () {
      expect(compareVersions('1.0.0+2', '1.0.0'), 0);
      expect(compareVersions('1.2.0-beta', '1.2.0'), 0);
    });
  });

  group('UpdateManifest.fromJson', () {
    test('parses a complete manifest', () {
      final manifest = UpdateManifest.fromJson(const {
        'version': '1.1.0',
        'url': 'https://example.com/FundLens-Setup.exe',
        'sha256': 'ABCD',
        'notes': '修复若干问题',
      });
      expect(manifest.version, '1.1.0');
      expect(manifest.sha256, 'abcd');
      expect(manifest.notes, '修复若干问题');
    });

    test('rejects manifests without version/url/sha256', () {
      expect(
        () => UpdateManifest.fromJson(const {'version': '1.1.0'}),
        throwsFormatException,
      );
    });
  });

  group('UpdateChecker.check', () {
    const manifestJson = '''
      {
        "version": "1.1.0",
        "url": "https://example.com/FundLens-Setup-1.1.0.exe",
        "sha256": "deadbeef",
        "notes": "n"
      }
      ''';

    test('is disabled and offline when no manifest url is configured', () async {
      const checker = UpdateChecker(manifestUrl: '', currentVersion: '1.0.0');
      expect(await checker.check(), isA<UpdateCheckDisabled>());
    });

    test('reports an update when the manifest version is newer', () async {
      final checker = UpdateChecker(
        manifestUrl: 'https://example.com/version.json',
        currentVersion: '1.0.0',
        fetcher: (_) async => manifestJson,
      );
      final result = await checker.check();
      expect(result, isA<UpdateAvailable>());
      expect((result as UpdateAvailable).manifest.version, '1.1.0');
      expect(result.currentVersion, '1.0.0');
    });

    test('reports up-to-date when the manifest is not newer', () async {
      final checker = UpdateChecker(
        manifestUrl: 'https://example.com/version.json',
        currentVersion: '1.1.0',
        fetcher: (_) async => manifestJson,
      );
      expect(await checker.check(), isA<UpdateUpToDate>());
    });

    test('fails cleanly on malformed json', () async {
      final checker = UpdateChecker(
        manifestUrl: 'https://example.com/version.json',
        currentVersion: '1.0.0',
        fetcher: (_) async => 'not json',
      );
      expect(await checker.check(), isA<UpdateCheckFailed>());
    });

    test('fails cleanly when the fetch throws', () async {
      final checker = UpdateChecker(
        manifestUrl: 'https://example.com/version.json',
        currentVersion: '1.0.0',
        fetcher: (_) async => throw Exception('offline'),
      );
      expect(await checker.check(), isA<UpdateCheckFailed>());
    });
  });
}
