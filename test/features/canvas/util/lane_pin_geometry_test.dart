// lane_pin_geometry 纯函数单测——泳道钉死模型的坐标数学。

import 'package:flutter/widgets.dart' show Matrix4;
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/lane_pin_geometry.dart';

void main() {
  const lanes = [(id: 'a', size: 400.0), (id: 'b', size: 300.0)];

  group('laneStartOf', () {
    test('按尺寸顺序累计；null/不存在 → null', () {
      expect(laneStartOf('a', lanes), 0);
      expect(laneStartOf('b', lanes), 400);
      expect(laneStartOf(null, lanes), isNull);
      expect(laneStartOf('ghost', lanes), isNull);
    });
  });

  group('lanePinDisplacement', () {
    test('恒等变换（s=1, t=0）→ 位移为 0', () {
      expect(
        lanePinDisplacement(laneStart: 400, scale: 1, crossTranslation: 0),
        0,
      );
    });

    test('全局变换作用于位移后等于锚定公式', () {
      // s*(w + d) + t == laneStart + s*(w - laneStart)
      for (final (s, t, laneStart, w) in const [
        (2.0, 0.0, 400.0, 500.0),
        (0.5, -120.0, 400.0, 650.0),
        (3.0, 80.0, 0.0, 30.0),
      ]) {
        final d = lanePinDisplacement(
          laneStart: laneStart,
          scale: s,
          crossTranslation: t,
        );
        expect(
          s * (w + d) + t,
          closeTo(laneStart + s * (w - laneStart), 1e-9),
          reason: 's=$s t=$t laneStart=$laneStart',
        );
      }
    });
  });

  group('crossToScreen / crossToWorld', () {
    test('有道：以泳道起始边为锚缩放——起始边不动，带内偏移按 scale 放大', () {
      expect(
        crossToScreen(laneStart: 400, world: 400, scale: 2, crossTranslation: 99),
        400,
      );
      expect(
        crossToScreen(laneStart: 400, world: 500, scale: 2, crossTranslation: 99),
        600,
      );
    });

    test('无道：全局仿射', () {
      expect(
        crossToScreen(
            laneStart: null, world: 100, scale: 2, crossTranslation: -50),
        150,
      );
    });

    test('roundtrip：两分支互逆', () {
      for (final laneStart in const [null, 400.0]) {
        final screen = crossToScreen(
          laneStart: laneStart,
          world: 567,
          scale: 1.7,
          crossTranslation: -33,
        );
        expect(
          crossToWorld(
            laneStart: laneStart,
            screen: screen,
            scale: 1.7,
            crossTranslation: -33,
          ),
          closeTo(567, 1e-9),
        );
      }
    });

    test('钉死不变量：带内世界坐标在任意缩放下仍映射进本道带', () {
      // lane b: [400, 700)。带内任一点，s 从 0.1 到 3 都不许穿出。
      for (final s in const [0.1, 0.5, 1.0, 2.0, 3.0]) {
        for (final w in const [400.0, 550.0, 699.0]) {
          final screen = crossToScreen(
            laneStart: 400,
            world: w,
            scale: s,
            crossTranslation: -500,
          );
          expect(screen, greaterThanOrEqualTo(400));
          expect(screen, lessThan(400 + 300 * 3 + 1)); // 起始边锚定，向下最多 3x
          if (s <= 1.0) {
            expect(screen, lessThan(700), reason: '缩小/原比例不许穿出本道');
          }
        }
      }
    });
  });

  group('displacedNodes', () {
    const inLane = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.image,
      position: Offset(100, 500),
      laneId: 'b',
    );
    const free = CanvasNode(
      id: 'n2',
      label: '',
      type: CanvasNodeType.image,
      position: Offset(100, 500),
    );

    test('横向泳道：在道节点仅 y 位移，无道节点原样', () {
      final m = Matrix4.identity()..scaleByDouble(2.0, 2.0, 1.0, 1.0);
      final out = displacedNodes(
        nodes: const [inLane, free],
        lanes: lanes,
        direction: LaneDirection.horizontal,
        transform: m,
      );
      // d = (400*(1-2) - 0)/2 = -200 → y=300；渲染 y = 2*300 = 600 = 400+2*(500-400) ✓
      expect(out[0].position, const Offset(100, 300));
      expect(out[1].position, const Offset(100, 500));
    });

    test('竖向泳道：在道节点仅 x 位移', () {
      final m = Matrix4.identity()..scaleByDouble(2.0, 2.0, 1.0, 1.0);
      final out = displacedNodes(
        nodes: const [
          CanvasNode(
            id: 'n3',
            label: '',
            type: CanvasNodeType.image,
            position: Offset(500, 100),
            laneId: 'b',
          ),
        ],
        lanes: lanes,
        direction: LaneDirection.vertical,
        transform: m,
      );
      expect(out[0].position, const Offset(300, 100));
    });

    test('恒等变换下全部原样', () {
      final out = displacedNodes(
        nodes: const [inLane, free],
        lanes: lanes,
        direction: LaneDirection.horizontal,
        transform: Matrix4.identity(),
      );
      expect(out[0].position, inLane.position);
      expect(out[1].position, free.position);
    });
  });
}
