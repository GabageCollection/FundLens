import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../importing/import_models.dart';
import '../../theme/fundlens_tokens.dart';
import 'data_issue_list.dart';
import 'import_diff_panel.dart';
import 'import_review_controller.dart';
import 'import_source_panel.dart';
import 'ocr_field_editor.dart';
import 'screenshot_crop_view.dart';

/// The import, OCR review and data-issue workspace. All data issues are
/// handled here, before anything is written to the portfolio.
class ImportReviewPage extends ConsumerStatefulWidget {
  const ImportReviewPage({super.key});

  @override
  ConsumerState<ImportReviewPage> createState() => _ImportReviewPageState();
}

class _ImportReviewPageState extends ConsumerState<ImportReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(importReviewControllerProvider).restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(importReviewControllerProvider);
    final state = controller.state;
    // 页面标题由 AppShell 顶栏统一提供,这里不再嵌套 AppBar;
    // 保留无 AppBar 的 Scaffold 以提供 Material 祖先与画布底色。
    final body = switch (state) {
      ImportIdle() => const _IdleBody(),
      ImportParsing() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.progress != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FundLensTokens.space12 * 2,
                ),
                child: LinearProgressIndicator(value: state.progress),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: FundLensTokens.space4),
            Text(
              state.currentStep != null && state.totalSteps != null
                  ? '正在识别第 ${state.currentStep}/${state.totalSteps} 张截图'
                  : '正在解析，首次截图识别需要加载模型，可能需要几分钟',
            ),
          ],
        ),
      ),
      ImportEditing() => _EditingBody(controller: controller),
      ImportCommitting() => const Center(child: CircularProgressIndicator()),
      ImportCommitted() => _CommittedBody(report: state.report),
      ImportFailed() => _FailedBody(state: state),
    };
    return Scaffold(body: body);
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(width: 320, child: ImportSourcePanel()),
    );
  }
}

class _CommittedBody extends StatelessWidget {
  const _CommittedBody({required this.report});

  final ImportCommitReport report;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('写入完成'),
          Text(
            '新增 ${report.inserted} 条 · 更新 ${report.updated} 条 · '
            '移除 ${report.removed} 条',
          ),
          const SizedBox(height: 16),
          const SizedBox(width: 320, child: ImportSourcePanel()),
        ],
      ),
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.state});

  final ImportFailed state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('导入失败: ${state.message}'),
          const SizedBox(height: 16),
          if (state.retryable)
            const SizedBox(width: 320, child: ImportSourcePanel()),
        ],
      ),
    );
  }
}

class _EditingBody extends StatelessWidget {
  const _EditingBody({required this.controller});

  final ImportReviewController controller;

  Future<void> _confirmCommit(BuildContext context) async {
    final state = controller.state;
    if (state is! ImportEditing) return;
    if (controller.mode == ImportMode.full && state.plan.removeIds.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认全量写入'),
          content: Text('将移除 ${state.plan.removeIds.length} 条持仓'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await controller.commit(confirmedFullRemovals: true);
      return;
    }
    await controller.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<ImportMode>(
            segments: const [
              ButtonSegment(value: ImportMode.partial, label: Text('部分持仓')),
              ButtonSegment(value: ImportMode.full, label: Text('全量持仓')),
            ],
            selected: {controller.mode},
            onSelectionChanged: (selection) =>
                controller.setMode(selection.first),
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ScreenshotCropView(controller: controller)),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: OcrFieldEditor(controller: controller),
                    ),
                    Expanded(
                      flex: 2,
                      child: DataIssueList(controller: controller),
                    ),
                    ImportDiffPanel(controller: controller),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: controller.discard,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: controller.canCommit
                    ? () => _confirmCommit(context)
                    : null,
                child: const Text('确认写入'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
