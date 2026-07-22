import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import 'import_review_controller.dart';

const _fieldLabels = {
  'product_name': '产品名称',
  'current_value': '当前金额',
  'holding_profit': '持有收益',
  'cumulative_profit': '累计收益',
  'cost_price': '成本价',
  'quantity': '持仓数量',
  'productName': '产品名称',
  'currentValue': '当前金额',
};

String fieldLabel(String field) => _fieldLabels[field] ?? field;

/// Editable draft fields. OCR fields always show a confidence badge and
/// provenance next to the value, so both are visible before any commit.
class OcrFieldEditor extends StatelessWidget {
  const OcrFieldEditor({super.key, required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state is! ImportEditing) return const SizedBox.shrink();
    final draft = state.draft;
    return ListView.builder(
      itemCount: draft.holdings.length,
      itemBuilder: (context, index) {
        final holding = draft.holdings[index];
        final ocrRow = index < controller.ocrRows.length
            ? controller.ocrRows[index]
            : null;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.productName.isEmpty
                      ? '持仓 ${index + 1}'
                      : holding.productName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (ocrRow != null)
                  for (final field in ocrRow.fields.values)
                    _OcrFieldTile(
                      rowIndex: index,
                      field: field,
                      focused: controller.focusedField == field.name &&
                          controller.focusedHoldingIndex == index,
                      controller: controller,
                    )
                else ...[
                  _PlainFieldTile(
                    index: index,
                    field: 'productName',
                    value: holding.productName,
                    provenance: _provenance(holding.dataOrigin),
                    controller: controller,
                  ),
                  _PlainFieldTile(
                    index: index,
                    field: 'currentValue',
                    value: holding.currentValue.canonical,
                    provenance: _provenance(holding.dataOrigin),
                    controller: controller,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _provenance(DataOrigin origin) => switch (origin) {
        DataOrigin.csv => 'CSV 文件',
        DataOrigin.excel => 'Excel 文件',
        DataOrigin.ocr => '截图 OCR',
        DataOrigin.manual => '手动录入',
      };
}

class _OcrFieldTile extends StatelessWidget {
  const _OcrFieldTile({
    required this.rowIndex,
    required this.field,
    required this.focused,
    required this.controller,
  });

  final int rowIndex;
  final OcrFieldValue field;
  final bool focused;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final percent = (field.confidence * 100).round();
    final lowConfidence = field.confidence < 0.9;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('ocr-field-${field.name}-$rowIndex'),
            initialValue: field.rawText,
            decoration: InputDecoration(
              labelText: fieldLabel(field.name),
              helperText: '截图 OCR · 第 ${field.pageIndex + 1} 页',
              isDense: true,
            ),
            onTap: () => controller.focusField(field.name, rowIndex),
            onChanged: (value) =>
                controller.updateHoldingField(rowIndex, field.name, value),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            '置信度 $percent%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: lowConfidence
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
          ),
        ),
      ],
    );
  }
}

class _PlainFieldTile extends StatelessWidget {
  const _PlainFieldTile({
    required this.index,
    required this.field,
    required this.value,
    required this.provenance,
    required this.controller,
  });

  final int index;
  final String field;
  final String value;
  final String provenance;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('ocr-field-$field-$index'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: fieldLabel(field),
        helperText: provenance,
        isDense: true,
      ),
      onTap: () => controller.focusField(field, index),
      onChanged: (next) => controller.updateHoldingField(index, field, next),
    );
  }
}
