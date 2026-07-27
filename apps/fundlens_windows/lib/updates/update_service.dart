import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'update_checker.dart';

/// Thrown when the downloaded installer does not match the manifest digest.
final class UpdateIntegrityException implements Exception {
  const UpdateIntegrityException();

  @override
  String toString() => '下载文件校验失败，已删除';
}

/// Streams bytes for [url] into [destination], reporting
/// `(receivedBytes, totalBytes?)` progress. Injectable so tests never touch
/// the network.
typedef UpdateDownloader = Future<void> Function(
  Uri url,
  File destination,
  void Function(int received, int? total) onProgress,
);

/// The install half of the update flow, abstracted so widget tests never
/// touch the network or the file system.
abstract interface class UpdateInstaller {
  /// Downloads [manifest]'s installer, verifies its SHA-256 against the
  /// manifest and launches it. [onProgress] reports values in `0..1`, or
  /// `null` while the total size is unknown.
  Future<File> downloadVerifiedAndLaunch(
    UpdateManifest manifest, {
    void Function(double? progress)? onProgress,
  });
}

/// Downloads a verified installer and hands it to the OS. The original
/// installer file is opened by the system's own process; nothing else is
/// modified.
final class UpdateService implements UpdateInstaller {
  const UpdateService({
    required this.tempDirectory,
    UpdateDownloader? downloader,
    Future<void> Function(String path)? launcher,
  })  : _downloader = downloader ?? _httpDownload,
        _launcher = launcher ?? _launchDetached;

  final Directory tempDirectory;
  final UpdateDownloader _downloader;
  final Future<void> Function(String path) _launcher;

  /// Downloads [manifest]'s installer, verifies its SHA-256 against the
  /// manifest and launches it. A digest mismatch deletes the download and
  /// throws [UpdateIntegrityException].
  @override
  Future<File> downloadVerifiedAndLaunch(
    UpdateManifest manifest, {
    void Function(double? progress)? onProgress,
  }) async {
    await tempDirectory.create(recursive: true);
    final file = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      'FundLens-Setup-${manifest.version}.exe',
    );
    await _downloader(Uri.parse(manifest.url), file, (received, total) {
      onProgress?.call(
        total == null || total == 0 ? null : received / total,
      );
    });

    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != manifest.sha256.toLowerCase()) {
      await file.delete();
      throw const UpdateIntegrityException();
    }

    await _launcher(file.path);
    return file;
  }

  static Future<void> _httpDownload(
    Uri url,
    File destination,
    void Function(int received, int? total) onProgress,
  ) async {
    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client
          .getUrl(url)
          .timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(
            const Duration(seconds: 15),
        );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: url);
      }
      final total =
          response.contentLength >= 0 ? response.contentLength : null;
      sink = destination.openWrite();
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
    } finally {
      await sink?.close();
      client.close();
    }
  }

  static Future<void> _launchDetached(String path) async {
    // Inno Setup closes the running app itself (CloseApplications) and
    // performs an in-place per-user upgrade; user data under %APPDATA% is
    // untouched.
    await Process.start(path, const [], mode: ProcessStartMode.detached);
  }
}
