// 提示词条宽度（提示词条与节点文字稿）：跟着画布舞台宽度走，不再钉死 668。
//
// 宽度规则：舞台宽 × 0.6，夹在 [480, 880]；舞台窄到连「下限 480 + 两侧各一档 InkSpacing.md」
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

/// 提示词条在舞台里的水平位置：左沿 [left]、宽 [width]（都相对舞台左沿）。
///
/// 照常居中；居中会压到左下那一簇（缩放条 + 泳道工具栏，[InkToolbarSize.stageBottomLeftReserve]）时，
/// 改在右边剩下的那一段里居中，放不下就再收窄——否则窗宽 1280、左栏展开时「适应」「+」整格被盖住，
/// 只要选中一张图像 / 视频配置卡（提示词条出现）就点不到。舞台不限宽（infinity）时照旧居中。
({double left, double width}) promptBarPlacement(double stageWidth) {
  final double width = promptBarWidth(stageWidth);
  if (!stageWidth.isFinite) return (left: 0, width: width);
  final double centered = (stageWidth - width) / 2;
  const double reserve = InkToolbarSize.stageBottomLeftReserve;
  if (centered >= reserve) return (left: centered, width: width);
  final double available = math.max(0.0, stageWidth - reserve - InkSpacing.md);
  final double fitted = math.min(width, available);
  return (left: reserve + (available - fitted) / 2, width: fitted);
}
