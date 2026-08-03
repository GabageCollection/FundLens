import 'package:flutter/material.dart';

import '../../importing/import_models.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/confirm_dialog.dart';
import 'data_issue_list.dart';
import 'import_review_controller.dart';

/// Public export used by the wizard page.
class ImportCheckPanel extends StatelessWidget {
  const ImportCheckPanel({
    super.key,
    required this.state,
    required this.controller,
  });

  final ImportCheck state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return _CheckBody(state: state, controller: controller);
  }
}

/// Wizard step 4: confirm. Shows the check summary (inserts / updates /
/// duplicates / abnormal amounts / unclassified assets / expected total value
/// change), the data issues, an explicit resolution dropdown for every row
/// flagged as a possible duplicate, the import mode and an optional snapshot,
/// then the confirm action. Nothing is written until this screen is approved.
class _CheckBody extends StatelessWidget {
  const _CheckBody({required this.state, required this.controller});

  final ImportCheck state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '确认导入',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FundLensTokens.ink,
              ),
            ),
            const SizedBox(height: FundLensTokens.space4),
            _SummaryGrid(summary: summary),
            const SizedBox(height: FundLensTokens.space4),
            _IssueSection(controller: controller),
            if (controller.candidateGroups.isNotEmpty) ...[
              const SizedBox(height: FundLensTokens.space4),
              _CandidateSection(controller: controller),
            ],
            if (_hasDuplicateRows(state)) ...[
              const SizedBox(height: FundLensTokens.space4),
              _ResolutionSection(state: state, controller: controller),
            ],
            const SizedBox(height: FundLensTokens.space4),
            _OptionsCard(controller: controller),
            const SizedBox(height: FundLensTokens.space4),
            _ConfirmRow(controller: controller),
          ],
        ),
      ),
    );
  }

  bool _hasDuplicateRows(ImportCheck state) =>
      state.plan.updates.isNotEmpty || controller.duplicateCount > 0;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final ImportCheckSummary summary;

  @override
  Widget build(BuildContext context) {
    final change = summary.totalValueChange;
    final changePositive = change.isNegative;
    final changeColor = changePositive
        ? FundLensTokens.loss
        : change.isZero
        ? FundLensTokens.ink
        : FundLensTokens.profit;
    final changeSign = changePositive ? '' : '+';
    return Wrap(
      spacing: FundLensTokens.space4,
      runSpacing: FundLensTokens.space4,
      children: [
        _SummaryTile(label: '即将新增', value: '${summary.insertCount} 条'),
        _SummaryTile(label: '即将更新', value: '${summary.updateCount} 条'),
        _SummaryTile(
          label: '疑似重复',
          value: '${summary.duplicateCount} 条',
          warn: summary.duplicateCount > 0,
        ),
        _SummaryTile(
          label: '异常金额',
          value: '${summary.abnormalCount} 条',
          warn: summary.abnormalCount > 0,
        ),
        _SummaryTile(
          label: '未分类资产',
          value: '${summary.unclassifiedCount} 条',
          warn: summary.unclassifiedCount > 0,
        ),
        _SummaryTile(
          label: '预计总金额变化',
          value: '$changeSign${change.canonical} 元',
          valueColor: changeColor,
          mono: true,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.warn = false,
    this.valueColor,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool warn;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(FundLensTokens.space3),
      decoration: BoxDecoration(
        color: warn ? FundLensTokens.warnSoft : FundLensTokens.surface,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        border: Border.all(
          color: warn ? FundLensTokens.warn : FundLensTokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Noto Sans SC',
              fontSize: 12,
              color: FundLensTokens.muted,
            ),
          ),
          const SizedBox(height: FundLensTokens.space1),
          Text(
            value,
            style: TextStyle(
              fontFamily: mono ? 'IBM Plex Mono' : 'Noto Sans SC',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: valueColor ?? FundLensTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueSection extends StatelessWidget {
  const _IssueSection({required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state is! ImportCheck) return const SizedBox.shrink();
    final issues = [...state.draft.issues, ...state.plan.issues];
    if (issues.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '需要处理的数据问题',
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: FundLensTokens.ink,
          ),
        ),
        const SizedBox(height: FundLensTokens.space2),
        DataIssueList(controller: controller),
      ],
    );
  }
}

class _CandidateSection extends StatelessWidget {
  const _CandidateSection({required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择匹配产品（跨平台疑似重复）',
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: FundLensTokens.ink,
          ),
        ),
        const SizedBox(height: FundLensTokens.space2),
        for (final entry in controller.candidateGroups.entries)
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: FundLensTokens.space1),
            color: FundLensTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
              side: FundLensTokens.cardBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.all(FundLensTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择匹配产品: ${(controller.state as ImportCheck).draft.holdings[entry.key].productName}',
                    style: const TextStyle(
                      fontFamily: 'Noto Sans SC',
                      fontSize: 14,
                      color: FundLensTokens.ink,
                    ),
                  ),
                  RadioGroup<int>(
                    groupValue:
                        controller.candidateSelections[entry.key] == null
                        ? null
                        : entry.value.indexOf(
                            controller.candidateSelections[entry.key]!,
                          ),
                    onChanged: (value) {
                      if (value != null) {
                        controller.selectCandidate(
                          entry.key,
                          entry.value[value],
                        );
                      }
                    },
                    child: Column(
                      children: [
                        for (var i = 0; i < entry.value.length; i++)
                          RadioListTile<int>(
                            dense: true,
                            value: i,
                            title: Text(
                              '${entry.value[i].name} '
                              '(${entry.value[i].productCode})',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ResolutionSection extends StatelessWidget {
  const _ResolutionSection({required this.state, required this.controller});

  final ImportCheck state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final updatedNames = {for (final u in state.plan.updates) u.productName};
    final duplicateIndexes = controller.duplicateIndexes;
    final rows = <(int, String)>[
      for (var i = 0; i < state.draft.holdings.length; i++)
        if (duplicateIndexes.contains(i) ||
            updatedNames.contains(state.draft.holdings[i].productName))
          (i, state.draft.holdings[i].productName),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '重复记录处理方式',
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: FundLensTokens.ink,
          ),
        ),
        const SizedBox(height: FundLensTokens.space2),
        const Text(
          '以下记录可能与现有持仓重复，请逐条选择处理方式。',
          style: TextStyle(
            fontFamily: 'Noto Sans SC',
            fontSize: 12,
            color: FundLensTokens.muted,
          ),
        ),
        const SizedBox(height: FundLensTokens.space2),
        for (final (index, name) in rows)
          Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(vertical: FundLensTokens.space1),
            color: FundLensTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
              side: FundLensTokens.cardBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FundLensTokens.space3,
                vertical: FundLensTokens.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name.isEmpty ? '持仓 ${index + 1}' : name,
                      style: const TextStyle(
                        fontFamily: 'Noto Sans SC',
                        fontSize: 14,
                        color: FundLensTokens.ink,
                      ),
                    ),
                  ),
                  DropdownButton<DuplicateResolution>(
                    key: ValueKey('resolution-$index'),
                    value:
                        controller.resolutions[index] ??
                        DuplicateResolution.overwrite,
                    items: const [
                      DropdownMenuItem(
                        value: DuplicateResolution.merge,
                        child: Text('合并金额'),
                      ),
                      DropdownMenuItem(
                        value: DuplicateResolution.overwrite,
                        child: Text('覆盖现有'),
                      ),
                      DropdownMenuItem(
                        value: DuplicateResolution.keepBoth,
                        child: Text('保留两条'),
                      ),
                      DropdownMenuItem(
                        value: DuplicateResolution.skip,
                        child: Text('跳过'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.setResolution(index, value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OptionsCard extends StatefulWidget {
  const _OptionsCard({required this.controller});

  final ImportReviewController controller;

  @override
  State<_OptionsCard> createState() => _OptionsCardState();
}

class _OptionsCardState extends State<_OptionsCard> {
  bool _createSnapshot = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final plan = (controller.state as ImportCheck).plan;
    final fullRemoves =
        controller.mode == ImportMode.full && plan.removeIds.isNotEmpty;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '导入模式',
                  style: TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FundLensTokens.ink,
                  ),
                ),
                const SizedBox(width: FundLensTokens.space4),
                SegmentedButton<ImportMode>(
                  segments: const [
                    ButtonSegment(
                      value: ImportMode.partial,
                      label: Text('部分持仓'),
                    ),
                    ButtonSegment(value: ImportMode.full, label: Text('全量持仓')),
                  ],
                  selected: {controller.mode},
                  onSelectionChanged: (selection) =>
                      controller.setMode(selection.first),
                ),
              ],
            ),
            if (fullRemoves) ...[
              const SizedBox(height: FundLensTokens.space3),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(FundLensTokens.space3),
                decoration: BoxDecoration(
                  color: FundLensTokens.warnSoft,
                  borderRadius: BorderRadius.circular(
                    FundLensTokens.radiusSmall,
                  ),
                ),
                child: Text(
                  '全量导入将移除不再出现的 ${plan.removeIds.length} 条同平台持仓',
                  style: const TextStyle(
                    fontFamily: 'Noto Sans SC',
                    fontSize: 12,
                    color: FundLensTokens.warnText,
                  ),
                ),
              ),
            ],
            const SizedBox(height: FundLensTokens.space4),
            CheckboxListTile(
              value: _createSnapshot,
              onChanged: (value) =>
                  setState(() => _createSnapshot = value ?? false),
              title: const Text(
                '导入完成后创建历史快照',
                style: TextStyle(
                  fontFamily: 'Noto Sans SC',
                  fontSize: 14,
                  color: FundLensTokens.ink,
                ),
              ),
              subtitle: const Text(
                '快照冻结当前所有持仓，供后续对比资产变化',
                style: TextStyle(
                  fontFamily: 'Noto Sans SC',
                  fontSize: 12,
                  color: FundLensTokens.muted,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.controller});

  final ImportReviewController controller;

  Future<void> _confirm(BuildContext context) async {
    final state = controller.state;
    if (state is! ImportCheck) return;
    final plan = state.plan;
    if (controller.mode == ImportMode.full && plan.removeIds.isNotEmpty) {
      final confirmed = await showConfirmDialog(
        context,
        title: '确认全量写入',
        content: Text('将移除 ${plan.removeIds.length} 条持仓，其余数据按本次导入结果更新。'),
      );
      if (!confirmed) return;
      await controller.commit(confirmedFullRemovals: true);
      return;
    }
    await controller.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: controller.back, child: const Text('返回')),
        const SizedBox(width: FundLensTokens.space2),
        FilledButton(
          onPressed: controller.canCommit ? () => _confirm(context) : null,
          child: const Text('确认导入'),
        ),
      ],
    );
  }
}
