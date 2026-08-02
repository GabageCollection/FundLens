import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../app/app_shell.dart';
import '../../theme/fundlens_tokens.dart';
import 'import_review_controller.dart';

/// Terminal result screen after a committed import: success/skip/failed
/// counts, data-completeness change, whether a snapshot was created, and the
/// two follow-up actions — view all holdings, and undo this import.
class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.state, required this.controller});

  final ImportCommitted state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final report = state.report;
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 44,
                color: FundLensTokens.profit,
              ),
              const SizedBox(height: FundLensTokens.space3),
              const Text(
                '导入完成',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Noto Serif SC',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: FundLensTokens.ink,
                ),
              ),
              const SizedBox(height: FundLensTokens.space4),
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: FundLensTokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    FundLensTokens.radiusCard,
                  ),
                  side: FundLensTokens.cardBorder,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(FundLensTokens.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ResultRow(
                        label: '新增',
                        value: '${report.inserted} 条',
                        mono: true,
                      ),
                      _ResultRow(
                        label: '更新',
                        value: '${report.updated} 条',
                        mono: true,
                      ),
                      _ResultRow(
                        label: '跳过',
                        value: '${report.skipped} 条',
                        mono: true,
                      ),
                      _ResultRow(
                        label: '失败',
                        value: '${report.failed} 条',
                        mono: true,
                      ),
                      const Divider(height: FundLensTokens.space4 * 2),
                      _ResultRow(
                        label: '数据完整度',
                        value: _completenessLabel(report),
                      ),
                      _ResultRow(
                        label: '历史快照',
                        value: report.createdSnapshot ? '已创建' : '未创建',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: FundLensTokens.space6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _goToHoldings(context),
                      child: const Text('查看全部持仓'),
                    ),
                  ),
                  const SizedBox(width: FundLensTokens.space4),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: controller.undo,
                      child: const Text('撤销本次导入'),
                    ),
                  ),
                  const SizedBox(width: FundLensTokens.space4),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => controller.back(),
                      child: const Text('继续导入'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FundLensTokens.space3),
              const Text(
                '导入已写入本地数据库；如需回退可在结果页撤销，或从“历史快照”恢复。',
                textAlign: TextAlign.center,
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
    );
  }

  String _completenessLabel(ImportCommitReport report) {
    final before = report.completenessBefore;
    final after = report.completenessAfter;
    if (before == null || after == null) return '未评估';
    final diff = (after - before) * DecimalValue.parse('100');
    final sign = diff.isNegative ? '' : '+';
    return '${_percent(before)} → ${_percent(after)} ($sign${diff.canonical} 个百分点)';
  }

  String _percent(DecimalValue value) {
    final percent = value * DecimalValue.parse('100');
    // Trim trailing zeros for display.
    final text = percent.canonical;
    final normalized = text.contains('.')
        ? text.replaceFirst(RegExp(r'\.?0+$'), '')
        : text;
    return '$normalized%';
  }

  void _goToHoldings(BuildContext context) {
    // The holdings page lives in the shell's IndexedStack; switching is done
    // by dispatching the same intent the sidebar uses.
    Actions.maybeInvoke<SelectDestinationIntent>(
      context,
      const SelectDestinationIntent(AppDestination.holdings),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FundLensTokens.space1),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 14,
              color: FundLensTokens.muted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: mono ? 'IBM Plex Mono' : 'Noto Sans SC',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FundLensTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Public export used by the wizard page.
class ImportResultView extends StatelessWidget {
  const ImportResultView({
    super.key,
    required this.state,
    required this.controller,
  });

  final ImportCommitted state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return _ResultBody(state: state, controller: controller);
  }
}
