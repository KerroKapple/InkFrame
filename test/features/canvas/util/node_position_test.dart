// 建点落点：旧固定区随机（回退路径）+ 视口中心换算（债150）。
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
    test('恒等变换：节点几何中心对准视口中心,散布 ≤±60', () {
      final rand = Random(1);
      for (var i = 0; i < 50; i++) {
        final p = pickViewportCenteredNodePosition(
          random: rand,
          transform: Matrix4.identity(),
          viewportSize: const Size(800, 600),
        );
        // 节点左上角 = 视口中心(400,300) - 半节点(100,80) ± 散布(≤60)
        expect(p.dx, inInclusiveRange(400 - 100 - 60, 400 - 100 + 60));
        expect(p.dy, inInclusiveRange(300 - 80 - 60, 300 - 80 + 60));
      }
    });

    test('平移+缩放变换：经逆变换换算进世界坐标', () {
      // 视图矩阵=先缩放 2x 再平移 (-1000,-500)：世界点 w 显示在 2w-1000。
      final m = Matrix4.identity()
        ..translateByDouble(-1000.0, -500.0, 0.0, 1.0)
        ..scaleByDouble(2.0, 2.0, 2.0, 1.0);
      final p = pickViewportCenteredNodePosition(
        random: _ZeroRandom(),
        transform: m,
        viewportSize: const Size(800, 600),
      );
      // 视口中心(400,300) → 世界 ((400+1000)/2, (300+500)/2) = (700,400);
      // _ZeroRandom 散布=恒 -60（(0-0.5)*120）;减半节点 (100,80)。
      expect(p.dx, closeTo(700 - 100 - 60, 0.001));
      expect(p.dy, closeTo(400 - 80 - 60, 0.001));
    });

    test('视口未上报（Size.zero）→ 回退旧固定区随机', () {
      final p = pickViewportCenteredNodePosition(
        random: Random(42),
        transform: Matrix4.identity(),
        viewportSize: Size.zero,
      );
      expect(p, pickRandomNodePosition(Random(42)));
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
