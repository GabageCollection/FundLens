import 'package:flutter/material.dart';

import '../../importing/import_models.dart';
import '../../theme/fundlens_tokens.dart';
import 'import_review_controller.dart';
import 'ocr_field_editor.dart' show fieldLabel;

/// Lists the draft and plan data issues. Each entry names the holding and
/// field it belongs to; tapping it jumps back to the screenshot review step,
/// scrolls the offending card into view and highlights the field.
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
          subtitle: Text(
            '${_severityLabel(issue.severity)} · ${_location(state, issue)}',
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: FundLensTokens.muted,
          ),
          onTap: () => controller.focusIssue(issue),
        );
      },
    );
  }

  /// 问题定位:持仓名称(未识别出名称时退化为「第 N 条持仓」) + 字段中文名;
  /// 既无归属持仓又无字段的全局问题归为「整体」。
  String _location(ImportCheck state, DataIssue issue) {
    final parts = <String>[];
    final index = issue.holdingIndex;
    if (index != null && index >= 0 && index < state.draft.holdings.length) {
      final name = state.draft.holdings[index].productName;
      parts.add(name.isEmpty ? '第 ${index + 1} 条持仓' : name);
    }
    if (issue.field.isNotEmpty) parts.add(fieldLabel(issue.field));
    return parts.isEmpty ? '整体' : parts.join(' · ');
  }

  String _severityLabel(IssueSeverity severity) => switch (severity) {
    IssueSeverity.blocking => '阻断',
    IssueSeverity.warning => '警告',
    IssueSeverity.info => '提示',
  };
}
