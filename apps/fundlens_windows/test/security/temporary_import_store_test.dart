import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fundlens_windows/security/temporary_import_store.dart';
import 'package:path/path.dart' as p;

void main() {
  group('TemporaryImportStore', () {
    late Directory root;
    late Directory sourceDir;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('fundlens_import_root_');
      sourceDir =
          await Directory.systemTemp.createTemp('fundlens_import_source_');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
      if (await sourceDir.exists()) await sourceDir.delete(recursive: true);
    });

    Future<String> makeSource(String name, [List<int>? bytes]) async {
      final file = File(p.join(sourceDir.path, name));
      await file.writeAsBytes(bytes ?? [1, 2, 3]);
      return file.path;
    }

    test('copyToTemp copies into a per-job directory with content-free names',
        () async {
      final store = TemporaryImportStore(root: root);
      final source = await makeSource('我的截图-账户A.png');

      final tempPaths = await store.copyToTemp([source]);

      expect(tempPaths, hasLength(1));
      final temp = File(tempPaths.first);
      expect(await temp.exists(), isTrue);
      expect(await temp.readAsBytes(), [1, 2, 3]);
      expect(p.isWithin(root.path, tempPaths.first), isTrue);
      final jobName = p.basename(p.dirname(tempPaths.first));
      expect(jobName, startsWith('job-'));
      expect(tempPaths.first, isNot(contains('账户')));
      expect(tempPaths.first, isNot(contains('我的截图')));
      // The user's original file is never touched.
      expect(await File(source).exists(), isTrue);
    });

    test('clear removes the whole job directory after commit or discard',
        () async {
      final store = TemporaryImportStore(root: root);
      final tempPaths = await store.copyToTemp([
        await makeSource('a.png'),
        await makeSource('b.png'),
      ]);
      final jobDir = Directory(p.dirname(tempPaths.first));

      await store.clear(tempPaths);

      expect(await jobDir.exists(), isFalse);
    });

    test('clear failure is a nonblocking privacy issue kept for retry',
        () async {
      var failDeletes = true;
      final issues = <String>[];
      final store = TemporaryImportStore(
        root: root,
        onPrivacyIssue: issues.add,
        deleteDirectory: (dir) async {
          if (failDeletes) throw const FileSystemException('locked');
          await dir.delete(recursive: true);
        },
      );
      final tempPaths = await store.copyToTemp([await makeSource('a.png')]);
      final jobDir = Directory(p.dirname(tempPaths.first));

      await store.clear(tempPaths);

      expect(issues, [TemporaryImportStore.cleanupFailedIssue]);
      expect(await jobDir.exists(), isTrue);

      // Retry succeeds once the deletion works again.
      failDeletes = false;
      await store.clear(tempPaths);
      expect(await jobDir.exists(), isFalse);
    });

    test('startup sweep removes job directories older than 24 hours',
        () async {
      final store = TemporaryImportStore(
        root: root,
        clock: () => DateTime.now().add(const Duration(hours: 25)),
      );
      final tempPaths = await store.copyToTemp([await makeSource('a.png')]);
      final jobDir = Directory(p.dirname(tempPaths.first));

      await store.sweepOrphans();

      expect(await jobDir.exists(), isFalse);
    });

    test('startup sweep keeps fresh job directories', () async {
      final store = TemporaryImportStore(root: root);
      final tempPaths = await store.copyToTemp([await makeSource('a.png')]);
      final jobDir = Directory(p.dirname(tempPaths.first));

      await store.sweepOrphans();

      expect(await jobDir.exists(), isTrue);
    });

    test('sweep leaves non-job entries untouched', () async {
      final store = TemporaryImportStore(
        root: root,
        clock: () => DateTime.now().add(const Duration(hours: 48)),
      );
      await store.copyToTemp([await makeSource('a.png')]);
      final keep = File(p.join(root.path, 'keep.txt'));
      await keep.writeAsString('keep');
      final otherDir = Directory(p.join(root.path, 'not-a-job'));
      await otherDir.create();

      await store.sweepOrphans();

      expect(await keep.exists(), isTrue);
      expect(await otherDir.exists(), isTrue);
    });

    test('sweep failure reports a privacy issue and retries next launch',
        () async {
      var failDeletes = true;
      final issues = <String>[];
      final clock = DateTime.now().add(const Duration(hours: 25));
      final store = TemporaryImportStore(
        root: root,
        clock: () => clock,
        onPrivacyIssue: issues.add,
        deleteDirectory: (dir) async {
          if (failDeletes) throw const FileSystemException('locked');
          await dir.delete(recursive: true);
        },
      );
      final tempPaths = await store.copyToTemp([await makeSource('a.png')]);
      final jobDir = Directory(p.dirname(tempPaths.first));

      await store.sweepOrphans();

      expect(issues, [TemporaryImportStore.cleanupFailedIssue]);
      expect(await jobDir.exists(), isTrue);

      // Next launch: the orphaned directory is retried and removed.
      failDeletes = false;
      await store.sweepOrphans();
      expect(await jobDir.exists(), isFalse);
    });

    test('sweep on a missing root is a no-op', () async {
      await root.delete(recursive: true);
      final store = TemporaryImportStore(root: root);

      await store.sweepOrphans();
    });
  });
}
