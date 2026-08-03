import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';
import 'package:uuid/uuid.dart';

import '../../theme/fundlens_tokens.dart';
import '../../widgets/confirm_dialog.dart';
import 'holding_filters.dart';

const _uuid = Uuid();

/// Opens the manual holding editor. Returns the submitted [Holding], or null
/// when the user cancels.
Future<Holding?> showHoldingEditorDialog(
  BuildContext context, {
  Holding? initial,
}) {
  return showDialog<Holding>(
    context: context,
    builder: (context) => HoldingEditorDialog(initial: initial),
  );
}

/// Asks the user to confirm deleting [holding]. The dialog always names the
/// product so the target of the destructive action is unambiguous.
Future<bool> showHoldingDeleteConfirmation(
  BuildContext context,
  Holding holding,
) {
  return showConfirmDialog(
    context,
    title: '删除持仓',
    content: Text('确定删除「${holding.productName}」吗？此操作不可撤销。'),
    confirmLabel: '删除',
    destructive: true,
  );
}

/// Manual add/edit form for one holding.
///
/// Validation is field-level: product name and current amount are required,
/// optional decimal fields must parse. Submission always produces a complete
/// [Holding] with [DataOrigin.manual] and user-corrected provenance on every
/// field the form touched.
class HoldingEditorDialog extends StatefulWidget {
  const HoldingEditorDialog({super.key, this.initial, this.onSubmit});

  /// Existing holding to edit; null creates a new manual holding.
  final Holding? initial;

  /// Test seam: invoked with the built holding before the dialog pops.
  final void Function(Holding holding)? onSubmit;

  @override
  State<HoldingEditorDialog> createState() => _HoldingEditorDialogState();
}

class _HoldingEditorDialogState extends State<HoldingEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late SourcePlatform _source;
  late InstrumentType _instrumentType;
  late AssetClass _assetClass;

  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _amountController;
  late final TextEditingController _costController;
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _source = initial?.sourcePlatform ?? SourcePlatform.manual;
    _instrumentType = initial?.instrumentType ?? InstrumentType.offExchangeFund;
    _assetClass = initial?.assetClass ?? AssetClass.other;
    _nameController = TextEditingController(text: initial?.productName ?? '');
    _codeController = TextEditingController(text: initial?.productCode ?? '');
    _quantityController = TextEditingController(
      text: initial?.quantity?.canonical ?? '',
    );
    _priceController = TextEditingController(
      text: initial?.currentPrice?.canonical ?? '',
    );
    _amountController = TextEditingController(
      text: initial?.currentValue.canonical ?? '',
    );
    _costController = TextEditingController(
      text: initial?.costAmount?.canonical ?? '',
    );
    _dateController = TextEditingController(
      text: initial?.valuationDate == null
          ? ''
          : HoldingValueDate.format(initial!.valuationDate!),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _amountController.dispose();
    _costController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _optionalDecimal(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _decimal(value);
  }

  String? _decimal(String? value) {
    if (value == null || value.trim().isEmpty) return '金额格式不正确';
    try {
      DecimalValue.parse(value.trim());
      return null;
    } on Exception {
      return '金额格式不正确';
    }
  }

  String? _optionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim()) == null ? '日期格式应为 YYYY-MM-DD' : null;
  }

  DecimalValue? _parseOptional(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return DecimalValue.parse(trimmed);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final initial = widget.initial;
    final now = DateTime.now().toUtc();
    final quantity = _parseOptional(_quantityController.text);
    final price = _parseOptional(_priceController.text);
    final amount = DecimalValue.parse(_amountController.text.trim());
    final cost = _parseOptional(_costController.text);
    final code = _codeController.text.trim();
    final note = _noteController.text.trim();
    final dateText = _dateController.text.trim();

    const provenance = FieldProvenance(
      kind: ProvenanceKind.userCorrected,
      source: '手工编辑',
    );

    final holding = Holding(
      id: initial?.id ?? _uuid.v4(),
      sourcePlatform: _source,
      instrumentType: _instrumentType,
      assetClass: _assetClass,
      productName: _nameController.text.trim(),
      productCode: code.isEmpty ? null : code,
      currency: initial?.currency ?? 'CNY',
      quantity: quantity,
      availableQuantity: initial?.availableQuantity,
      currentPrice: price,
      costPrice: initial?.costPrice,
      currentValue: amount,
      costAmount: cost,
      holdingProfit: initial?.holdingProfit,
      holdingReturn: initial?.holdingReturn,
      dailyProfit: initial?.dailyProfit,
      cumulativeProfit: initial?.cumulativeProfit,
      platformTags: initial?.platformTags ?? const [],
      valuationMethod: quantity != null && price != null
          ? ValuationMethod.quantityTimesPrice
          : ValuationMethod.manualAmount,
      valuationDate: dateText.isEmpty
          ? null
          : DateTime.tryParse(dateText)?.toUtc(),
      dataOrigin: DataOrigin.manual,
      fieldProvenance: {
        ...?initial?.fieldProvenance,
        'productName': provenance,
        'currentValue': provenance,
        if (code.isNotEmpty) 'productCode': provenance,
        if (quantity != null) 'quantity': provenance,
        if (price != null) 'currentPrice': provenance,
        if (cost != null) 'costAmount': provenance,
      },
      note: note.isEmpty ? null : note,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );

    widget.onSubmit?.call(holding);
    Navigator.of(context).maybePop(holding);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? '添加持仓' : '编辑持仓'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _enumField<SourcePlatform>(
                        label: '数据来源',
                        value: _source,
                        labels: HoldingLabels.sourcePlatform,
                        onChanged: (v) => setState(() => _source = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _enumField<InstrumentType>(
                        label: '产品形态',
                        value: _instrumentType,
                        labels: HoldingLabels.instrumentType,
                        onChanged: (v) => setState(() => _instrumentType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _enumField<AssetClass>(
                        label: '资产类别',
                        value: _assetClass,
                        labels: HoldingLabels.assetClass,
                        onChanged: (v) => setState(() => _assetClass = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FundLensTokens.formGap),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '产品名称'),
                  validator: (v) => _required(v, '请输入产品名称'),
                ),
                const SizedBox(height: FundLensTokens.formGap),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: '产品代码'),
                ),
                const SizedBox(height: FundLensTokens.formGap),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(labelText: '份额'),
                        validator: _optionalDecimal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: '现价'),
                        validator: _optionalDecimal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FundLensTokens.formGap),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(labelText: '当前金额'),
                        validator: (v) =>
                            _required(v, '请输入当前金额') ?? _decimal(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        decoration: const InputDecoration(labelText: '成本金额'),
                        validator: _optionalDecimal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FundLensTokens.formGap),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: '估值日期',
                    hintText: 'YYYY-MM-DD',
                  ),
                  validator: _optionalDate,
                ),
                const SizedBox(height: FundLensTokens.formGap),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '保存后该持仓标记为手工录入，字段来源记为你确认的值。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _enumField<T>({
    required String label,
    required T value,
    required Map<T, String> labels,
    required void Function(T value) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final entry in labels.entries)
          DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Date rendering used by the editor's initial value.
abstract final class HoldingValueDate {
  static String format(DateTime value) {
    final utc = value.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
