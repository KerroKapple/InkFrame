// 产出线推导 + 端口占用（util/lineage_edges.dart）。
//
// 背景：config → result 的来历只存在 nodes.source_node_id 里，edges 表里没有行，
// 示例项目打开一条线都没有。这里锁的是「从节点表推出来、只用于画」的那几条规则。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/util/lineage_edges.dart';

const CanvasNode _config = CanvasNode(
  id: 'cfg',
  label: 'Config',
  type: CanvasNodeType.image,
);

const CanvasNode _result1 = CanvasNode(
  id: 'r1',
  label: '',
  type: CanvasNodeType.image,
  role: NodeRole.result,
  sourceNodeId: 'cfg',
);

const CanvasNode _result2 = CanvasNode(
  id: 'r2',
  label: '',
  type: CanvasNodeType.image,
  role: NodeRole.result,
  sourceNodeId: 'cfg',
);

CanvasEdge _edge(
  String id,
  String source,
  String target, {
  EdgeType type = EdgeType.data,
}) =>
    CanvasEdge(
      id: id,
      canvasId: 'c',
      sourceNodeId: source,
      targetNodeId: target,
      edgeType: type,
    );

void main() {
  group('deriveLineageEdges', () {
    test('config 名下每个 result 各推一条 config → result（没有任何存量边）', () {
      final List<LineageEdge> lineage = deriveLineageEdges(
        nodes: const <CanvasNode>[_config, _result1, _result2],
        edges: const <CanvasEdge>[],
      );
      expect(lineage, <LineageEdge>[
        (sourceNodeId: 'cfg', targetNodeId: 'r1'),
        (sourceNodeId: 'cfg', targetNodeId: 'r2'),
      ]);
    });

    test('源节点不在节点集里（已删 / 别的画布 / 折叠隐藏）→ 不推导', () {
      final List<LineageEdge> lineage = deriveLineageEdges(
        nodes: const <CanvasNode>[_result1],
        edges: const <CanvasEdge>[],
      );
      expect(lineage, isEmpty);
    });

    test('source_node_id 指向自己 → 不推导', () {
      const CanvasNode self = CanvasNode(
        id: 'x',
        label: '',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        sourceNodeId: 'x',
      );
      expect(
        deriveLineageEdges(
          nodes: const <CanvasNode>[self],
          edges: const <CanvasEdge>[],
        ),
        isEmpty,
      );
    });

    test('没有 source_node_id 的节点（config / 孤儿 result）→ 不推导', () {
      const CanvasNode orphan = CanvasNode(
        id: 'o',
        label: '',
        type: CanvasNodeType.image,
        role: NodeRole.result,
      );
      expect(
        deriveLineageEdges(
          nodes: const <CanvasNode>[_config, orphan],
          edges: const <CanvasEdge>[],
        ),
        isEmpty,
      );
    });

    test('同一对节点已有存量边（任一类型、任一方向）→ 不再推导，免得叠两条线', () {
      for (final CanvasEdge stored in <CanvasEdge>[
        _edge('e1', 'cfg', 'r1', type: EdgeType.generationSource),
        _edge('e2', 'cfg', 'r1'),
        _edge('e3', 'cfg', 'r1', type: EdgeType.narrative),
        _edge('e4', 'r1', 'cfg'),
      ]) {
        final List<LineageEdge> lineage = deriveLineageEdges(
          nodes: const <CanvasNode>[_config, _result1, _result2],
          edges: <CanvasEdge>[stored],
        );
        expect(
          lineage,
          <LineageEdge>[(sourceNodeId: 'cfg', targetNodeId: 'r2')],
          reason: '${stored.edgeType} ${stored.sourceNodeId}→${stored.targetNodeId}'
              ' 已经连着 cfg 与 r1；r2 照常推导',
        );
      }
    });

    test('别的节点对之间的存量边不影响推导', () {
      final List<LineageEdge> lineage = deriveLineageEdges(
        nodes: const <CanvasNode>[_config, _result1, _result2],
        edges: <CanvasEdge>[_edge('e1', 'r1', 'r2')],
      );
      expect(lineage, hasLength(2));
    });

    test('空节点集 → 空', () {
      expect(
        deriveLineageEdges(
          nodes: const <CanvasNode>[],
          edges: const <CanvasEdge>[],
        ),
        isEmpty,
      );
    });
  });

  group('connectedPortSides', () {
    const CanvasNode a = CanvasNode(id: 'a', label: '', type: CanvasNodeType.image);
    const CanvasNode b = CanvasNode(id: 'b', label: '', type: CanvasNodeType.video);

    test('存量边：源记出口、靶记入口', () {
      final PortSides ports = connectedPortSides(
        nodes: const <CanvasNode>[a, b],
        edges: <CanvasEdge>[_edge('e1', 'a', 'b')],
        lineage: const <LineageEdge>[],
      );
      expect(ports.outbound, <String>{'a'});
      expect(ports.inbound, <String>{'b'});
    });

    test('产出线同样算：config 出口、result 入口', () {
      final List<CanvasNode> nodes = <CanvasNode>[_config, _result1];
      final PortSides ports = connectedPortSides(
        nodes: nodes,
        edges: const <CanvasEdge>[],
        lineage: deriveLineageEdges(nodes: nodes, edges: const <CanvasEdge>[]),
      );
      expect(ports.outbound, <String>{'cfg'});
      expect(ports.inbound, <String>{'r1'});
    });

    test('一端不在可见集里（折叠道）的线画不出来，不算挂着线', () {
      final PortSides ports = connectedPortSides(
        nodes: const <CanvasNode>[a],
        edges: <CanvasEdge>[_edge('e1', 'a', 'b')],
        lineage: const <LineageEdge>[(sourceNodeId: 'a', targetNodeId: 'gone')],
      );
      expect(ports.outbound, isEmpty);
      expect(ports.inbound, isEmpty);
    });

    test('没有任何线 → 两边都空', () {
      final PortSides ports = connectedPortSides(
        nodes: const <CanvasNode>[a, b],
        edges: const <CanvasEdge>[],
        lineage: const <LineageEdge>[],
      );
      expect(ports.outbound, isEmpty);
      expect(ports.inbound, isEmpty);
    });
  });
}
