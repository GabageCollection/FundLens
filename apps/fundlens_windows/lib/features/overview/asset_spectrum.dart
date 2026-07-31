import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../application/selection_state.dart';
import '../../theme/fundlens_tokens.dart';
import 'overview_formatters.dart';

/// Chinese labels for the seven asset classes, shown on the spectrum and in
/// semantics so segments are never identified by color alone.
const assetClassLabels = <AssetClass, String>{
  AssetClass.cash: '现金',
  AssetClass.deposit: '存款',
  AssetClass.equity: '权益',
  AssetClass.fixedIncome: '固收',
  AssetClass.mixed: '混合',
  AssetClass.gold: '黄金',
  AssetClass.other: '其他',
};

/// Formats a 0..1 share as a one-decimal percentage, e.g. `34.9%`.
String formatPercent(DecimalValue share) =>
    '${(share.value.toDouble() * 100).toStringAsFixed(1)}%';

/// Formats an amount with an explicit `+`/`-` sign. China convention pairs
/// the sign with profit-red / loss-green at the call site.
String formatSignedAmount(DecimalValue value) =>
    '${value.isNegative ? '-' : '+'}${value.value.abs()}';

/// One segment of the Asset Spectrum bar.
///
/// [start] and [end] are cumulative 0..1 fractions along the bar; they are
/// derived from exact [DecimalValue] shares at the rendering boundary only.
final class SpectrumSegment {
  const SpectrumSegment({
    required this.assetClass,
    required this.start,
    required this.end,
    required this.color,
    required this.amount,
    required this.share,
    this.isMergedAggregate = false,
  });

  /// 合并段为 [AssetClass.other] 且 [isMergedAggregate] 为 true。
  final AssetClass assetClass;
  final double start;
  final double end;
  final Color color;
  final DecimalValue amount;
  final DecimalValue share;

  /// 超过 6 个类别时,占比最小的类别合并为“其他”聚合段;
  /// 聚合段不可点击筛选(它不代表单一类别)。
  final bool isMergedAggregate;

  String get semanticsLabel =>
      '${assetClassLabels[assetClass]} 金额 ¥${amount.canonical} 占比 ${formatPercent(share)}';
}

/// 类别超过 6 项时,把占比最小的类别合并为一个“其他”聚合段,
/// 保持结构带可读;不超过 6 项时原样返回。
List<SpectrumSegment> mergeSpectrumSegments(List<SpectrumSegment> segments) {
  if (segments.length <= 6) return segments;
  final sorted = [...segments]
    ..sort((a, b) => b.share.compareTo(a.share));
  final kept = sorted.take(5).toList();
  final merged = sorted.skip(5).toList();
  final mergedAmount = merged.fold<DecimalValue>(
    DecimalValue.zero,
    (sum, s) => sum + s.amount,
  );
  final mergedShare = merged.fold<DecimalValue>(
    DecimalValue.zero,
    (sum, s) => sum + s.share,
  );
  // 按占比降序重排,聚合段固定在最右。
  final result = <SpectrumSegment>[];
  var cumulative = 0.0;
  for (final segment in kept) {
    final width = segment.share.value.toDouble();
    result.add(
      SpectrumSegment(
        assetClass: segment.assetClass,
        start: cumulative,
        end: cumulative + width,
        color: segment.color,
        amount: segment.amount,
        share: segment.share,
      ),
    );
    cumulative += width;
  }
  result.add(
    SpectrumSegment(
      assetClass: AssetClass.other,
      start: cumulative,
      end: cumulative + mergedShare.value.toDouble(),
      color: FundLensTokens.categoryColors[AssetClass.other]!,
      amount: mergedAmount,
      share: mergedShare,
      isMergedAggregate: true,
    ),
  );
  return List.unmodifiable(result);
}

/// Interactive Asset Spectrum.
///
/// Renders the per-class value shares as a 20 px horizontal bar with 2 px
/// Paper separators. Tapping or pressing Enter/Space on a segment toggles the
/// asset-class filter via [selectedAssetClassProvider]; arrow keys move focus
/// between segments and Escape clears the selection. A detail rail below the
/// bar shows the selected class as text.
class AssetSpectrum extends ConsumerStatefulWidget {
  const AssetSpectrum({super.key});

  @override
  ConsumerState<AssetSpectrum> createState() => _AssetSpectrumState();
}

class _AssetSpectrumState extends ConsumerState<AssetSpectrum> {
  final _nodes = <AssetClass, FocusNode>{};
  int _focusedIndex = -1;

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  List<SpectrumSegment> _segments(PortfolioSummary summary) {
    final segments = <SpectrumSegment>[];
    var cumulative = 0.0;
    for (final assetClass in AssetClass.values) {
      final amount = summary.byAssetClass[assetClass];
      if (amount == null || amount.isZero) continue;
      final share = summary.totalValue.isZero
          ? DecimalValue.zero
          : amount.divide(summary.totalValue);
      // Decimal share -> double geometry only here, at the render boundary.
      final width = share.value.toDouble();
      segments.add(
        SpectrumSegment(
          assetClass: assetClass,
          start: cumulative,
          end: cumulative + width,
          color: FundLensTokens.categoryColors[assetClass]!,
          amount: amount,
          share: share,
        ),
      );
      cumulative += width;
    }
    return segments;
  }

  void _toggle(AssetClass assetClass) {
    final current = ref.read(selectedAssetClassProvider);
    ref.read(selectedAssetClassProvider.notifier).state = current == assetClass
        ? null
        : assetClass;
  }

  /// 结构带空状态:没有有效金额数据时给出明确说明,而不是灰色占位条。
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: FundLensTokens.space6,
        horizontal: FundLensTokens.space3,
      ),
      child: Text(
        '暂无有效资产数据,添加或更新持仓后展示资产结构。',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }

  KeyEventResult _onBarKey(FocusNode node, KeyEvent event, int segmentCount) {
    if (event is! KeyDownEvent || segmentCount == 0) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final delta = event.logicalKey == LogicalKeyboardKey.arrowRight ? 1 : -1;
      final next = (_focusedIndex + delta) % segmentCount;
      final index = next < 0 ? next + segmentCount : next;
      _nodes.values.elementAt(index).requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      ref.read(selectedAssetClassProvider.notifier).state = null;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(portfolioSummaryProvider);
    final selected = ref.watch(selectedAssetClassProvider);
    final segments = mergeSpectrumSegments(_segments(summary));
    if (segments.isEmpty) return _buildEmptyState(context);

    // Keep one FocusNode per present segment, dropping stale ones. 聚合段
    // 不可聚焦,只为真实类别保留 FocusNode。
    final present = {
      for (final s in segments)
        if (!s.isMergedAggregate) s.assetClass,
    };
    for (final stale
        in _nodes.keys.where((c) => !present.contains(c)).toList()) {
      _nodes.remove(stale)!.dispose();
    }
    for (final assetClass in present) {
      _nodes.putIfAbsent(assetClass, () => FocusNode());
    }

    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 400);
    // Re-run the orchestrated animation whenever the shares change (import or
    // snapshot switch); keyed on the exact geometry so taps stay stable.
    final signature = segments
        .map((s) => '${s.assetClass.name}:${s.share.canonical}')
        .join('|');

    final selectedSegment = selected == null
        ? null
        : segments.where((s) => s.assetClass == selected).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onKeyEvent: (node, event) => _onBarKey(node, event, segments.length),
          // 视觉条保持 20px,上下各留 10px 透明热区,使分段点击区域达到
          // 40px 的最小点击目标。
          child: SizedBox(
            height: FundLensTokens.minTapTarget,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(signature),
              tween: Tween(begin: 0, end: 1),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: (FundLensTokens.minTapTarget - 20) / 2,
                            ),
                            child: CustomPaint(
                              painter: _SpectrumPainter(
                                segments: segments,
                                progress: progress,
                                focusedIndex: _focusedIndex,
                              ),
                            ),
                          ),
                        ),
                        for (var i = 0; i < segments.length; i++)
                          Positioned(
                            left: segments[i].start * width,
                            width:
                                (segments[i].end - segments[i].start) * width,
                            top: 0,
                            bottom: 0,
                            child: segments[i].isMergedAggregate
                                // 聚合段只读:Hover 展示合并后的详细数据。
                                ? Tooltip(
                                    message: segments[i].semanticsLabel,
                                    child: const SizedBox.expand(),
                                  )
                                : Semantics(
                                    label: segments[i].semanticsLabel,
                                    button: true,
                                    child: FocusableActionDetector(
                                      focusNode:
                                          _nodes[segments[i].assetClass],
                                      mouseCursor: SystemMouseCursors.click,
                                      onShowFocusHighlight: (highlighted) {
                                        setState(() {
                                          _focusedIndex = highlighted ? i : -1;
                                        });
                                      },
                                      shortcuts: const {
                                        SingleActivator(
                                          LogicalKeyboardKey.enter,
                                        ): ActivateIntent(),
                                        SingleActivator(
                                          LogicalKeyboardKey.space,
                                        ): ActivateIntent(),
                                      },
                                      actions: {
                                        ActivateIntent:
                                            CallbackAction<ActivateIntent>(
                                              onInvoke: (_) {
                                                _toggle(
                                                  segments[i].assetClass,
                                                );
                                                return null;
                                              },
                                            ),
                                      },
                                      child: Tooltip(
                                        message: segments[i].semanticsLabel,
                                        child: GestureDetector(
                                          key: ValueKey(
                                            'spectrum-${segments[i].assetClass.name}',
                                          ),
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            _nodes[segments[i].assetClass]!
                                                .requestFocus();
                                            _toggle(segments[i].assetClass);
                                          },
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: FundLensTokens.space2),
        // 图例:每个分段的类别名称、占比和金额,颜色之外必有文字。
        for (final segment in segments) _SegmentLegendRow(segment: segment),
        if (selectedSegment != null) ...[
          const SizedBox(height: 8),
          _SelectedDetailRail(segment: selectedSegment),
        ],
      ],
    );
  }
}

/// 结构带图例行:色点 + 类别名称 + 金额与占比(右对齐)。
class _SegmentLegendRow extends StatelessWidget {
  const _SegmentLegendRow({required this.segment});

  final SpectrumSegment segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final number = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'IBM Plex Mono',
      color: FundLensTokens.inkSoft,
    );
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: segment.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: FundLensTokens.space2),
          Expanded(
            child: Text(
              assetClassLabels[segment.assetClass]!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            formatCurrency(segment.amount),
            style: number,
          ),
          const SizedBox(width: FundLensTokens.space4),
          SizedBox(
            width: 52,
            child: Text(
              formatPercent(segment.share),
              style: number,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDetailRail extends StatelessWidget {
  const _SelectedDetailRail({required this.segment});

  final SpectrumSegment segment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.bodyMedium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: FundLensTokens.accentSoft,
        border: Border(
          left: BorderSide(color: FundLensTokens.accent, width: 3),
        ),
      ),
      child: Text(
        '${assetClassLabels[segment.assetClass]} · '
        '金额 ${segment.amount.canonical} · '
        '占比 ${formatPercent(segment.share)}',
        style: text,
      ),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter({
    required this.segments,
    required this.progress,
    required this.focusedIndex,
  });

  final List<SpectrumSegment> segments;
  final double progress;
  final int focusedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final separator = Paint()..color = FundLensTokens.surface;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final left = segment.start * size.width;
      final right =
          (segment.start + (segment.end - segment.start) * progress) *
          size.width;
      if (right <= left) continue;
      final rect = Rect.fromLTRB(left, 0, right, size.height);
      canvas.drawRect(rect, Paint()..color = segment.color);
      // 2 px Paper separators between segments.
      if (i > 0) {
        canvas.drawRect(Rect.fromLTWH(left - 1, 0, 2, size.height), separator);
      }
      if (i == focusedIndex) {
        canvas.drawRect(
          rect.deflate(1),
          Paint()
            ..color = FundLensTokens.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.focusedIndex != focusedIndex ||
      oldDelegate.segments != segments;
}
