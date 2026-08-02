import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../importing/import_models.dart';
import '../../theme/fundlens_tokens.dart';
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
  Future<PickedImportFile?> pickExcelFile() => _pick(const ['xlsx', 'xls']);

  @override
  Future<PickedImportFile?> pickTabularFile() =>
      _pick(const ['csv', 'xlsx', 'xls']);

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

/// Wizard steps 1 & 2. When no source is chosen yet, shows the five source
/// cards; once a source is picked it renders that source's upload area
/// (click or drag for tabular files, click or drop for screenshots), the
/// supported-format note, template downloads and the last-import record.
class _SourceUploadBody extends StatelessWidget {
  const _SourceUploadBody({required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final source = controller.source;
    if (source == null) return const _SourceCards();
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FundLensTokens.space12,
          vertical: FundLensTokens.space4,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SourceBanner(source: source, controller: controller),
                const SizedBox(height: FundLensTokens.space4),
                if (source == ImportSource.screenshot)
                  _ScreenshotUpload(controller: controller)
                else
                  _TabularUpload(controller: controller),
                const SizedBox(height: FundLensTokens.space4),
                _TemplateDownloads(source: source),
                const SizedBox(height: FundLensTokens.space4),
                _LastImportRecord(controller: controller),
                const SizedBox(height: FundLensTokens.space3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: controller.back,
                    child: const Text('重选来源'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceBanner extends StatelessWidget {
  const _SourceBanner({required this.source, required this.controller});

  final ImportSource source;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: FundLensTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        side: FundLensTokens.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Row(
          children: [
            Icon(_iconOf(source), size: 20, color: FundLensTokens.accent),
            const SizedBox(width: FundLensTokens.space3),
            Text(
              source.label,
              style: const TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FundLensTokens.ink,
              ),
            ),
            const Spacer(),
            if (source == ImportSource.alipay || source == ImportSource.ths)
              OutlinedButton(
                onPressed: () =>
                    controller.selectSource(ImportSource.screenshot),
                child: const Text('改用截图识别'),
              ),
          ],
        ),
      ),
    );
  }
}

/// The five source options shown before any source is chosen.
class _SourceCards extends StatelessWidget {
  const _SourceCards();

  static const _options = <_SourceOption>[
    _SourceOption(
      source: ImportSource.alipay,
      icon: Icons.account_balance_wallet_outlined,
      subtitle: '支付宝导出文件或截图',
    ),
    _SourceOption(
      source: ImportSource.ths,
      icon: Icons.show_chart,
      subtitle: '同花顺导出文件或截图',
    ),
    _SourceOption(
      source: ImportSource.csv,
      icon: Icons.table_chart_outlined,
      subtitle: '从 CSV 文件导入',
    ),
    _SourceOption(
      source: ImportSource.excel,
      icon: Icons.grid_on_outlined,
      subtitle: '从 Excel 文件导入',
    ),
    _SourceOption(
      source: ImportSource.screenshot,
      icon: Icons.photo_camera_outlined,
      subtitle: '识别持仓截图',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Consumer(
        builder: (context, ref, _) {
          final controller = ref.watch(importReviewControllerProvider);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(FundLensTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择数据来源',
                    style: const TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: FundLensTokens.ink,
                    ),
                  ),
                  const SizedBox(height: FundLensTokens.space2),
                  const Text(
                    '所有文件只在本机处理，不会上传',
                    style: TextStyle(
                      fontFamily: 'Noto Sans SC',
                      fontSize: 12,
                      color: FundLensTokens.muted,
                    ),
                  ),
                  const SizedBox(height: FundLensTokens.space4),
                  Wrap(
                    spacing: FundLensTokens.space4,
                    runSpacing: FundLensTokens.space4,
                    children: [
                      for (final option in _options)
                        _SourceCard(
                          option: option,
                          onTap: () => controller.selectSource(option.source),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SourceOption {
  const _SourceOption({
    required this.source,
    required this.icon,
    required this.subtitle,
  });

  final ImportSource source;
  final IconData icon;
  final String subtitle;
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.option, required this.onTap});

  final _SourceOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 120,
      child: Material(
        color: FundLensTokens.surface,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
              border: Border.all(color: FundLensTokens.border),
            ),
            padding: const EdgeInsets.all(FundLensTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(option.icon, size: 24, color: FundLensTokens.accent),
                const Spacer(),
                Text(
                  option.source.label,
                  style: const TextStyle(
                    fontFamily: 'Noto Serif SC',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: FundLensTokens.ink,
                  ),
                ),
                const SizedBox(height: FundLensTokens.space1),
                Text(
                  option.subtitle,
                  style: const TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 12,
                    color: FundLensTokens.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Click-or-drop upload area for tabular files.
class _TabularUpload extends ConsumerStatefulWidget {
  const _TabularUpload({required this.controller});

  final ImportReviewController controller;

  @override
  ConsumerState<_TabularUpload> createState() => _TabularUploadState();
}

class _TabularUploadState extends ConsumerState<_TabularUpload> {
  bool _dragOver = false;

  Future<void> _acceptDrop(List<DropItem> items) async {
    if (items.isEmpty) return;
    final item = items.first;
    final bytes = await item.readAsBytes();
    await widget.controller.acceptDroppedFile(
      PickedImportFile(name: item.name, path: item.path, bytes: bytes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: (details) async {
        setState(() => _dragOver = false);
        await _acceptDrop(details.files);
      },
      child: Material(
        color: _dragOver ? FundLensTokens.accentSoft : FundLensTokens.surface,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        child: InkWell(
          onTap: widget.controller.pickFile,
          borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
          child: Container(
            height: 168,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
              border: Border.all(
                color: _dragOver
                    ? FundLensTokens.accent
                    : FundLensTokens.borderStrong,
                width: _dragOver ? FundLensTokens.focusOutlineWidth : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _dragOver
                      ? Icons.file_download_done
                      : Icons.cloud_upload_outlined,
                  size: 28,
                  color: _dragOver
                      ? FundLensTokens.accent
                      : FundLensTokens.muted,
                ),
                const SizedBox(height: FundLensTokens.space2),
                Text(
                  _dragOver ? '松开以导入' : '点击选择或拖拽文件到此处',
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 14,
                    fontWeight: _dragOver ? FontWeight.w600 : FontWeight.w400,
                    color: _dragOver
                        ? FundLensTokens.accent
                        : FundLensTokens.ink,
                  ),
                ),
                const SizedBox(height: FundLensTokens.space2),
                const Text(
                  '支持 .csv / .xlsx / .xls · 单个文件 ≤ 20 MB',
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 12,
                    color: FundLensTokens.muted,
                  ),
                ),
                const SizedBox(height: FundLensTokens.space2),
                const Text(
                  '字段将自动识别，识别不全时可手动调整映射',
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 12,
                    color: FundLensTokens.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screenshot upload entry: choose files, pick the OCR template and drop
/// screenshots directly.
class _ScreenshotUpload extends ConsumerStatefulWidget {
  const _ScreenshotUpload({required this.controller});

  final ImportReviewController controller;

  @override
  ConsumerState<_ScreenshotUpload> createState() => _ScreenshotUploadState();
}

class _ScreenshotUploadState extends ConsumerState<_ScreenshotUpload> {
  bool _dragOver = false;

  Future<void> _acceptDrop(List<DropItem> items) async {
    final files = <PickedImportFile>[];
    for (final item in items) {
      final bytes = await item.readAsBytes();
      files.add(
        PickedImportFile(name: item.name, path: item.path, bytes: bytes),
      );
    }
    await widget.controller.acceptDroppedScreenshots(files);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: FundLensTokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
            side: FundLensTokens.cardBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.all(FundLensTokens.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '识别模板',
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FundLensTokens.ink,
                  ),
                ),
                const SizedBox(height: FundLensTokens.space3),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'alipay', label: Text('支付宝')),
                    ButtonSegment(value: 'ths', label: Text('同花顺')),
                  ],
                  selected: {controller.templateHint},
                  onSelectionChanged: (selection) =>
                      controller.templateHint = selection.first,
                ),
                const SizedBox(height: FundLensTokens.space4),
                FilledButton.icon(
                  onPressed: controller.pickScreenshots,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('选择截图'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FundLensTokens.space4),
        DropTarget(
          onDragEntered: (_) => setState(() => _dragOver = true),
          onDragExited: (_) => setState(() => _dragOver = false),
          onDragDone: (details) async {
            setState(() => _dragOver = false);
            await _acceptDrop(details.files);
          },
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              color: _dragOver
                  ? FundLensTokens.accentSoft
                  : FundLensTokens.surfaceAlt,
              borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
              border: Border.all(
                color: _dragOver
                    ? FundLensTokens.accent
                    : FundLensTokens.borderStrong,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _dragOver ? '松开以识别' : '或将截图拖拽到此处 · 支持 png / jpg / webp',
              style: const TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 12,
                color: FundLensTokens.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateDownloads extends StatelessWidget {
  const _TemplateDownloads({required this.source});

  final ImportSource source;

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
  Widget build(BuildContext context) {
    if (source == ImportSource.screenshot) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        const Text(
          '下载模板',
          style: TextStyle(
            fontFamily: 'Noto Sans SC',
            fontSize: 14,
            color: FundLensTokens.muted,
          ),
        ),
        const SizedBox(width: FundLensTokens.space3),
        OutlinedButton(
          onPressed: () => _downloadTemplate(
            context,
            assetName: 'fundlens-import-template.csv',
            fileName: 'fundlens-import-template.csv',
          ),
          child: const Text('CSV 模板'),
        ),
        const SizedBox(width: FundLensTokens.space2),
        OutlinedButton(
          onPressed: () => _downloadTemplate(
            context,
            assetName: 'fundlens-import-template.xlsx',
            fileName: 'fundlens-import-template.xlsx',
          ),
          child: const Text('Excel 模板'),
        ),
      ],
    );
  }
}

class _LastImportRecord extends StatelessWidget {
  const _LastImportRecord({required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final record = controller.lastRecord;
    if (record == null) return const SizedBox.shrink();
    final time = record.committedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final formatted =
        '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FundLensTokens.space3,
        vertical: FundLensTokens.space2,
      ),
      decoration: BoxDecoration(
        color: FundLensTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
        border: Border.all(color: FundLensTokens.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: FundLensTokens.muted),
          const SizedBox(width: FundLensTokens.space2),
          const Text(
            '最近一次导入',
            style: TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 12,
              color: FundLensTokens.muted,
            ),
          ),
          const SizedBox(width: FundLensTokens.space2),
          Text(
            '$formatted · 新增 ${record.inserted} / 更新 ${record.updated}'
            ' / 移除 ${record.removed} / 跳过 ${record.skipped}',
            style: const TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 12,
              color: FundLensTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconOf(ImportSource source) => switch (source) {
  ImportSource.alipay => Icons.account_balance_wallet_outlined,
  ImportSource.ths => Icons.show_chart,
  ImportSource.csv => Icons.table_chart_outlined,
  ImportSource.excel => Icons.grid_on_outlined,
  ImportSource.screenshot => Icons.photo_camera_outlined,
};

/// Public export: the source-upload body used by the wizard.
class ImportSourcePanel extends StatelessWidget {
  const ImportSourcePanel({super.key, required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return _SourceUploadBody(controller: controller);
  }
}
