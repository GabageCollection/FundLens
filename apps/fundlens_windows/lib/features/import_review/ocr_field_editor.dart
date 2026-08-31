import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../importing/import_models.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/confirm_dialog.dart';
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

/// 不在字段区重复展示的 OCR 字段:
/// - 产品名称提升到卡片标题处编辑;
/// - 平台标签只属于来源元信息,不参与人工复核。
const _hiddenOcrFields = {
  'product_name',
  'productName',
  'platform_tags',
  'platformTags',
};

/// 预构建 (holdingIndex, field) → 阻断问题文案 的映射,供字段 tile 做 O(1) 查找。
/// 每次击键都会重建整个复审体,若每个 tile 各自线性扫描 issues 列表,
/// 单次重建代价为 O(行数² × 字段数);预建一次 map 降到 O(行数)。
/// 键用 record 而非字符串拼接,编码格式由类型保证,构建与查找无法写岔。
/// holdingIndex 可空(全局问题不归属某行),空键永远查不到,与原字符串键语义一致。
Map<(int?, String), String> _blockingIssues(ImportDraft draft) {
  final map = <(int?, String), String>{};
  for (final issue in draft.issues) {
    if (issue.severity != IssueSeverity.blocking) continue;
    map[(issue.holdingIndex, issue.field)] = issue.message;
  }
  return map;
}

/// Wizard step 3 for screenshots: left panel shows the source screenshot and
/// its focused crop; right panel lists the OCR rows as compact cards. The
/// product name is edited inline in the card title; numeric fields sit in a
/// two-column grid with the confidence badge inside each input, so a row no
/// longer repeats its provenance under every field. The user confirms only
/// after reviewing everything; nothing is written before that.
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
              TextButton(
                onPressed: () async {
                  // 返回将丢弃当前截图的识别与编辑结果:先确认再离开。
                  final leave = await showConfirmDialog(
                    context,
                    title: '返回上一步',
                    content: const Text('返回将丢弃当前截图的识别结果与编辑内容，确定返回吗？'),
                    confirmLabel: '返回',
                  );
                  if (leave && context.mounted) controller.back();
                },
                child: const Text('返回'),
              ),
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

class _OcrEditor extends StatefulWidget {
  const _OcrEditor({required this.controller});

  final ImportReviewController controller;

  @override
  State<_OcrEditor> createState() => _OcrEditorState();
}

class _OcrEditorState extends State<_OcrEditor> {
  /// 卡片与字段的定位 key:点击数据问题后 ensureVisible 跳到出错位置。
  ///
  /// key 必须按稳定行身份分配而非位置号:删除一行后,后续行位置上移,
  /// 若按位置复用 GlobalKey/ValueKey,Flutter 会把被删行的元素状态
  /// (TextFormField 内容等)迁移到后一行卡片上,造成名称/数值串行显示。
  final _cardKeys = <int, GlobalKey>{};
  final _fieldKeys = <String, GlobalKey>{};
  (String?, int)? _scrolledFocus;

  ImportReviewController get controller => widget.controller;

  /// 行的稳定身份:OCR 行用其合并时的原始序号(删除后保持不变);
  /// 非 OCR 行用负的位置号兜底,与 OCR 序号域不冲突。
  int _rowIdFor(int holdingsIndex) {
    final rows = controller.ocrRows;
    if (holdingsIndex < rows.length) return rows[holdingsIndex].index;
    return -1 - holdingsIndex;
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    if (state is! ImportOcrReview) return const SizedBox.shrink();
    final draft = state.draft;
    if (draft.holdings.isEmpty) {
      return Center(
        child: Text(
          '没有识别到持仓行，可返回重选或删除截图',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: FundLensTokens.muted),
        ),
      );
    }
    final blockingIssues = _blockingIssues(draft);
    _scheduleFocusScroll();
    return SingleChildScrollView(
      child: Column(
        children: [
          for (var index = 0; index < draft.holdings.length; index++)
            _buildCard(context, index, draft, blockingIssues),
        ],
      ),
    );
  }

  /// 数据问题点击后:聚焦签名变化时,把目标字段(拿不到字段退到整张卡片)
  /// 滚进可视区。卡片列表用 Column 而非懒加载 ListView,保证目标 key
  /// 的 context 一定已挂载,ensureVisible 不会落空。
  void _scheduleFocusScroll() {
    final index = controller.focusedHoldingIndex;
    if (index == null) return;
    final signature = (controller.focusedField, index);
    if (signature == _scrolledFocus) return;
    _scrolledFocus = signature;
    final rowId = _rowIdFor(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target =
          _fieldKeys['$rowId:${controller.focusedField}']?.currentContext ??
          _cardKeys[rowId]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  Widget _buildCard(
    BuildContext context,
    int index,
    ImportDraft draft,
    Map<(int?, String), String> blockingIssues,
  ) {
    final holding = draft.holdings[index];
    final ocrRow = index < controller.ocrRows.length
        ? controller.ocrRows[index]
        : null;
    final rowId = _rowIdFor(index);
    final cardFocused = controller.focusedHoldingIndex == index;
    return Card(
      key: _cardKeys.putIfAbsent(rowId, GlobalKey.new),
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: FundLensTokens.space2,
        vertical: FundLensTokens.space1,
      ),
      color: FundLensTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FundLensTokens.radiusCard),
        // 数据问题定位到的卡片用主色描边,一眼看到出错位置。
        side: cardFocused
            ? BorderSide(
                color: FundLensTokens.accent,
                width: FundLensTokens.focusOutlineWidth,
              )
            : FundLensTokens.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OcrCardHeader(
              index: index,
              rowId: rowId,
              productName: holding.productName,
              provenance: _provenanceLabel(holding, ocrRow),
              errorText: blockingIssues[(index, 'product_name')],
              controller: controller,
            ),
            const SizedBox(height: FundLensTokens.space1),
            Divider(height: 1, color: FundLensTokens.border),
            const SizedBox(height: FundLensTokens.space3),
            if (ocrRow != null)
              _OcrFieldGrid(
                rowIndex: index,
                rowId: rowId,
                fields: [
                  for (final field in ocrRow.fields.values)
                    if (!_hiddenOcrFields.contains(field.name)) field,
                ],
                controller: controller,
                blockingIssues: blockingIssues,
                focusedField: cardFocused ? controller.focusedField : null,
                fieldKeyFor: (name) =>
                    _fieldKeys.putIfAbsent('$rowId:$name', GlobalKey.new),
              )
            else
              _PlainFieldTile(
                index: index,
                rowId: rowId,
                field: 'currentValue',
                value: holding.currentValue.canonical,
                controller: controller,
                blockingIssues: blockingIssues,
              ),
          ],
        ),
      ),
    );
  }

  /// 卡片头部只展示一次来源:OCR 行给页码(跨页时给「跨页」),
  /// 非 OCR 行给数据出处。
  String _provenanceLabel(DraftHolding holding, OcrRow? ocrRow) {
    if (ocrRow != null && ocrRow.fields.isNotEmpty) {
      final pages = {for (final field in ocrRow.fields.values) field.pageIndex};
      if (pages.length == 1) return '截图 OCR · 第 ${pages.first + 1} 页';
      return '截图 OCR · 跨页';
    }
    return switch (holding.dataOrigin) {
      DataOrigin.csv => 'CSV 文件',
      DataOrigin.excel => 'Excel 文件',
      DataOrigin.ocr => '截图 OCR',
      DataOrigin.manual => '手动录入',
    };
  }
}

/// 卡片头:产品名称就地编辑(标题样式),右侧是来源与删除操作。
class _OcrCardHeader extends StatelessWidget {
  const _OcrCardHeader({
    required this.index,
    required this.rowId,
    required this.productName,
    required this.provenance,
    required this.errorText,
    required this.controller,
  });

  /// 持仓在草稿中的位置号:用于编辑回写与提示文案。
  final int index;

  /// 稳定行身份:用于 widget key,删除其他行后本行状态不串位。
  final int rowId;
  final String productName;
  final String provenance;
  final String? errorText;
  final ImportReviewController controller;

  @override
  Widget build(BuildContext context) {
    final styles = FundLensTextStyles.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextFormField(
            key: ValueKey('ocr-title-$rowId'),
            initialValue: productName,
            style: styles.subsectionTitle,
            decoration: InputDecoration(
              hintText: '持仓 ${index + 1}',
              hintStyle: styles.subsectionTitle.copyWith(
                color: FundLensTokens.muted,
              ),
              errorText: errorText,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: FundLensTokens.space2,
              ),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.transparent),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: FundLensTokens.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: FundLensTokens.accent,
                  width: FundLensTokens.focusOutlineWidth,
                ),
              ),
            ),
            onTap: () => controller.focusField('product_name', index),
            onChanged: (value) =>
                controller.updateHoldingField(index, 'product_name', value),
          ),
        ),
        const SizedBox(width: FundLensTokens.space2),
        Text(
          provenance,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: FundLensTokens.muted),
        ),
        const SizedBox(width: FundLensTokens.space1),
        TextButton.icon(
          onPressed: () => controller.removeOcrRow(index),
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('删除'),
        ),
      ],
    );
  }
}

/// 字段网格:卡片够宽时两列排布,窄时单列;字段之间用统一间距,
/// 不再为每个字段重复来源行。
class _OcrFieldGrid extends StatelessWidget {
  const _OcrFieldGrid({
    required this.rowIndex,
    required this.rowId,
    required this.fields,
    required this.controller,
    required this.blockingIssues,
    required this.focusedField,
    required this.fieldKeyFor,
  });

  final int rowIndex;
  final int rowId;
  final List<OcrFieldValue> fields;
  final ImportReviewController controller;
  final Map<(int?, String), String> blockingIssues;

  /// 本卡片当前被数据问题定位的字段名;无定位时为 null。
  final String? focusedField;

  /// 字段定位 key 的惰性分配,供 ensureVisible 滚动到出错字段。
  final GlobalKey Function(String fieldName) fieldKeyFor;

  /// 两列排布所需的最小卡片内容宽度;低于该值退化为单列。
  static const _twoColumnMinWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = FundLensTokens.space4;
        final twoColumns = constraints.maxWidth >= _twoColumnMinWidth;
        final tileWidth = twoColumns
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: FundLensTokens.space2,
          children: [
            for (final field in fields)
              SizedBox(
                key: fieldKeyFor(field.name),
                width: tileWidth,
                child: _OcrFieldTile(
                  rowIndex: rowIndex,
                  rowId: rowId,
                  field: field,
                  focused: focusedField == field.name,
                  controller: controller,
                  blockingIssues: blockingIssues,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OcrFieldTile extends StatelessWidget {
  const _OcrFieldTile({
    required this.rowIndex,
    required this.rowId,
    required this.field,
    required this.focused,
    required this.controller,
    required this.blockingIssues,
  });

  final int rowIndex;

  /// 稳定行身份:用于 widget key,删除其他行后本行字段状态不串位。
  final int rowId;
  final OcrFieldValue field;

  /// 被数据问题定位时用主色描边突出显示。
  final bool focused;
  final ImportReviewController controller;
  final Map<(int?, String), String> blockingIssues;

  @override
  Widget build(BuildContext context) {
    final percent = (field.confidence * 100).round();
    final lowConfidence = field.confidence < 0.9;
    // 非法输入(金额无法解析等)在字段下方就近提示,而非藏在汇总列表。
    final errorText = blockingIssues[(rowIndex, field.name)];
    return TextFormField(
      key: ValueKey('ocr-field-${field.name}-$rowId'),
      initialValue: field.rawText,
      decoration: InputDecoration(
        labelText: fieldLabel(field.name),
        errorText: errorText,
        // 置信徽标收进输入框尾部,不再单独占一整列。
        suffixIcon: _ConfidenceChip(
          percent: percent,
          lowConfidence: lowConfidence,
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: focused
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  FundLensTokens.radiusControl,
                ),
                borderSide: BorderSide(
                  color: FundLensTokens.accent,
                  width: FundLensTokens.focusOutlineWidth,
                ),
              )
            : lowConfidence
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  FundLensTokens.radiusControl,
                ),
                borderSide: BorderSide(color: FundLensTokens.warn),
              )
            : null,
      ),
      onTap: () => controller.focusField(field.name, rowIndex),
      onChanged: (value) =>
          controller.updateHoldingField(rowIndex, field.name, value),
    );
  }
}

/// 输入框尾部的紧凑置信徽标;低置信时用警示底色。
class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.percent, required this.lowConfidence});

  final int percent;
  final bool lowConfidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: FundLensTokens.space2),
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
        style:
            (lowConfidence
                    ? FundLensTextStyles.of(context).auxStrong
                    : Theme.of(context).textTheme.bodySmall)
                ?.copyWith(
                  color: lowConfidence
                      ? FundLensTokens.warnText
                      : FundLensTokens.muted,
                ),
      ),
    );
  }
}

class _PlainFieldTile extends StatelessWidget {
  const _PlainFieldTile({
    required this.index,
    required this.rowId,
    required this.field,
    required this.value,
    required this.controller,
    required this.blockingIssues,
  });

  final int index;
  final int rowId;
  final String field;
  final String value;
  final ImportReviewController controller;
  final Map<(int?, String), String> blockingIssues;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey('ocr-field-$field-$rowId'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: fieldLabel(field),
        errorText: blockingIssues[(index, field)],
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
