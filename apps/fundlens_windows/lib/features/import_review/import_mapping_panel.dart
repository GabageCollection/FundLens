import 'package:flutter/material.dart';

import '../../importing/tabular_import_parser.dart';
import '../../theme/fundlens_tokens.dart';
import 'import_review_controller.dart';

/// Wizard step 3 for tabular files: the user confirms or corrects the
/// auto-detected column mapping and sees the first rows of data. Required
/// fields (product name, current value) that are unmapped block the "确认映射"
/// action, so the user must choose a column for them.
class _MappingBody extends StatelessWidget {
  const _MappingBody({required this.state, required this.controller});

  final ImportFieldMapping state;
  final ImportReviewController controller;

  static const _systemFields = <(String, String, bool)>[
    ('productName', '产品名称', true),
    ('productCode', '产品代码', false),
    ('currentValue', '当前金额', true),
    ('quantity', '持仓数量 / 份额', false),
    ('currentPrice', '现价', false),
    ('costPrice', '成本价', false),
    ('costAmount', '成本金额', false),
    ('holdingProfit', '持有收益', false),
    ('cumulativeProfit', '累计收益', false),
    ('sourcePlatform', '来源平台', false),
    ('instrumentType', '产品类型', false),
    ('currency', '币种', false),
  ];

  @override
  Widget build(BuildContext context) {
    final table = state.table;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '字段映射',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FundLensTokens.ink,
              ),
            ),
            const SizedBox(height: FundLensTokens.space2),
            Text(
              '已按常见表头自动识别下列映射，可手动修改；带“必填”的字段必须选择对应列。',
              style: TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 12,
                color: FundLensTokens.muted,
              ),
            ),
            const SizedBox(height: FundLensTokens.space4),
            _MappingTable(
              headings: table.headings,
              mapping: state.mapping,
              onChanged: (mapping) => controller.setMapping(mapping),
            ),
            const SizedBox(height: FundLensTokens.space4),
            Text(
              '数据预览',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: FundLensTokens.ink,
              ),
            ),
            const SizedBox(height: FundLensTokens.space2),
            _PreviewTable(table: table),
            const SizedBox(height: FundLensTokens.space4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: controller.back, child: const Text('返回')),
                const SizedBox(width: FundLensTokens.space2),
                FilledButton(
                  onPressed: controller.applyMapping,
                  child: const Text('确认映射'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MappingTable extends StatelessWidget {
  const _MappingTable({
    required this.headings,
    required this.mapping,
    required this.onChanged,
  });

  final List<String> headings;
  final Map<String, int> mapping;
  final ValueChanged<Map<String, int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: FundLensTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        side: FundLensTokens.cardBorder,
      ),
      child: Column(
        children: [
          for (final (field, label, required) in _MappingBody._systemFields)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FundLensTokens.space4,
                vertical: FundLensTokens.space2,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Noto Sans SC',
                            fontSize: 14,
                            color: FundLensTokens.ink,
                          ),
                        ),
                        if (required) ...[
                          const SizedBox(width: FundLensTokens.space1),
                          Text(
                            '必填',
                            style: TextStyle(
                              fontFamily: 'Noto Sans SC',
                              fontSize: 11,
                              color: FundLensTokens.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('mapping-$field'),
                      initialValue: mapping[field],
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: FundLensTokens.space3,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            FundLensTokens.radiusControl,
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<int>(
                          value: -1,
                          child: Text('未映射'),
                        ),
                        for (var i = 0; i < headings.length; i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              headings[i].isEmpty ? '列 ${i + 1}' : headings[i],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        final next = Map<String, int>.of(mapping);
                        if (value < 0) {
                          next.remove(field);
                        } else {
                          next[field] = value;
                        }
                        onChanged(next);
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.table});

  final TabularTable table;

  @override
  Widget build(BuildContext context) {
    final headings = table.headings;
    final preview = table.dataRows.take(8).toList();
    if (preview.isEmpty) {
      return Text(
        '文件中没有数据行',
        style: TextStyle(
          fontFamily: 'Noto Sans SC',
          fontSize: 12,
          color: FundLensTokens.muted,
        ),
      );
    }
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: FundLensTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        side: FundLensTokens.cardBorder,
      ),
      child: SingleChildScrollView(
        // 高 DPI/200% 缩放或列数较多时横向滚动而非溢出。
        scrollDirection: Axis.horizontal,
        child: Table(
          columnWidths: {
            for (var i = 0; i < headings.length; i++) i: const FlexColumnWidth(),
          },
          border: TableBorder(
            horizontalInside: BorderSide(color: FundLensTokens.border),
          ),
          children: [
          TableRow(
            decoration: BoxDecoration(color: FundLensTokens.surfaceAlt),
            children: [
              for (final heading in headings)
                Padding(
                  padding: const EdgeInsets.all(FundLensTokens.space2),
                  child: Text(
                    heading.isEmpty ? '列' : heading,
                    style: TextStyle(
                      fontFamily: 'Noto Sans SC',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FundLensTokens.ink,
                    ),
                  ),
                ),
            ],
          ),
          for (final row in preview)
            TableRow(
              children: [
                for (var i = 0; i < headings.length; i++)
                  Padding(
                    padding: const EdgeInsets.all(FundLensTokens.space2),
                    child: Text(
                      i < row.length ? row[i] : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Noto Sans SC',
                        fontSize: 12,
                        color: FundLensTokens.inkSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Public export used by the wizard page.
class ImportMappingPanel extends StatelessWidget {
  const ImportMappingPanel({
    super.key,
    required this.state,
    required this.controller,
  });

  final ImportFieldMapping state;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    return _MappingBody(state: state, controller: controller);
  }
}
