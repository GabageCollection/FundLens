import 'package:flutter/material.dart';

import '../../importing/import_models.dart';
import 'import_review_controller.dart';

/// Lists the draft and plan data issues. Selecting an issue focuses the
/// corresponding field and its source crop.
class DataIssueList extends StatelessWidget {
  const DataIssueList({super.key, required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state is! ImportCheck) return const SizedBox.shrink();
    final issues = [...state.draft.issues, ...state.plan.issues];
    if (issues.isEmpty) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('无数据问题'));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        return ListTile(
          dense: true,
          leading: Icon(
            issue.severity == IssueSeverity.blocking
                ? Icons.error_outline
                : Icons.warning_amber_outlined,
            color: issue.severity == IssueSeverity.blocking
                ? Theme.of(context).colorScheme.error
                : null,
          ),
          title: Text(issue.message),
          subtitle: Text(_severityLabel(issue.severity)),
          onTap: () => controller.focusIssue(issue),
        );
      },
    );
  }

  String _severityLabel(IssueSeverity severity) => switch (severity) {
    IssueSeverity.blocking => '阻断',
    IssueSeverity.warning => '警告',
    IssueSeverity.info => '提示',
  };
}
