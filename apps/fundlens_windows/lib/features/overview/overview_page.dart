import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../application/portfolio_state.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_scaffold.dart';
import '../holdings/holding_editor_dialog.dart';
import 'asset_spectrum.dart';
import 'insight_list.dart';
import 'summary_strip.dart';
import 'top_holdings_table.dart';
import 'trend_chart.dart';

/// 资产总览 page:直接回答五个问题——
/// 当前有多少资产(KPI)、最近如何变化(净值趋势)、资产集中在哪里
/// (资产结构带)、哪些持仓贡献盈亏(最高持仓表)、需要处理哪些数据或
/// 风险问题(风险与数据提醒)。
class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioStateProvider);
    return PageScaffold(
      tier: PageWidthTier.standard,
      crumb: '组合',
      title: '资产总览',
      body: switch (state) {
        PortfolioLoading() => const LoadingView(label: '正在加载资产总览…'),
        PortfolioDegraded(:final error) => Center(child: Text('数据暂时不可用：$error')),
        PortfolioEmpty() => Center(
          child: FilledButton.icon(
            key: const ValueKey('overview-add-first-asset'),
            onPressed: () => _addFirstAsset(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加第一项资产'),
          ),
        ),
        PortfolioReady() => const _OverviewContent(),
      },
    );
  }

  Future<void> _addFirstAsset(BuildContext context, WidgetRef ref) async {
    final holding = await showHoldingEditorDialog(context);
    if (holding == null) return;
    await ref.read(holdingRepositoryProvider).upsert(holding);
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: FundLensTokens.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SummaryStrip(),
          const SizedBox(height: FundLensTokens.cardGap),
          const _StructureBandCard(),
          const SizedBox(height: FundLensTokens.cardGap),
          // 主体 8+4:左侧净值趋势,右侧风险与数据提醒;窄屏堆叠。
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= FundLensTokens.gridCollapseBelow) {
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 8, child: PortfolioTrendChart()),
                    SizedBox(width: FundLensTokens.gridGutter),
                    Expanded(flex: 4, child: OverviewInsightList()),
                  ],
                );
              }
              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PortfolioTrendChart(),
                  SizedBox(height: FundLensTokens.cardGap),
                  OverviewInsightList(),
                ],
              );
            },
          ),
          const SizedBox(height: FundLensTokens.cardGap),
          const TopHoldingsTable(),
        ],
      ),
    );
  }
}

/// 资产结构带卡:按资产类别把总资产显示为比例分段带 + 图例。
class _StructureBandCard extends StatelessWidget {
  const _StructureBandCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '资产结构',
              style: Theme.of(
                context,
              ).extension<FundLensTextStyles>()!.sectionTitle,
            ),
            const SizedBox(height: FundLensTokens.space3),
            const AssetSpectrum(),
          ],
        ),
      ),
    );
  }
}
