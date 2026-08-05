// 建点落点：旧固定区随机（回退路径）+ 视口中心换算（债150）。
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/util/node_position.dart';

void main() {
  test('同 seed 结果确定', () {
    final a = pickRandomNodePosition(Random(42));
    final b = pickRandomNodePosition(Random(42));
    expect(a, b);
  });

  test('落点始终在 [200, 600) 区间', () {
    final rand = Random(7);
    for (var i = 0; i < 100; i++) {
      final p = pickRandomNodePosition(rand);
      expect(p.dx, inInclusiveRange(200, 600));
      expect(p.dy, inInclusiveRange(200, 600));
    }
  });

  group('pickViewportCenteredNodePosition（债150）', () {
    // 断言基准=真实相机（评审 P0-2:恒等矩阵在 app 中不存在——初始相机即
    // translate(-kStageOrigin),恒等基准会把漏减 kStageOrigin 的 bug 钉死为约定）。
    test('初始相机：节点几何中心对准视口中心的世界坐标,散布 ≤±60', () {
      final rand = Random(1);
      for (var i = 0; i < 50; i++) {
        final p = pickViewportCenteredNodePosition(
          random: rand,
          transform: initialCanvasTransform(),
          viewportSize: const Size(800, 600),
        );
        // 初始相机对准世界原点附近:视口中心(400,300)→世界(400,300);
        // 节点左上角 = 世界中心 - 半节点(100,80) ± 散布(≤60)。
        expect(p.dx, inInclusiveRange(400 - 100 - 60, 400 - 100 + 60));
        expect(p.dy, inInclusiveRange(300 - 80 - 60, 300 - 80 + 60));
      }
    });

    test('漫游+缩放相机：经逆变换与 stageToWorld 换算进世界坐标', () {
      // 相机: 世界 w 显示在 2*(w+50000) - 101000 → 视口中心(400,300)
      // 对应世界 ((400+101000)/2 - 50000, (300+100500)/2 - 50000) = (700,400)。
      final m = Matrix4.identity()
        ..translateByDouble(-101000.0, -100500.0, 0.0, 1.0)
        ..scaleByDouble(2.0, 2.0, 2.0, 1.0);
      final p = pickViewportCenteredNodePosition(
        random: _ZeroRandom(),
        transform: m,
        viewportSize: const Size(800, 600),
      );
      // _ZeroRandom 散布=恒 -60（(0-0.5)*120）;减半节点 (100,80)。
      expect(p.dx, closeTo(700 - 100 - 60, 0.001));
      expect(p.dy, closeTo(400 - 80 - 60, 0.001));
    });

    test('落点世界坐标必在 ±kWorldReach 内（初始相机全类型冒烟）', () {
      for (final size in const <Size>[
        Size(1600, 900),
        Size(960, 700),
      ]) {
        final p = pickViewportCenteredNodePosition(
          random: Random(9),
          transform: initialCanvasTransform(),
          viewportSize: size,
        );
        expect(p.dx.abs(), lessThan(48000), reason: '不得飞出世界域');
        expect(p.dy.abs(), lessThan(48000));
      }
    });

    test('视口未上报/坍缩（isEmpty）→ 回退旧固定区随机', () {
      for (final size in const <Size>[Size.zero, Size(0, 600), Size(800, 0)]) {
        final p = pickViewportCenteredNodePosition(
          random: Random(42),
          transform: initialCanvasTransform(),
          viewportSize: size,
        );
        expect(p, pickRandomNodePosition(Random(42)));
      }
    });
  });
}

/// nextDouble 恒 0——散布退化为确定值,便于精确断言。
class _ZeroRandom implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
  @override
  int nextInt(int max) => 0;
}
