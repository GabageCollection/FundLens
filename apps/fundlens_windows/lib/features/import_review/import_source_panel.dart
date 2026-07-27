import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Offers a bundled import template through the OS save dialog.
  static Future<void> _downloadTemplate(
    BuildContext context, {
    required String assetName,
    required String fileName,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await rootBundle.load('assets/import-templates/$assetName');
      final savedPath = await file_picker.FilePicker.platform.saveFile(
        dialogTitle: '保存导入模板',
        fileName: fileName,
        bytes: bytes.buffer.asUint8List(),
      );
      if (savedPath != null) {
        messenger.showSnackBar(SnackBar(content: Text('模板已保存: $savedPath')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('模板保存失败: $e')));
    }
  }

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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _downloadTemplate(
                  context,
                  assetName: 'fundlens-import-template.csv',
                  fileName: 'fundlens-import-template.csv',
                ),
                child: const Text('下载 CSV 模板'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _downloadTemplate(
                  context,
                  assetName: 'fundlens-import-template.xlsx',
                  fileName: 'fundlens-import-template.xlsx',
                ),
                child: const Text('下载 Excel 模板'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
