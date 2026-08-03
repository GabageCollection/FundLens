import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/app_dependencies.dart';
import '../../application/portfolio_providers.dart';
import '../../application/portfolio_state.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../../widgets/error_retry_view.dart';
import '../../widgets/grid_row.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_scaffold.dart';
import '../holdings/holding_editor_dialog.dart';
import 'analysis_chart.dart';
import 'analysis_conclusions.dart';
import 'structure_thresholds.dart';

/// 资产分析页:三个构成维度(Tabs) + 图表 + 分析结论。
///
/// 只描述资产事实与数据质量,不输出任何投资行为措辞。
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: AnalysisDimension.values.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addFirstAsset(BuildContext context) async {
    final holding = await showHoldingEditorDialog(context);
    if (holding == null) return;
    await ref.read(holdingRepositoryProvider).upsert(holding);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioStateProvider);
    return PageScaffold(
      tier: PageWidthTier.standard,
      crumb: '组合',
      title: '资产分析',
      body: switch (state) {
        PortfolioLoading() => const LoadingView(label: '正在加载资产分析…'),
        PortfolioDegraded() => ErrorRetryView(
          title: '资产分析暂时不可用',
          message: '持仓数据加载失败，本地数据未受影响，请重试。',
          onRetry: () => ref.invalidate(holdingsProvider),
        ),
        PortfolioEmpty() => Center(
          child: FilledButton.icon(
            key: const ValueKey('analysis-add-first-asset'),
            onPressed: () => _addFirstAsset(context),
            icon: const Icon(Icons.add),
            label: const Text('添加第一项资产'),
          ),
        ),
        PortfolioReady() => _AnalysisBody(tabController: _tabController),
      },
    );
  }
}

/// 主体:左 8 列图表卡 + 右 4 列结论卡;窄屏堆叠。
class _AnalysisBody extends ConsumerWidget {
  const _AnalysisBody({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final quality = ref.watch(dataQualityProvider);
    final holdings = ref.watch(holdingsProvider).value ?? <Holding>[];
    final thresholds = ref.watch(structureThresholdsProvider);
    final freshQuoteHoldingIds = ref.watch(freshQuoteHoldingIdsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: FundLensTokens.pagePadding),
      child: GridRow(
        children: [
          GridCol(span: 8, child: _CompositionChartCard(tabController: tabController)),
          GridCol(
            span: 4,
            child: AnalysisConclusionsCard(
              items: buildAnalysisConclusions(
                summary: summary,
                quality: quality,
                holdings: holdings,
                thresholds: thresholds,
                freshQuoteHoldingIds: freshQuoteHoldingIds,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 左卡:标题 + 可访问 Tabs + 固定高度图表区(切换仅换内容,布局稳定)。
class _CompositionChartCard extends ConsumerWidget {
  const _CompositionChartCard({required this.tabController});

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(portfolioSummaryProvider);
    // TabController 是 ChangeNotifier:监听 index 变化,切换 Tab 时重绘图表区。
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        final dimension = AnalysisDimension.values[tabController.index];
        final rows = buildChartRows(summary, dimension);
        return _buildCard(theme, dimension, rows);
      },
    );
  }

  Widget _buildCard(ThemeData theme, AnalysisDimension dimension, List<ChartBarRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(FundLensTokens.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '资产构成',
              style: theme.extension<FundLensTextStyles>()!.sectionTitle,
            ),
            const SizedBox(height: FundLensTokens.space4),
            TabBar(
              controller: tabController,
              indicatorColor: FundLensTokens.accent,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: FundLensTokens.border,
              labelColor: FundLensTokens.ink,
              unselectedLabelColor: FundLensTokens.muted,
              labelStyle: const TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Noto Sans SC',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: [
                for (final d in AnalysisDimension.values)
                  Tab(text: dimensionLabels[d]),
              ],
            ),
            const SizedBox(height: FundLensTokens.space3),
            SizedBox(
              height: 264,
              key: const ValueKey('analysis-chart-area'),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (dimension) {
                  AnalysisDimension.source => PlatformProportionBar(
                    key: const ValueKey('platform-proportion-bar'),
                    rows: rows,
                  ),
                  _ => HorizontalBarChart(
                    key: const ValueKey('horizontal-bar-chart'),
                    rows: rows,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
