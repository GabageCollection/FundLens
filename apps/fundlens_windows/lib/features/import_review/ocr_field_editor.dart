import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_tokens.dart';
import 'import_review_controller.dart';
import 'screenshot_crop_view.dart';

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

/// Wizard step 3 for screenshots: left panel shows the source screenshot and
/// its focused crop; right panel lists the OCR rows with confidence badges,
/// editable fields and a per-row delete action. The user confirms only after
/// reviewing everything; nothing is written before that.
class _OcrReviewBody extends StatelessWidget {
  const _OcrReviewBody({required this.state, required this.controller});

  final ImportOcrReview state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final editor = _OcrEditor(controller: controller);
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= FundLensTokens.gridCollapseBelow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: ScreenshotCropView(controller: controller)),
                    Expanded(flex: 2, child: editor),
                  ],
                );
              }
              // 窄屏:裁剪区与编辑列纵向堆叠,统一滚动
              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 320,
                      child: ScreenshotCropView(controller: controller),
                    ),
                    const SizedBox(height: FundLensTokens.space3),
                    SizedBox(height: 640, child: editor),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(FundLensTokens.space2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: controller.back, child: const Text('返回')),
              const SizedBox(width: FundLensTokens.space2),
              FilledButton(
                onPressed: controller.confirmOcrReview,
                child: const Text('确认识别结果'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OcrEditor extends StatelessWidget {
  const _OcrEditor({required this.controller});

  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state is! ImportOcrReview) return const SizedBox.shrink();
    final draft = state.draft;
    if (draft.holdings.isEmpty) {
      return const Center(
        child: Text(
          '没有识别到持仓行，可返回重选或删除截图',
          style: TextStyle(
            fontFamily: 'Noto Sans SC',
            fontSize: 14,
            color: FundLensTokens.muted,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: draft.holdings.length,
      itemBuilder: (context, index) {
        final holding = draft.holdings[index];
        final ocrRow = index < controller.ocrRows.length
            ? controller.ocrRows[index]
            : null;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(
            horizontal: FundLensTokens.space2,
            vertical: FundLensTokens.space1,
          ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        holding.productName.isEmpty
                            ? '持仓 ${index + 1}'
                            : holding.productName,
                        style: const TextStyle(
                          fontFamily: 'Noto Serif SC',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: FundLensTokens.ink,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => controller.removeOcrRow(index),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('删除'),
                    ),
                  ],
                ),
                const Divider(height: 1, color: FundLensTokens.border),
                const SizedBox(height: FundLensTokens.space2),
                if (ocrRow != null)
                  for (final field in ocrRow.fields.values)
                    _OcrFieldTile(
                      rowIndex: index,
                      field: field,
                      focused:
                          controller.focusedField == field.name &&
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
              enabledBorder: lowConfidence
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        FundLensTokens.radiusControl,
                      ),
                      borderSide: const BorderSide(color: FundLensTokens.warn),
                    )
                  : null,
            ),
            onTap: () => controller.focusField(field.name, rowIndex),
            onChanged: (value) =>
                controller.updateHoldingField(rowIndex, field.name, value),
          ),
        ),
        const SizedBox(width: FundLensTokens.space2),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FundLensTokens.space2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: lowConfidence
                  ? FundLensTokens.warnSoft
                  : FundLensTokens.surfaceAlt,
              borderRadius: BorderRadius.circular(FundLensTokens.radiusSmall),
            ),
            child: Text(
              lowConfidence ? '低置信 $percent%' : '置信 $percent%',
              style: TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 12,
                fontWeight: lowConfidence ? FontWeight.w600 : FontWeight.w400,
                color: lowConfidence
                    ? FundLensTokens.warn
                    : FundLensTokens.muted,
              ),
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
      ),
      onTap: () => controller.focusField(field, index),
      onChanged: (next) => controller.updateHoldingField(index, field, next),
    );
  }
}

/// Public export used by the wizard page.
class OcrReviewPanel extends StatelessWidget {
  const OcrReviewPanel({
    super.key,
    required this.state,
    required this.controller,
  });

  final ImportOcrReview state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return _OcrReviewBody(state: state, controller: controller);
  }
}
