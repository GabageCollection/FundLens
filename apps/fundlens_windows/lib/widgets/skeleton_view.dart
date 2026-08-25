import 'package:flutter/material.dart';

import '../theme/fundlens_tokens.dart';

/// 骨架块:加载占位用的纯色矩形,呼吸透明度动画。
///
/// 系统开启"减少动画"时([MediaQuery.disableAnimationsOf])呼吸动画
/// 关闭,呈现为静态色块。
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius});

  final double? width;
  final double height;
  final double? radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: FundLensTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(
          widget.radius ?? FundLensTokens.radiusSmall,
        ),
        border: Border.all(color: FundLensTokens.border),
      ),
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: 0.55 + 0.45 * _controller.value,
        child: child,
      ),
      child: box,
    );
  }
}

/// 页面级骨架屏:卡片轮廓 + 文本行占位,替代居中 spinner,
/// 避免加载完成后布局跳动。仍带 [Semantics] 标签供读屏。
class SkeletonView extends StatelessWidget {
  const SkeletonView({super.key, this.label = '正在加载…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI 汇总条轮廓
          Card(
            child: Padding(
              padding: EdgeInsets.all(FundLensTokens.cardPadding),
              child: Row(
                children: [
                  Expanded(child: _SkeletonCell()),
                  SizedBox(width: FundLensTokens.space6),
                  Expanded(child: _SkeletonCell()),
                  SizedBox(width: FundLensTokens.space6),
                  Expanded(child: _SkeletonCell()),
                  SizedBox(width: FundLensTokens.space6),
                  Expanded(child: _SkeletonCell()),
                  SizedBox(width: FundLensTokens.space6),
                  Expanded(child: _SkeletonCell()),
                ],
              ),
            ),
          ),
          SizedBox(height: FundLensTokens.cardGap),
          // 图表区轮廓
          Card(
            child: Padding(
              padding: EdgeInsets.all(FundLensTokens.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 96, height: 18),
                  SizedBox(height: FundLensTokens.space4),
                  SkeletonBox(height: 180, radius: FundLensTokens.radiusCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCell extends StatelessWidget {
  const _SkeletonCell();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 56, height: 12),
        SizedBox(height: FundLensTokens.space2),
        SkeletonBox(width: 88, height: 20),
      ],
    );
  }
}