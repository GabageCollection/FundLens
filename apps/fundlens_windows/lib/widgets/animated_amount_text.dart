import 'package:flutter/material.dart';
import 'package:fundlens_core/fundlens_core.dart';

import '../theme/fundlens_theme.dart';

/// 数字变化微动画:值变化时从旧值平滑滚动到新值。
///
/// 中间帧用 [interpolateFormat](double 格式化)渲染,终值帧用
/// [format](Decimal 精确格式化)渲染,保证最终显示与领域计算口径
/// 完全一致;动画只影响视觉过渡,不参与任何计算。
///
/// 系统开启"减少动画"时经 [fundlensAnimationDuration] 归零,直接显示终值。
class AnimatedAmountText extends StatefulWidget {
  const AnimatedAmountText({
    super.key,
    required this.value,
    required this.format,
    required this.interpolateFormat,
    this.style,
  });

  /// 目标值(精确十进制)。
  final DecimalValue value;

  /// 终值格式化:接收 [DecimalValue],输出精确文本。
  final String Function(DecimalValue value) format;

  /// 中间帧格式化:接收 double 插值,输出与 [format] 同款式的文本。
  final String Function(double value) interpolateFormat;

  final TextStyle? style;

  @override
  State<AnimatedAmountText> createState() => _AnimatedAmountTextState();
}

class _AnimatedAmountTextState extends State<AnimatedAmountText> {
  double? _previous;

  @override
  Widget build(BuildContext context) {
    final target = widget.value.value.toDouble();
    final from = _previous ?? target;
    final duration = fundlensAnimationDuration(context);
    _previous = target;
    if (duration == Duration.zero || from == target) {
      return Text(widget.format(widget.value), style: widget.style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: target),
      duration: duration * 2,
      curve: Curves.easeOut,
      onEnd: () {},
      builder: (context, current, _) {
        final isFinal = (current - target).abs() < 1e-9;
        return Text(
          isFinal
              ? widget.format(widget.value)
              : widget.interpolateFormat(current),
          style: widget.style,
        );
      },
    );
  }
}