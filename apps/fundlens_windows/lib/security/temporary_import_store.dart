import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../features/import_review/import_review_controller.dart';
import 'selected_path_guard.dart';

/// File-based [ScreenshotTempStore] with per-job directories.
///
/// Each import batch gets its own `job-<random>` directory beneath [root];
/// names contain no user content. Copies — never the user's originals —
/// are removed after a successful commit or an explicit discard. On app
/// startup [sweepOrphans] removes job directories older than
/// [orphanMaxAge]; cleanup failures raise a nonblocking privacy issue via
/// [onPrivacyIssue] and are retried on the next launch.
final class TemporaryImportStore implements ScreenshotTempStore {
  TemporaryImportStore({
    required this.root,
    DateTime Function()? clock,
    this.onPrivacyIssue,
    Future<void> Function(Directory directory)? deleteDirectory,
  })  : _clock = clock ?? DateTime.now,
        _deleteDirectory = deleteDirectory ?? _defaultDelete;

  /// Issue code reported when a job directory cannot be removed.
  static const cleanupFailedIssue = 'privacy.temp_cleanup_failed';

  /// Orphaned job directories older than this are removed on startup.
  static const orphanMaxAge = Duration(hours: 24);

  /// Parent directory beneath which per-job directories are created.
  final Directory root;

  final DateTime Function() _clock;
  /// Receives [cleanupFailedIssue] when a job directory cannot be removed.
  final void Function(String issueCode)? onPrivacyIssue;
  final Future<void> Function(Directory directory) _deleteDirectory;

  static Future<void> _defaultDelete(Directory directory) =>
      directory.delete(recursive: true);

  @override
  Future<List<String>> copyToTemp(List<String> sourcePaths) async {
    await root.create(recursive: true);
    final suffix = Random.secure().nextInt(0xFFFFFFFF).toRadixString(16);
    final job = Directory(p.join(root.path, 'job-$suffix'));
    await job.create();
    _restrictPermissions(job);
    const guard = SelectedPathGuard();
    final tempPaths = <String>[];
    for (var i = 0; i < sourcePaths.length; i++) {
      final source = File(guard.canonicalize(sourcePaths[i]));
      final destination = p.join(
        job.path,
        'page_$i${p.extension(source.path)}',
      );
      await source.copy(destination);
      tempPaths.add(destination);
    }
    return tempPaths;
  }

  @override
  Future<void> clear(List<String> tempPaths) async {
    final jobDirs = <String>{};
    for (final tempPath in tempPaths) {
      final parent = p.dirname(tempPath);
      if (p.isWithin(root.path, parent) &&
          p.basename(parent).startsWith('job-')) {
        jobDirs.add(parent);
      }
    }
    for (final dir in jobDirs) {
      await _removeDirectory(Directory(dir));
    }
  }

  /// Removes orphaned job directories older than [orphanMaxAge] and returns
  /// how many were removed.
  ///
  /// Entries that are not `job-*` directories are left untouched; failures
  /// are reported as privacy issues and retried on the next launch.
  Future<int> sweepOrphans() async {
    if (!await root.exists()) return 0;
    final cutoff = _clock().subtract(orphanMaxAge);
    var removed = 0;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      if (!p.basename(entity.path).startsWith('job-')) continue;
      final modified = (await entity.stat()).modified;
      if (modified.isAfter(cutoff)) continue;
      if (await _removeDirectory(entity)) removed++;
    }
    return removed;
  }

  /// Returns true when [dir] was actually removed. Failures are nonblocking:
  /// the directory stays and cleanup is retried later.
  Future<bool> _removeDirectory(Directory dir) async {
    if (!await dir.exists()) return false;
    try {
      await _deleteDirectory(dir);
      return true;
    } catch (_) {
      onPrivacyIssue?.call(cleanupFailedIssue);
      return false;
    }
  }

  /// Best-effort owner-only permissions where the platform supports it.
  void _restrictPermissions(Directory dir) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', ['700', dir.path]);
    } catch (_) {
      // Restrictive permissions are best-effort only.
    }
  }
}
