import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/fundlens_tokens.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_scaffold.dart';
import 'import_check_panel.dart';
import 'import_mapping_panel.dart';
import 'import_review_controller.dart';
import 'import_result_view.dart';
import 'import_source_panel.dart';
import 'ocr_field_editor.dart';

/// The four-step import wizard:
/// 1. choose a data source, 2. upload a file, 3. review the recognized rows
/// (field mapping for CSV/Excel, OCR review for screenshots),
/// 4. confirm the import. All data issues are handled here, before anything
/// is written to the portfolio.
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
    final step = controller.wizardStep;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (step != null) ...[
          _StepIndicator(current: step),
          const SizedBox(height: FundLensTokens.space4),
        ],
        Expanded(
          child: switch (state) {
            ImportSourceSelect() => ImportSourcePanel(controller: controller),
            ImportParsing() => _ParsingBody(state: state),
            ImportFieldMapping() => ImportMappingPanel(
              state: state,
              controller: controller,
            ),
            ImportOcrReview() => OcrReviewPanel(
              state: state,
              controller: controller,
            ),
            ImportCheck() => ImportCheckPanel(
              state: state,
              controller: controller,
            ),
            ImportCommitting() => const LoadingView(label: '正在提交导入…'),
            ImportCommitted() => ImportResultView(
              state: state,
              controller: controller,
            ),
            ImportFailed() => _FailedBody(state: state, controller: controller),
          },
        ),
      ],
    );
    return PageScaffold(
      tier: PageWidthTier.form,
      crumb: '数据',
      title: '导入与识别',
      body: body,
    );
  }
}

/// Four-step progress strip: 选择来源 → 上传文件 → 检查识别 → 确认导入.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  /// 1-based current step.
  final int current;

  static const _labels = <String>['选择来源', '上传文件', '检查识别', '确认导入'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                color: i < current
                    ? FundLensTokens.accent
                    : FundLensTokens.border,
              ),
            ),
          _StepChip(
            index: i + 1,
            label: _labels[i],
            done: i + 1 < current,
            active: i + 1 == current,
          ),
        ],
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final badgeColor = active || done
        ? FundLensTokens.accent
        : FundLensTokens.surface;
    final badgeBorderColor = active || done
        ? FundLensTokens.accent
        : FundLensTokens.borderStrong;
    final textColor = active || done
        ? FundLensTokens.ink
        : FundLensTokens.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
            border: Border.all(color: badgeBorderColor),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 14, color: FundLensTokens.canvas)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? FundLensTokens.canvas : textColor,
                  ),
                ),
        ),
        const SizedBox(width: FundLensTokens.space2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Noto Sans SC',
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _ParsingBody extends StatelessWidget {
  const _ParsingBody({required this.state});

  final ImportParsing state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.progress != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FundLensTokens.space12,
              ),
              child: LinearProgressIndicator(value: state.progress),
            )
          else
            const CircularProgressIndicator(),
          const SizedBox(height: FundLensTokens.space4),
          Text(
            state.currentStep != null && state.totalSteps != null
                ? '正在识别第 ${state.currentStep}/${state.totalSteps} 张截图'
                : '正在解析文件…',
            style: const TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 14,
              color: FundLensTokens.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({required this.state, required this.controller});

  final ImportFailed state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: FundLensTokens.warnText,
            ),
            const SizedBox(height: FundLensTokens.space3),
            Text(
              '导入未完成',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: FundLensTokens.space2),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: FundLensTokens.space2),
            Text(
              '本次未写入任何数据，可重试或返回重新选择。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: FundLensTokens.muted,
              ),
            ),
            const SizedBox(height: FundLensTokens.space4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.retry != null) ...[
                  FilledButton(
                    onPressed: () => state.retry?.call(),
                    child: const Text('重试'),
                  ),
                  const SizedBox(width: FundLensTokens.space3),
                ],
                OutlinedButton(
                  onPressed: controller.back,
                  child: const Text('返回来源'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
