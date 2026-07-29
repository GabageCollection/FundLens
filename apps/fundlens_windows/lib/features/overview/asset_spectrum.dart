import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../../application/portfolio_providers.dart';
import '../../application/selection_state.dart';
import '../../theme/fundlens_tokens.dart';

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
  });

  final AssetClass assetClass;
  final double start;
  final double end;
  final Color color;
  final DecimalValue amount;
  final DecimalValue share;

  String get semanticsLabel =>
      '${assetClassLabels[assetClass]} 金额 ${amount.canonical} 占比 ${formatPercent(share)}';
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
    final segments = _segments(summary);
    if (segments.isEmpty) return const SizedBox.shrink();

    // Keep one FocusNode per present class, dropping stale ones.
    final present = {for (final s in segments) s.assetClass};
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
                            child: Semantics(
                              label: segments[i].semanticsLabel,
                              button: true,
                              child: FocusableActionDetector(
                                focusNode: _nodes[segments[i].assetClass],
                                mouseCursor: SystemMouseCursors.click,
                                onShowFocusHighlight: (highlighted) {
                                  setState(() {
                                    _focusedIndex = highlighted ? i : -1;
                                  });
                                },
                                shortcuts: const {
                                  SingleActivator(LogicalKeyboardKey.enter):
                                      ActivateIntent(),
                                  SingleActivator(LogicalKeyboardKey.space):
                                      ActivateIntent(),
                                },
                                actions: {
                                  ActivateIntent:
                                      CallbackAction<ActivateIntent>(
                                        onInvoke: (_) {
                                          _toggle(segments[i].assetClass);
                                          return null;
                                        },
                                      ),
                                },
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
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        if (selectedSegment != null) ...[
          const SizedBox(height: 8),
          _SelectedDetailRail(segment: selectedSegment),
        ],
      ],
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
