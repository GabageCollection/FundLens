import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../theme/fundlens_tokens.dart';
import '../analysis/structure_thresholds.dart';
import 'persisted_settings.dart';
import 'widgets/settings_section_card.dart';

/// 资产识别规则:影响资产分析页「资产结构提示」的可选参数。
///
/// 技术性参数折叠在「高级设置」中,每项提供说明、默认值、恢复默认与修改影响。
/// 所有值 opt-in:未设置时资产分析只显示实际值,不做判断。
class AssetRulesSection extends ConsumerWidget {
  const AssetRulesSection({super.key});

  static const _fields =
      <
        ({
          String key,
          String label,
          String description,
          String impact,
          DecimalValue? Function(StructureThresholds) read,
          StructureThresholds Function(StructureThresholds, DecimalValue?)
          write,
        })
      >[
        (
          key: 'maxSingleHoldingShare',
          label: '单一持仓占比上限',
          description: '单只产品市值占组合的比例上限。',
          impact: '超过该比例时，资产分析页显示结构提示。',
          read: _readMaxSingle,
          write: _writeMaxSingle,
        ),
        (
          key: 'maxAssetClassShare',
          label: '单一类别占比上限',
          description: '单类资产(如权益、固收)占组合的比例上限。',
          impact: '超过该比例时，资产分析页显示结构提示。',
          read: _readMaxClass,
          write: _writeMaxClass,
        ),
        (
          key: 'minCashAndDepositShare',
          label: '现金及存款占比下限',
          description: '现金及存款占组合的比例下限。',
          impact: '低于该比例时，资产分析页显示结构提示。',
          read: _readMinCash,
          write: _writeMinCash,
        ),
        (
          key: 'maxEquityExposureShare',
          label: '权益仓位占比上限',
          description: '权益类资产占组合的比例上限。',
          impact: '超过该比例时，资产分析页显示结构提示。',
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
  ) => StructureThresholds(
    maxSingleHoldingShare: v,
    maxAssetClassShare: t.maxAssetClassShare,
    minCashAndDepositShare: t.minCashAndDepositShare,
    maxEquityExposureShare: t.maxEquityExposureShare,
  );

  static StructureThresholds _writeMaxClass(
    StructureThresholds t,
    DecimalValue? v,
  ) => StructureThresholds(
    maxSingleHoldingShare: t.maxSingleHoldingShare,
    maxAssetClassShare: v,
    minCashAndDepositShare: t.minCashAndDepositShare,
    maxEquityExposureShare: t.maxEquityExposureShare,
  );

  static StructureThresholds _writeMinCash(
    StructureThresholds t,
    DecimalValue? v,
  ) => StructureThresholds(
    maxSingleHoldingShare: t.maxSingleHoldingShare,
    maxAssetClassShare: t.maxAssetClassShare,
    minCashAndDepositShare: v,
    maxEquityExposureShare: t.maxEquityExposureShare,
  );

  static StructureThresholds _writeMaxEquity(
    StructureThresholds t,
    DecimalValue? v,
  ) => StructureThresholds(
    maxSingleHoldingShare: t.maxSingleHoldingShare,
    maxAssetClassShare: t.maxAssetClassShare,
    minCashAndDepositShare: t.minCashAndDepositShare,
    maxEquityExposureShare: v,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final thresholds = ref.watch(structureThresholdsProvider);

    return SettingsSectionCard(
      key: const ValueKey('asset-rules-section'),
      title: '资产识别规则',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '以下参数影响资产分析页的「资产结构提示」。未设置时不做任何判断。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            key: const ValueKey('asset-rules-advanced'),
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              '高级设置',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            children: [
              for (final field in _fields)
                _ParameterRow(
                  field: field,
                  value: field.read(thresholds),
                  onChanged: (text) => _onChanged(ref, field, text),
                  onReset: () => _onChanged(ref, field, ''),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _onChanged(
    WidgetRef ref,
    ({String key, String label, String description, String impact, DecimalValue? Function(StructureThresholds) read, StructureThresholds Function(StructureThresholds, DecimalValue?) write}) field,
    String text,
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
    ref.read(structureThresholdsProvider.notifier).state = field.write(
      current,
      share,
    );
    unawaited(_persistThreshold(ref, field.key, share));
  }

  Future<void> _persistThreshold(WidgetRef ref, String fieldKey, DecimalValue? share) async {
    final settingKey = _settingKeyFor(fieldKey);
    if (share == null) {
      try {
        await ref.read(appSettingsRepositoryProvider).delete(settingKey);
      } catch (_) {
        // 落盘失败不阻断;下次启动回退。
      }
    } else {
      await persistSetting(ref.container, settingKey, share.canonical);
    }
  }

  static String _settingKeyFor(String fieldKey) {
    return switch (fieldKey) {
      'maxSingleHoldingShare' => SettingKeys.thresholdMaxSingleHolding,
      'maxAssetClassShare' => SettingKeys.thresholdMaxAssetClass,
      'minCashAndDepositShare' => SettingKeys.thresholdMinCashAndDeposit,
      'maxEquityExposureShare' => SettingKeys.thresholdMaxEquityExposure,
      _ => throw ArgumentError('未知阈值字段: $fieldKey'),
    };
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({
    required this.field,
    required this.value,
    required this.onChanged,
    required this.onReset,
  });

  final ({
    String key,
    String label,
    String description,
    String impact,
    DecimalValue? Function(StructureThresholds) read,
    StructureThresholds Function(StructureThresholds, DecimalValue?) write,
  }) field;
  final DecimalValue? value;
  final ValueChanged<String> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.label, style: theme.textTheme.bodyMedium),
                    Text(field.description, style: theme.textTheme.bodySmall),
                    Text(
                      value == null
                          ? '默认：未设置（不提示）'
                          : '已设置；恢复默认后回到未设置',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 140,
                child: TextFormField(
                  key: ValueKey('threshold-${field.key}'),
                  initialValue: _percentText(value),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(suffixText: '%'),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  field.impact,
                  // outline 令牌是边框色(#E4DED1),用作正文会近乎隐形(≈1.3:1);
                  // 影响说明文字用 muted。
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: FundLensTokens.muted),
                ),
              ),
              TextButton(
                onPressed: value == null ? null : onReset,
                child: const Text('恢复默认'),
              ),
            ],
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
