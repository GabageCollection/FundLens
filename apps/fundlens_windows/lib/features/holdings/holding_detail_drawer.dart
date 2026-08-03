import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../theme/fundlens_theme.dart';
import '../../theme/fundlens_tokens.dart';
import '../data_health/data_health_providers.dart';
import 'holding_actions.dart';
import 'holding_filters.dart';
import 'holding_status.dart';

/// 打开右侧持仓详情抽屉。
Future<void> showHoldingDetailDrawer(BuildContext context, String holdingId) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭持仓详情',
    barrierColor: const Color(0x61000000),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 400,
          height: double.infinity,
          child: HoldingDetailDrawer(holdingId: holdingId),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return SlideTransition(position: offset, child: child);
    },
  );
}

/// 基本信息分节行。
List<(String, String)> drawerBasicRows(Holding h) {
  return [
    ('产品名称', h.productName),
    ('产品代码', h.productCode ?? '未填写'),
    ('产品形态', HoldingLabels.instrumentType[h.instrumentType]!),
    ('资产类别', HoldingLabels.assetClass[h.assetClass]!),
    ('币种', h.currency),
    ('备注', h.note ?? '未填写'),
  ];
}

/// 来源平台分节行。
List<(String, String)> drawerPlatformRows(Holding h) {
  return [
    ('来源平台', HoldingLabels.sourcePlatform[h.sourcePlatform]!),
    ('数据出处', HoldingLabels.dataOrigin[h.dataOrigin]!),
    ('估值方式', HoldingLabels.valuationMethod[h.valuationMethod]!),
    ('组合标签', h.platformTags.isEmpty ? '未填写' : h.platformTags.join('、')),
  ];
}

/// 当前金额分节行;share 为 null 时占比显示"不适用"。
List<(String, String)> drawerAmountRows(Holding h, DecimalValue? share) {
  return [
    ('当前金额', '¥${HoldingValueFormatter.amount(h.currentValue)}'),
    ('资产占比', holdingShareText(share)),
  ];
}

/// 红盈利绿亏损的着色映射;方向缺失(缺少成本等)或零值(中性)时
/// 返回 null 保持默认文字色。
Color? _pnlColor(PnlDirection? direction) {
  return switch (direction) {
    PnlDirection.positive => FundLensTokens.profit,
    PnlDirection.negative => FundLensTokens.loss,
    // 零值:既非盈也非亏,保持默认正文色。
    PnlDirection.zero || null => null,
  };
}

/// 成本与收益分节行。
List<(String, String)> drawerProfitRows(Holding h) {
  return [
    ('覆盖成本', holdingCostText(h)),
    ('持仓盈亏', holdingProfitText(h)),
    ('持仓收益率', holdingReturnText(h)),
    (
      '当日盈亏',
      h.dailyProfit == null
          ? (h.valuationMethod == ValuationMethod.manualAmount ? '不适用' : '暂无行情')
          : HoldingValueFormatter.signedAmount(h.dailyProfit),
    ),
    (
      '累计盈亏',
      h.cumulativeProfit == null
          ? '不适用'
          : HoldingValueFormatter.signedAmount(h.cumulativeProfit),
    ),
  ];
}

/// 数据来源分节行:按字段来源类型汇总计数。
List<(String, String)> drawerProvenanceRows(Holding h) {
  final counts = <ProvenanceKind, int>{};
  for (final provenance in h.fieldProvenance.values) {
    counts[provenance.kind] = (counts[provenance.kind] ?? 0) + 1;
  }
  if (counts.isEmpty) return [('字段来源', '无字段来源记录')];
  return [
    if ((counts[ProvenanceKind.original] ?? 0) > 0)
      ('原始确认', '${counts[ProvenanceKind.original]} 项'),
    if ((counts[ProvenanceKind.inferred] ?? 0) > 0)
      ('系统推断', '${counts[ProvenanceKind.inferred]} 项'),
    if ((counts[ProvenanceKind.market] ?? 0) > 0)
      ('行情更新', '${counts[ProvenanceKind.market]} 项'),
    if ((counts[ProvenanceKind.userCorrected] ?? 0) > 0)
      ('人工修正', '${counts[ProvenanceKind.userCorrected]} 项'),
  ];
}

/// 最后更新分节行。
List<(String, String)> drawerUpdatedRows(Holding h) {
  final local = h.updatedAt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return [
    ('最后更新', '$y-$m-$d $hh:$mm'),
    ('估值日期', holdingValuationDateText(h)),
  ];
}

/// 右侧持仓详情抽屉:六个分节 + 编辑/刷新/删除操作。
///
/// 内容按 holdingId 从 holdingsProvider 实时解析,编辑或行情刷新后
/// 自动呈现最新值;持仓被删除时自动关闭。
class HoldingDetailDrawer extends ConsumerWidget {
  const HoldingDetailDrawer({super.key, required this.holdingId});

  final String holdingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdings = ref.watch(holdingsProvider).value;
    Holding? holding;
    if (holdings != null) {
      for (final h in holdings) {
        if (h.id == holdingId) {
          holding = h;
          break;
        }
      }
    }
    // 数据加载中:静默占位,等待流送达后再渲染,不弹出路由。
    if (holdings == null) {
      return const SizedBox.shrink();
    }
    // 数据已加载但找不到该持仓(已被删除):自动关闭抽屉。
    if (holding == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }
    final h = holding;

    final totalValue = ref.watch(portfolioSummaryProvider).totalValue;
    final share =
        totalValue.isZero ? null : h.currentValue.divide(totalValue);
    final service = ref.watch(quoteRefreshServiceProvider);
    final supportsRefresh = holdingSupportsQuoteRefresh(h);
    // 已有一次刷新进行中:禁用入口,避免并发触发被误报为失败。
    final refreshing =
        ref.watch(quoteRefreshUiStateProvider) is QuoteRefreshInProgress;
    final canRefresh = supportsRefresh && service != null && !refreshing;
    final refreshDisabledReason = !supportsRefresh
        ? '该资产类型不支持行情刷新'
        : service == null
        ? '行情服务未就绪'
        : '正在刷新行情';

    final theme = Theme.of(context);
    return Material(
      color: FundLensTokens.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: FundLensTokens.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FundLensTokens.space4, FundLensTokens.space3,
                FundLensTokens.space2, FundLensTokens.space3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      h.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.extension<FundLensTextStyles>()!.sectionTitle,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('drawer-close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FundLensTokens.space4),
                children: [
                  _Section(title: '基本信息', rows: drawerBasicRows(h)),
                  _Section(title: '来源平台', rows: drawerPlatformRows(h)),
                  _Section(title: '当前金额', rows: drawerAmountRows(h, share)),
                  _Section(
                    title: '成本与收益',
                    rows: drawerProfitRows(h),
                    valueColors: {
                      '持仓盈亏': _pnlColor(
                        holdingPnlDirection(h.currentFloatingProfit),
                      ),
                      '持仓收益率': _pnlColor(
                        holdingPnlDirection(holdingEffectiveReturn(h)),
                      ),
                    },
                    footnote: '累计盈亏只展示,不纳入当前盈亏汇总。',
                  ),
                  _Section(title: '数据来源', rows: drawerProvenanceRows(h)),
                  _Section(title: '最后更新', rows: drawerUpdatedRows(h)),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FundLensTokens.space4,
                vertical: FundLensTokens.space2,
              ),
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('drawer-edit'),
                    onPressed: () async {
                      final saved = await HoldingActions.edit(
                        context,
                        ref,
                        h,
                        onFailure: () {
                          // 保存失败(数据库写入异常):提示重试,抽屉保持打开。
                          if (context.mounted) {
                            showHoldingToast(
                              context,
                              '保存失败：持仓未修改，请重试。',
                              isError: true,
                            );
                          }
                        },
                      );
                      if (saved && context.mounted) {
                        showHoldingToast(context, '已保存');
                      }
                    },
                    child: const Text('编辑'),
                  ),
                  const SizedBox(width: FundLensTokens.space2),
                  Tooltip(
                    message: canRefresh ? '' : refreshDisabledReason,
                    child: TextButton(
                      key: const ValueKey('drawer-refresh'),
                      onPressed: canRefresh
                          ? () async {
                              final report = await HoldingActions.refreshQuotes(
                                ref.container,
                                [h],
                              );
                              if (!context.mounted) return;
                              if (report == null) {
                                // 刷新进行中(并发拦截)不是失败:提示稍候。
                                final inProgress = ref
                                        .read(quoteRefreshUiStateProvider)
                                    is QuoteRefreshInProgress;
                                showHoldingToast(
                                  context,
                                  inProgress
                                      ? '正在刷新行情，请稍候…'
                                      : '行情刷新失败，保留最近一次估值。请稍后重试。',
                                  isError: !inProgress,
                                );
                                return;
                              }
                              showHoldingToast(
                                context,
                                report.updated.isNotEmpty
                                    ? '行情已更新'
                                    : '行情未更新,保留原值',
                              );
                            }
                          : null,
                      child: Text(refreshing ? '刷新中…' : '刷新行情'),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const ValueKey('drawer-delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: FundLensTokens.profit,
                    ),
                    onPressed: () async {
                      final deleted = await HoldingActions.delete(
                        context,
                        ref,
                        h,
                        onFailure: () {
                          // 删除失败(数据库错误等):提示重试,不关闭抽屉。
                          if (context.mounted) {
                            showHoldingToast(
                              context,
                              '删除失败：持仓未删除，请重试。',
                              isError: true,
                            );
                          }
                        },
                      );
                      if (!deleted || !context.mounted) return;
                      Navigator.of(context).maybePop();
                      showHoldingToast(context, '已删除');
                    },
                    child: const Text('删除'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉分节:标题 + 标签/值行 + 可选脚注。
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    this.footnote,
    this.valueColors,
  });

  final String title;
  final List<(String, String)> rows;
  final String? footnote;

  /// 按行标签附加的值着色(红盈利绿亏损);未命中的行保持默认正文色。
  final Map<String, Color?>? valueColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: FundLensTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium!
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: FundLensTokens.space2),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: FundLensTokens.space1,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(label, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: _valueStyle(theme, label),
                    ),
                  ),
                ],
              ),
            ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.only(top: FundLensTokens.space1),
              child: Text(footnote!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  /// 行值样式:命中着色表的行叠加红绿,其余保持正文色。
  TextStyle _valueStyle(ThemeData theme, String label) {
    final color = valueColors?[label];
    if (color == null) return theme.textTheme.bodyMedium!;
    return theme.textTheme.bodyMedium!.copyWith(color: color);
  }
}
