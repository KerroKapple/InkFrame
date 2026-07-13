// edge_hit_test 纯函数单测——点到连线曲线（源右出/靶左入贝塞尔）距离命中判定。

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/edge_hit_test.dart';

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
        point: const Offset(150, 150),
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

    test('点在源节点出点（右边中点）→ 命中（距离为 0）', () {
      final id = hitTestEdge(
        point: const Offset(100, 50),
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
      // 点 (50, 150) 距 a-c 线段（从 (50,50) 到 (50,250)）距离 0
      // 距 a-b 线段（从 (50,50) 到 (250,250)）距离 ~70
      final id = hitTestEdge(
        point: const Offset(50, 150),
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
    // a-out (100,50) → b-in (200,250)，水平对称手柄 → 中点 (150,150)。
    final mid = edgeMidpoint(source: nodeA, target: nodeB);
    expect(mid.dx, closeTo(150, 1));
    expect(mid.dy, closeTo(150, 1));
  });
}
