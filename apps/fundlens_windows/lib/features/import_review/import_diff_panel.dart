import 'package:flutter/material.dart';

import '../../importing/import_models.dart';
import 'import_review_controller.dart';

/// Bottom diff: added, updated, possible duplicates and possible removals.
/// Full mode with removals shows a warning panel; the commit button then
/// opens a second confirmation naming the removal count. Product
/// candidates require an explicit radio selection before commit.
class ImportDiffPanel extends StatelessWidget {
  const ImportDiffPanel({super.key, required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state is! ImportEditing) return const SizedBox.shrink();
    final plan = state.plan;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            children: [
              Text('新增 ${plan.inserts.length} 条'),
              Text('更新 ${plan.updates.length} 条'),
              Text('可能重复 ${controller.duplicateCount} 条'),
              Text('可能移除 ${plan.removeIds.length} 条'),
            ],
          ),
          if (controller.mode == ImportMode.full &&
              plan.removeIds.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                '全量导入将移除不再出现的持仓',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          for (final entry in controller.candidateGroups.entries)
            _CandidateGroup(
              holdingIndex: entry.key,
              productName: state.draft.holdings[entry.key].productName,
              candidates: entry.value,
              selected: controller.candidateSelections[entry.key],
              controller: controller,
            ),
        ],
      ),
    );
  }
}

class _CandidateGroup extends StatelessWidget {
  const _CandidateGroup({
    required this.holdingIndex,
    required this.productName,
    required this.candidates,
    required this.selected,
    required this.controller,
  });

  final int holdingIndex;
  final String productName;
  final List<ProductCandidate> candidates;
  final ProductCandidate? selected;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text('选择匹配产品: $productName'),
        RadioGroup<int>(
          groupValue:
              selected == null ? null : candidates.indexOf(selected!),
          onChanged: (value) {
            if (value != null) {
              controller.selectCandidate(holdingIndex, candidates[value]);
            }
          },
          child: Column(
            children: [
              for (var i = 0; i < candidates.length; i++)
                RadioListTile<int>(
                  dense: true,
                  value: i,
                  title: Text(
                    '${candidates[i].name} (${candidates[i].productCode})',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
