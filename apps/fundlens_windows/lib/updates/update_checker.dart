import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Configuration for the self-update check.
///
/// [kUpdateManifestUrl] points at a static JSON manifest hosted next to the
/// released installers. It can be set at build time:
///
/// ```
/// flutter build windows --release \
///   --dart-define=FUNDLENS_UPDATE_MANIFEST_URL=https://example.com/fundlens/version.json
/// ```
///
/// When empty, the update check is disabled and the settings UI says so
/// instead of making any network request.
const String kUpdateManifestUrl = String.fromEnvironment(
  'FUNDLENS_UPDATE_MANIFEST_URL',
  defaultValue: '',
);

/// The update manifest published next to release installers.
///
/// ```json
/// {
///   "version": "1.1.0",
///   "url": "https://example.com/fundlens/FundLens-Setup-1.1.0.exe",
///   "sha256": "<hex digest of the installer>",
///   "notes": "简短更新说明"
/// }
/// ```
final class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.url,
    required this.sha256,
    required this.notes,
  });

  final String version;
  final String url;
  final String sha256;
  final String notes;

  factory UpdateManifest.fromJson(Map<String, Object?> json) {
    final version = json['version'] as String? ?? '';
    final url = json['url'] as String? ?? '';
    final sha256 = json['sha256'] as String? ?? '';
    if (version.isEmpty || url.isEmpty || sha256.isEmpty) {
      throw const FormatException('update manifest requires version/url/sha256');
    }
    return UpdateManifest(
      version: version,
      url: url,
      sha256: sha256.toLowerCase(),
      notes: json['notes'] as String? ?? '',
    );
  }
}

/// Compares two dotted numeric versions (`1.10.0` > `1.9.2`). Build metadata
/// (`+x`) and pre-release suffixes (`-x`) are ignored; missing segments count
/// as zero. Unparseable segments compare as zero.
int compareVersions(String a, String b) {
  List<int> segments(String v) => [
        for (final part in v.split(RegExp('[-+]')).first.split('.'))
          int.tryParse(part) ?? 0,
      ];
  final left = segments(a);
  final right = segments(b);
  final length =
      left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// Outcome of one update check.
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

/// No manifest URL is configured; no network request was made.
final class UpdateCheckDisabled extends UpdateCheckResult {
  const UpdateCheckDisabled();
}

final class UpdateUpToDate extends UpdateCheckResult {
  const UpdateUpToDate(this.currentVersion);
  final String currentVersion;
}

final class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.manifest, this.currentVersion);
  final UpdateManifest manifest;
  final String currentVersion;
}

final class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed(this.message);
  final String message;
}

/// Fetches the update manifest and compares it with the running version.
/// The fetcher is injectable so tests never touch the network.
final class UpdateChecker {
  const UpdateChecker({
    required this.manifestUrl,
    required this.currentVersion,
    Future<String> Function(Uri url)? fetcher,
  }) : _fetcher = fetcher ?? _httpGet;

  final String manifestUrl;
  final String currentVersion;
  final Future<String> Function(Uri url) _fetcher;

  Future<UpdateCheckResult> check() async {
    final url = manifestUrl.trim();
    if (url.isEmpty) return const UpdateCheckDisabled();
    try {
      final body = await _fetcher(Uri.parse(url));
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return const UpdateCheckFailed('更新清单格式错误');
      }
      final manifest = UpdateManifest.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (compareVersions(manifest.version, currentVersion) <= 0) {
        return UpdateUpToDate(currentVersion);
      }
      return UpdateAvailable(manifest, currentVersion);
    } on FormatException {
      return const UpdateCheckFailed('更新清单格式错误');
    } on Exception catch (e) {
      return UpdateCheckFailed('检查更新失败: $e');
    }
  }

  static Future<String> _httpGet(Uri url) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 10));
      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }
}
