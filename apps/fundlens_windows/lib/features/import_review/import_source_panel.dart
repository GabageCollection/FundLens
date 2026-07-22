import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'import_review_controller.dart';

/// OS-backed picker used by the app bootstrap; tests inject a fake
/// [ImportFilePicker] instead.
final class FilePickerImportFilePicker implements ImportFilePicker {
  const FilePickerImportFilePicker();

  Future<PickedImportFile?> _pick(List<String> extensions) async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;
    return PickedImportFile(
      name: file.name,
      path: file.path ?? file.name,
      bytes: file.bytes,
    );
  }

  @override
  Future<PickedImportFile?> pickCsvFile() => _pick(const ['csv']);

  @override
  Future<PickedImportFile?> pickExcelFile() =>
      _pick(const ['xlsx', 'xls']);

  @override
  Future<List<PickedImportFile>> pickScreenshotFiles() async {
    final result = await file_picker.FilePicker.platform.pickFiles(
      type: file_picker.FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'bmp', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    return [
      for (final file in result?.files ?? const <file_picker.PlatformFile>[])
        PickedImportFile(
          name: file.name,
          path: file.path ?? file.name,
          bytes: file.bytes,
        ),
    ];
  }
}

/// Entry points for CSV, Excel and screenshot imports. Data issues are
/// handled only here, in the import workspace.
class ImportSourcePanel extends ConsumerWidget {
  const ImportSourcePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(importReviewControllerProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'alipay', label: Text('支付宝截图')),
            ButtonSegment(value: 'ths', label: Text('同花顺截图')),
          ],
          selected: {controller.templateHint},
          onSelectionChanged: (selection) =>
              controller.templateHint = selection.first,
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: controller.importCsv,
          child: const Text('导入 CSV'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: controller.importExcel,
          child: const Text('导入 Excel'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: controller.importScreenshots,
          child: const Text('导入截图'),
        ),
      ],
    );
  }
}
