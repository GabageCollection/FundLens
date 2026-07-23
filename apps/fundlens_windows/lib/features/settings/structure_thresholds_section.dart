import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../theme/fundlens_tokens.dart';
import '../analysis/structure_thresholds.dart';

/// Optional user-set structure thresholds.
///
/// Every threshold is opt-in: nothing is editable until the user taps
/// “添加结构阈值”, and each row is labeled “由你设置，仅用于结构提示” so the
/// values can never read as ideal defaults or advice.
class StructureThresholdsSection extends ConsumerStatefulWidget {
  const StructureThresholdsSection({super.key});

  @override
  ConsumerState<StructureThresholdsSection> createState() =>
      _StructureThresholdsSectionState();
}

class _StructureThresholdsSectionState
    extends ConsumerState<StructureThresholdsSection> {
  bool _editing = false;

  static const _fields = <
      ({
    String key,
    String label,
    DecimalValue? Function(StructureThresholds) read,
    StructureThresholds Function(StructureThresholds, DecimalValue?) write,
  })>[
    (
      key: 'maxSingleHoldingShare',
      label: '单一持仓占比上限',
      read: _readMaxSingle,
      write: _writeMaxSingle,
    ),
    (
      key: 'maxAssetClassShare',
      label: '单一类别占比上限',
      read: _readMaxClass,
      write: _writeMaxClass,
    ),
    (
      key: 'minCashAndDepositShare',
      label: '现金及存款占比下限',
      read: _readMinCash,
      write: _writeMinCash,
    ),
    (
      key: 'maxEquityExposureShare',
      label: '权益仓位占比上限',
      read: _readMaxEquity,
      write: _writeMaxEquity,
    ),
  ];

  static DecimalValue? _readMaxSingle(StructureThresholds t) =>
      t.maxSingleHoldingShare;
  static DecimalValue? _readMaxClass(StructureThresholds t) =>
      t.maxAssetClassShare;
  static DecimalValue? _readMinCash(StructureThresholds t) =>
      t.minCashAndDepositShare;
  static DecimalValue? _readMaxEquity(StructureThresholds t) =>
      t.maxEquityExposureShare;

  static StructureThresholds _writeMaxSingle(
    StructureThresholds t,
    DecimalValue? v,
  ) =>
      StructureThresholds(
        maxSingleHoldingShare: v,
        maxAssetClassShare: t.maxAssetClassShare,
        minCashAndDepositShare: t.minCashAndDepositShare,
        maxEquityExposureShare: t.maxEquityExposureShare,
      );

  static StructureThresholds _writeMaxClass(
    StructureThresholds t,
    DecimalValue? v,
  ) =>
      StructureThresholds(
        maxSingleHoldingShare: t.maxSingleHoldingShare,
        maxAssetClassShare: v,
        minCashAndDepositShare: t.minCashAndDepositShare,
        maxEquityExposureShare: t.maxEquityExposureShare,
      );

  static StructureThresholds _writeMinCash(
    StructureThresholds t,
    DecimalValue? v,
  ) =>
      StructureThresholds(
        maxSingleHoldingShare: t.maxSingleHoldingShare,
        maxAssetClassShare: t.maxAssetClassShare,
        minCashAndDepositShare: v,
        maxEquityExposureShare: t.maxEquityExposureShare,
      );

  static StructureThresholds _writeMaxEquity(
    StructureThresholds t,
    DecimalValue? v,
  ) =>
      StructureThresholds(
        maxSingleHoldingShare: t.maxSingleHoldingShare,
        maxAssetClassShare: t.maxAssetClassShare,
        minCashAndDepositShare: t.minCashAndDepositShare,
        maxEquityExposureShare: v,
      );

  static bool _hasAny(StructureThresholds t) {
    return t.maxSingleHoldingShare != null ||
        t.maxAssetClassShare != null ||
        t.minCashAndDepositShare != null ||
        t.maxEquityExposureShare != null;
  }

  void _onChanged(
    String text,
    StructureThresholds Function(StructureThresholds, DecimalValue?) write,
  ) {
    final trimmed = text.trim();
    DecimalValue? share;
    if (trimmed.isNotEmpty) {
      final DecimalValue percent;
      try {
        percent = DecimalValue.parse(trimmed);
      } on FormatException {
        return;
      }
      if (percent.isNegative) return;
      share = percent.divide(DecimalValue.parse('100'));
    }
    final current = ref.read(structureThresholdsProvider);
    ref.read(structureThresholdsProvider.notifier).state =
        write(current, share);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thresholds = ref.watch(structureThresholdsProvider);
    final editing = _editing || _hasAny(thresholds);

    return SettingsSectionCard(
      title: '结构阈值',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阈值完全可选；未设置时资产分析只显示实际值，不做判断。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (!editing)
            FilledButton.tonal(
              onPressed: () => setState(() => _editing = true),
              child: const Text('添加结构阈值'),
            )
          else
            for (final field in _fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(field.label, style: theme.textTheme.bodyMedium),
                          Text(
                            '由你设置，仅用于结构提示',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: TextFormField(
                        key: ValueKey('threshold-${field.key}'),
                        initialValue: _percentText(field.read(thresholds)),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          suffixText: '%',
                          isDense: true,
                        ),
                        onChanged: (text) => _onChanged(text, field.write),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  static String _percentText(DecimalValue? share) {
    if (share == null) return '';
    return (share.value.toDouble() * 100).toStringAsFixed(1);
  }
}

/// Paper section card shared by the settings sections.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FundLensTokens.paper,
        borderRadius: BorderRadius.circular(FundLensTokens.radiusMedium),
        border: Border.all(color: FundLensTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
