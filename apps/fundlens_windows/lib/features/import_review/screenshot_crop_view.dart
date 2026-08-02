import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/fundlens_theme.dart';
import 'import_review_controller.dart';

/// Left panel: shows the selected source screenshot and, for the focused
/// field, its exact crop rectangle. The crop is always available before
/// commit so the user can verify OCR output against the source.
class ScreenshotCropView extends StatelessWidget {
  const ScreenshotCropView({super.key, required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final paths = controller.tempScreenshotPaths;
    if (paths.isEmpty) {
      return const Center(child: Text('无截图来源'));
    }
    final focused = controller.focusedOcrField;
    final pageIndex = (focused?.pageIndex ?? 0).clamp(0, paths.length - 1);
    final path = paths[pageIndex];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '来源截图',
            style: Theme.of(
              context,
            ).extension<FundLensTextStyles>()!.sectionTitle,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: File(path).existsSync()
                ? Image.file(File(path), fit: BoxFit.contain)
                : Center(
                    child: Text(
                      path,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                  ),
          ),
          if (focused != null) ...[
            const SizedBox(height: 8),
            Container(
              key: ValueKey('ocr-crop-${focused.name}'),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                '字段裁剪（x ${focused.crop[0]}, y ${focused.crop[1]}, '
                '宽 ${focused.crop[2]}, 高 ${focused.crop[3]}）',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
