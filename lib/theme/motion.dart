// InkMotionSpring 预设：常用动画弹簧 / 入场出场时长参数。
//
// hoverScale / tapScale —— 按钮交互微缩放
// panelIn / popoverIn / popoverOut —— 入场出场时长
// defaultSpring —— damping fraction 0.8 / stiffness 300
import 'package:flutter/animation.dart';

class InkMotionSpringConfig {
  const InkMotionSpringConfig({
    required this.dampingFraction,
    required this.stiffness,
  });

  final double dampingFraction;
  final double stiffness;

  SpringDescription toSpringDescription({double mass = 1.0}) =>
      SpringDescription.withDampingRatio(
        mass: mass,
        stiffness: stiffness,
        ratio: dampingFraction,
      );
}

class InkMotionSpring {
  InkMotionSpring._();

  /// Hover 微放大
  static const double hoverScale = 1.05;

  /// Tap 微缩小
  static const double tapScale = 0.95;

  /// 面板入场
  static const Duration panelIn = Duration(milliseconds: 300);

  /// Popover 入场（slash / asset menu scale 0.8→1 + opacity）
  static const Duration popoverIn = Duration(milliseconds: 150);

  /// Popover 退场
  static const Duration popoverOut = Duration(milliseconds: 150);

  /// 默认弹簧：Framer damping fraction 0.8 / stiffness 300
  static const InkMotionSpringConfig defaultSpring = InkMotionSpringConfig(
    dampingFraction: 0.8,
    stiffness: 300,
  );
}
