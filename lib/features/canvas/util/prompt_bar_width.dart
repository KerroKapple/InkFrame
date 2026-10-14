// 提示词条宽度（提示词条与节点文字稿）：跟着画布舞台宽度走，不再钉死 668。
//
// 规则：舞台宽 × 0.6，夹在 [480, 880]；舞台窄到连「下限 480 + 两侧各一档 InkSpacing.md」
// 都放不下（< 512）时，改取舞台宽减两侧边距——宁可条子窄一点，也不让它顶到舞台边上。
// 512 不另立常量：它就是下限加两侧边距，两段规则在这一点上首尾相接（511 → 479、512 → 480）。
//
// 0.6 / 480 / 880 是布局比例与上下限（行为），不是视觉 token，所以住在函数旁边；
// 两侧边距是间距，照规矩取 token。纯函数，可脱离 widget 单测。
import 'dart:math' as math;

import '../../../theme/tokens.dart';

/// 提示词条占舞台宽度的比例。
const double kPromptBarWidthRatio = 0.6;

/// 宽度下限：再窄，一行里放不下提示词框 + 字数 + 「生成」按钮。
const double kPromptBarMinWidth = 480;

/// 宽度上限：再宽，一行字拉得太长，读到行尾找不回下一行的行首。
const double kPromptBarMaxWidth = 880;

/// 舞台宽 [canvasWidth] 下提示词条的宽度。
///
/// [canvasWidth] 为 infinity（父级不限宽）时落在上限 880。
double promptBarWidth(double canvasWidth) {
  const double gutters = 2 * InkSpacing.md;
  if (canvasWidth < kPromptBarMinWidth + gutters) {
    // 极窄（不足两侧边距）时夹到 0：负宽会让 BoxConstraints 断言炸掉。
    return math.max(0.0, canvasWidth - gutters);
  }
  return (canvasWidth * kPromptBarWidthRatio)
      .clamp(kPromptBarMinWidth, kPromptBarMaxWidth)
      .toDouble();
}
