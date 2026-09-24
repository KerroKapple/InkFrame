// edge_hit_test 纯函数单测——点到连线曲线（源右出/靶左入贝塞尔）距离命中判定。

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/edge_hit_test.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';

void main() {
  // 两个节点：A 在 (0,0) 尺寸 100x100 中心 (50,50)；B 在 (200,200) 尺寸 100x100 中心 (250,250)。
  const nodeA = CanvasNode(
    id: 'a',
    label: '',
    type: CanvasNodeType.image,
    size: Size(100, 100),
  );
  const nodeB = CanvasNode(
    id: 'b',
    label: '',
    type: CanvasNodeType.image,
    position: Offset(200, 200),
    size: Size(100, 100),
  );
  const edgeAB = CanvasEdge(
    id: 'ab',
    canvasId: 'c',
    sourceNodeId: 'a',
    targetNodeId: 'b',
    edgeType: EdgeType.data,
  );

  group('hitTestEdge', () {
    test('点在线段中点 → 命中', () {
      final id = hitTestEdge(
        point: edgeMidpoint(source: nodeA, target: nodeB),
        edges: const [edgeAB],
        nodes: const [nodeA, nodeB],
      );
      expect(id, 'ab');
    });

    test('点距线段 > 阈值 → 未命中', () {
      final id = hitTestEdge(
        point: const Offset(0, 200),
        edges: const [edgeAB],
        nodes: const [nodeA, nodeB],
      );
      expect(id, isNull);
    });

    test('点在源节点出点（右缘端口）→ 命中（距离为 0）', () {
      // 卡片渲染尺寸 224×172、端口 y=87（不读 node.size）。
      final id = hitTestEdge(
        point: const Offset(224, 87),
        edges: const [edgeAB],
        nodes: const [nodeA, nodeB],
      );
      expect(id, 'ab');
    });

    test('点超出线段延长线 → clamp 到端点后仍可能命中', () {
      // 点在 A 端点之外 (0,0)，距离 ≈ 70.7 > 10 → 不命中
      final id = hitTestEdge(
        point: const Offset(0, 0),
        edges: const [edgeAB],
        nodes: const [nodeA, nodeB],
      );
      expect(id, isNull);
    });

    test('多条边：返回最近的', () {
      const nodeC = CanvasNode(
        id: 'c',
        label: '',
        type: CanvasNodeType.image,
        position: Offset(0, 200),
        size: Size(100, 100),
      );
      const edgeAC = CanvasEdge(
        id: 'ac',
        canvasId: 'c',
        sourceNodeId: 'a',
        targetNodeId: 'c',
        edgeType: EdgeType.data,
      );
      // 取 a-c 曲线中点：距 a-c 为 0，距 a-b（靶在 (195,287)）远 > 10。
      final id = hitTestEdge(
        point: edgeMidpoint(source: nodeA, target: nodeC),
        edges: const [edgeAB, edgeAC],
        nodes: const [nodeA, nodeB, nodeC],
      );
      expect(id, 'ac');
    });

    test('缺少节点端点 → 该边跳过', () {
      final id = hitTestEdge(
        point: const Offset(150, 150),
        edges: const [edgeAB],
        nodes: const [nodeA], // 缺 B
      );
      expect(id, isNull);
    });

    test('长连线：点在曲线中点仍命中（采样步长自适应，不受弧长稀释）', () {
      const far = CanvasNode(
        id: 'far',
        label: '',
        type: CanvasNodeType.image,
        position: Offset(3000, 300),
        size: Size(100, 100),
      );
      const edgeAFar = CanvasEdge(
        id: 'af',
        canvasId: 'c',
        sourceNodeId: 'a',
        targetNodeId: 'far',
        edgeType: EdgeType.data,
      );
      final mid = edgeMidpoint(source: nodeA, target: far);
      final id = hitTestEdge(
        point: mid,
        edges: const [edgeAFar],
        nodes: const [nodeA, far],
      );
      expect(id, 'af');
    });

    test('空列表 → null', () {
      expect(
        hitTestEdge(
            point: Offset.zero, edges: const [], nodes: const [nodeA, nodeB]),
        isNull,
      );
    });
  });

  test('edgeMidpoint 返回连线曲线弧长中点（对称手柄下 ≈ 锚点几何中点）', () {
    // a-out (224,87) → b-in (195,287)，水平对称手柄 → 中点 (209.5,187)。
    final mid = edgeMidpoint(source: nodeA, target: nodeB);
    expect(mid.dx, closeTo(209.5, 1));
    expect(mid.dy, closeTo(187, 1));
  });

  group('竖向泳道命中（direction: vertical）', () {
    test('竖向锚点（源下边中点）→ 命中；同点在横向语义下未命中', () {
      // a 下边中点：卡片渲染尺寸 224×172（不读 node.size）⇒ (112,172)。
      const p = Offset(112, 172);
      expect(
        hitTestEdge(
          point: p,
          edges: const [edgeAB],
          nodes: const [nodeA, nodeB],
          direction: LaneDirection.vertical,
        ),
        'ab',
      );
      expect(
        hitTestEdge(
          point: p,
          edges: const [edgeAB],
          nodes: const [nodeA, nodeB],
        ),
        isNull,
      );
    });

    test('edgeMidpoint 竖向：对称手柄下 ≈ 锚点几何中点', () {
      // a-out (112,172) → b-in (312,200) → 中点 (212,186)。
      final mid = edgeMidpoint(
        source: nodeA,
        target: nodeB,
        direction: LaneDirection.vertical,
      );
      expect(mid.dx, closeTo(212, 1));
      expect(mid.dy, closeTo(186, 1));
    });
  });
}
