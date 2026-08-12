import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// A file picked by the user. The original at [path] is only ever read;
/// it is never modified or deleted.
final class PickedImportFile {
  const PickedImportFile({required this.name, required this.path, this.bytes});

  final String name;
  final String path;
  final Uint8List? bytes;
}

/// File picker abstraction so tests never touch the OS dialog.
abstract interface class ImportFilePicker {
  Future<PickedImportFile?> pickCsvFile();
  Future<PickedImportFile?> pickExcelFile();

  /// CSV or Excel — used by platform sources (支付宝/同花顺) whose exports
  /// may be either format.
  Future<PickedImportFile?> pickTabularFile();
  Future<List<PickedImportFile>> pickScreenshotFiles();
}

/// Stores temporary copies of selected screenshots. Copies — never the
/// originals — are deleted after a successful commit or explicit discard.
abstract interface class ScreenshotTempStore {
  Future<List<String>> copyToTemp(List<String> sourcePaths);
  Future<void> clear(List<String> tempPaths);
}

/// File-based temp store: copies screenshots into [_directory]; [clear]
/// deletes only the copies inside that directory.
final class FileScreenshotTempStore implements ScreenshotTempStore {
  FileScreenshotTempStore(this._directory);

  final Directory _directory;

  @override
  Future<List<String>> copyToTemp(List<String> sourcePaths) async {
    await _directory.create(recursive: true);
    final tempPaths = <String>[];
    for (var i = 0; i < sourcePaths.length; i++) {
      final source = File(sourcePaths[i]);
      final destination = p.join(
        _directory.path,
        'import_${DateTime.now().microsecondsSinceEpoch}_$i'
        '${p.extension(sourcePaths[i])}',
      );
      await source.copy(destination);
      tempPaths.add(destination);
    }
    return tempPaths;
  }

  @override
  Future<void> clear(List<String> tempPaths) async {
    for (final tempPath in tempPaths) {
      if (!p.isWithin(_directory.path, tempPath)) continue;
      final file = File(tempPath);
      if (await file.exists()) await file.delete();
    }
  }
}
