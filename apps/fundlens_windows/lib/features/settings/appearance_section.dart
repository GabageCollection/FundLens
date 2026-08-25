import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/fundlens_tokens.dart';
import 'persisted_settings.dart';
import 'widgets/settings_section_card.dart';

/// 外观设置:主题模式(跟随系统/浅色/深色)与表格行密度(舒适/紧凑)。
/// 选择立即生效并持久化到加密数据库,下次启动自动恢复。
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final density = ref.watch(tableDensityProvider);
    return SettingsSectionCard(
      key: const ValueKey('appearance-section'),
      title: '外观',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('主题模式', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: FundLensTokens.space2),
          SegmentedButton<ThemeModePreference>(
            segments: const [
              ButtonSegment(
                value: ThemeModePreference.system,
                label: Text('跟随系统'),
              ),
              ButtonSegment(
                value: ThemeModePreference.light,
                label: Text('浅色'),
              ),
              ButtonSegment(
                value: ThemeModePreference.dark,
                label: Text('深色'),
              ),
            ],
            selected: {themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final mode = selection.single;
              ref.read(themeModeProvider.notifier).state = mode;
              unawaited(
                persistSetting(
                  ref.container,
                  SettingKeys.uiThemeMode,
                  mode.name,
                ),
              );
            },
          ),
          const SizedBox(height: FundLensTokens.space4),
          Text('表格行密度', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: FundLensTokens.space2),
          SegmentedButton<TableDensity>(
            segments: const [
              ButtonSegment(
                value: TableDensity.comfortable,
                label: Text('舒适'),
              ),
              ButtonSegment(
                value: TableDensity.compact,
                label: Text('紧凑'),
              ),
            ],
            selected: {density},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              final value = selection.single;
              ref.read(tableDensityProvider.notifier).state = value;
              unawaited(
                persistSetting(
                  ref.container,
                  SettingKeys.uiTableDensity,
                  value.name,
                ),
              );
            },
          ),
          const SizedBox(height: FundLensTokens.space2),
          Text(
            '紧凑密度将全部持仓表格行高从 56 调整为 44。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}