// 「移到视口中心」的坐标数学（PR-4 左栏定位）：transformCenteringRect + nodeStageRect。
//
// 两条硬性质：缩放不变；节点渲染矩形的中心经新变换后正好落在视口中心。
// 泳道里的卡片画在「世界 + 分道位移」处（位移随缩放变），所以缩放 ≠ 1 时也要对准它真正画的位置。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/lane_pin_geometry.dart';
import 'package:inkframe/features/canvas/util/viewport_focus.dart';

/// 舞台点经变换落到视口里的位置。
Offset _onScreen(Matrix4 m, Offset stage) => MatrixUtils.transformPoint(m, stage);

void main() {
  const Size viewport = Size(1000, 600);
  const Offset viewportCenter = Offset(500, 300);

  group('transformCenteringRect', () {
    test('初始相机：节点中心落在视口中心，缩放仍是 1', () {
      final Matrix4 current = initialCanvasTransform();
      final Rect rect = worldToStage(const Offset(3000, -1200)) & kNodeCardSize;

      final Matrix4 next = transformCenteringRect(
        current: current,
        viewportSize: viewport,
        stageRect: rect,
      );

      expect(scaleOf(next), closeTo(1, 1e-9));
      final Offset c = _onScreen(next, rect.center);
      expect(c.dx, closeTo(viewportCenter.dx, 1e-6));
      expect(c.dy, closeTo(viewportCenter.dy, 1e-6));
    });

    test('缩放 0.5 / 2.4 都保持原缩放，且节点中心落在视口中心', () {
      for (final double s in <double>[0.5, 2.4]) {
        final Matrix4 current = Matrix4.identity()
          ..translateByDouble(-12345, 678, 0.0, 1.0)
          ..scaleByDouble(s, s, 1.0, 1.0);
        final Rect rect = worldToStage(const Offset(-800, 450)) & kNodeCardSize;

        final Matrix4 next = transformCenteringRect(
          current: current,
          viewportSize: viewport,
          stageRect: rect,
        );

        expect(scaleOf(next), closeTo(s, 1e-9), reason: 'scale $s 不能被改');
        final Offset c = _onScreen(next, rect.center);
        expect(c.dx, closeTo(viewportCenter.dx, 1e-6), reason: 'scale $s');
        expect(c.dy, closeTo(viewportCenter.dy, 1e-6), reason: 'scale $s');
      }
    });

    test('视口还没上报（Size.zero / 坍缩）→ 原样返回，不把画布甩到 (0,0) 附近', () {
      final Matrix4 current = initialCanvasTransform();
      for (final Size empty in const <Size>[Size.zero, Size(0, 600), Size(1000, 0)]) {
        final Matrix4 next = transformCenteringRect(
          current: current,
          viewportSize: empty,
          stageRect: worldToStage(const Offset(9000, 9000)) & kNodeCardSize,
        );
        expect(next, current);
      }
    });
  });

  group('nodeStageRect', () {
    test('不在泳道里：世界坐标 + kStageOrigin，尺寸 = 卡片渲染尺寸', () {
      const CanvasNode node = CanvasNode(
        id: 'n',
        label: 'n',
        type: CanvasNodeType.image,
        position: Offset(120, -40),
      );
      final Rect rect = nodeStageRect(
        node: node,
        lanes: const <({String id, double size})>[],
        direction: LaneDirection.horizontal,
        transform: initialCanvasTransform(),
      );
      expect(rect, worldToStage(const Offset(120, -40)) & kNodeCardSize);
    });

    test('泳道里、缩放 ≠ 1：矩形含分道位移，居中后卡片真正画出来的中心落在视口中心', () {
      const CanvasNode node = CanvasNode(
        id: 'n',
        label: 'n',
        type: CanvasNodeType.image,
        laneId: 'L2',
        position: Offset(600, 520),
      );
      const List<({String id, double size})> lanes = <({String id, double size})>[
        (id: 'L1', size: 400),
        (id: 'L2', size: 400),
      ];
      final Matrix4 current = Matrix4.identity()
        ..translateByDouble(-40000, -49800, 0.0, 1.0)
        ..scaleByDouble(0.8, 0.8, 1.0, 1.0);

      final Rect rect = nodeStageRect(
        node: node,
        lanes: lanes,
        direction: LaneDirection.horizontal,
        transform: current,
      );
      // 与卡片 Positioned 同源：世界 + kStageOrigin + 分道位移（canvas_view 就是这么摆的）。
      final Offset expectedTopLeft = worldToStage(node.position) +
          nodeLaneDisplacement(
            node: node,
            lanes: lanes,
            direction: LaneDirection.horizontal,
            transform: current,
          );
      expect(rect.topLeft, expectedTopLeft);
      expect(rect.size, kNodeCardSize);
      expect(rect.topLeft.dy, isNot(closeTo(worldToStage(node.position).dy, 1e-6)),
          reason: '缩放 0.8 下分道位移非零——没算它就对不准');

      final Matrix4 next = transformCenteringRect(
        current: current,
        viewportSize: viewport,
        stageRect: rect,
      );
      // 位移只随缩放变，而缩放没变：用新相机重算一遍渲染矩形，中心仍在视口中心。
      final Rect drawnAfter = nodeStageRect(
        node: node,
        lanes: lanes,
        direction: LaneDirection.horizontal,
        transform: next,
      );
      final Offset c = _onScreen(next, drawnAfter.center);
      expect(c.dx, closeTo(viewportCenter.dx, 1e-6));
      expect(c.dy, closeTo(viewportCenter.dy, 1e-6));
    });
  });
}
