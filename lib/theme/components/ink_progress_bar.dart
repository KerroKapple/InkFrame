// InkProgressBar：统一的细进度条（3px 高，圆角裁切）。
//
// value 为 null 时进入不确定态（持续动画）；非 null 时 clamp 到 0..1。
// 颜色固定取 token：底 surface3 / 填充 cta。渲染队列 / Job 面板共用。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkProgressBar extends StatelessWidget {
  const InkProgressBar({super.key, this.value});

  /// 0..1 进度；null = 不确定态。
  final double? value;

  // 组件固有几何（非全局 token）：条高 3px。
  static const double _kHeight = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(InkRadius.xs),
      child: SizedBox(
        height: _kHeight,
        child: LinearProgressIndicator(
          value: value?.clamp(0.0, 1.0),
          backgroundColor: colors.surface3,
          valueColor: AlwaysStoppedAnimation<Color>(colors.cta),
        ),
      ),
    );
  }
}
