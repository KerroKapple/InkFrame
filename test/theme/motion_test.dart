// InkMotionSpring 预设测试：对齐 CineFlow Framer Motion 常用参数。
import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/motion.dart';

void main() {
  group('InkMotionSpring', () {
    test('hover / tap scale 预设', () {
      expect(InkMotionSpring.hoverScale, 1.05);
      expect(InkMotionSpring.tapScale, 0.95);
    });

    test('panel / popover 时长', () {
      expect(InkMotionSpring.panelIn.inMilliseconds, 300);
      expect(InkMotionSpring.popoverIn.inMilliseconds, 150);
      expect(InkMotionSpring.popoverOut.inMilliseconds, 150);
    });

    test('defaultSpring damping 0.8 / stiffness 300', () {
      const cfg = InkMotionSpring.defaultSpring;
      expect(cfg.dampingFraction, closeTo(0.8, 0.0001));
      expect(cfg.stiffness, 300);
    });

    test('toSpringDescription 生成 SpringDescription', () {
      final desc = InkMotionSpring.defaultSpring.toSpringDescription();
      expect(desc, isA<SpringDescription>());
      expect(desc.stiffness, 300);
    });
  });
}
