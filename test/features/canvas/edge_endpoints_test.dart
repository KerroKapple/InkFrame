// EdgeEndpoints：撤销栈按「两端 + 类型」反向找边，不按边 id、不看 role。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/edge_endpoints.dart';

CanvasEdge _edge(
  String id, {
  String source = 's',
  String target = 't',
  EdgeType type = EdgeType.data,
  EdgeRole role = EdgeRole.reference,
}) =>
    CanvasEdge(
      id: id,
      canvasId: 'cv',
      sourceNodeId: source,
      targetNodeId: target,
      edgeType: type,
      role: role,
    );

void main() {
  group('EdgeEndpoints', () {
    test('of 拷四个字段', () {
      final EdgeEndpoints k = EdgeEndpoints.of(
        _edge('e1', source: 'a', target: 'b', role: EdgeRole.firstFrame),
      );
      expect(k.sourceNodeId, 'a');
      expect(k.targetNodeId, 'b');
      expect(k.edgeType, EdgeType.data);
      expect(k.role, EdgeRole.firstFrame);
      expect(
        k,
        const EdgeEndpoints(
          sourceNodeId: 'a',
          targetNodeId: 'b',
          edgeType: EdgeType.data,
          role: EdgeRole.firstFrame,
        ),
      );
    });

    test('== / hashCode 覆盖四个字段', () {
      const EdgeEndpoints base = EdgeEndpoints(
        sourceNodeId: 'a',
        targetNodeId: 'b',
        edgeType: EdgeType.data,
      );
      const EdgeEndpoints same = EdgeEndpoints(
        sourceNodeId: 'a',
        targetNodeId: 'b',
        edgeType: EdgeType.data,
      );
      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(
        base ==
            const EdgeEndpoints(
              sourceNodeId: 'a',
              targetNodeId: 'b',
              edgeType: EdgeType.data,
              role: EdgeRole.lastFrame,
            ),
        isFalse,
      );
      expect(
        base ==
            const EdgeEndpoints(
              sourceNodeId: 'x',
              targetNodeId: 'b',
              edgeType: EdgeType.data,
            ),
        isFalse,
      );
      expect(
        base ==
            const EdgeEndpoints(
              sourceNodeId: 'a',
              targetNodeId: 'x',
              edgeType: EdgeType.data,
            ),
        isFalse,
      );
      expect(
        base ==
            const EdgeEndpoints(
              sourceNodeId: 'a',
              targetNodeId: 'b',
              edgeType: EdgeType.narrative,
            ),
        isFalse,
      );
    });

    test('按两端 + 类型找到在世边，不看 id', () {
      // 删了又重建的线：两端 + 类型同，id 换了。
      final EdgeEndpoints k = EdgeEndpoints.of(_edge('old-id'));
      final CanvasEdge rebuilt = _edge('new-id');
      final List<CanvasEdge> live = <CanvasEdge>[
        _edge('other', source: 'x'),
        rebuilt,
      ];
      expect(findEdgeByEndpoints(live, k), same(rebuilt));
    });

    test('改过角色的边仍能找到', () {
      final EdgeEndpoints k =
          EdgeEndpoints.of(_edge('e1', role: EdgeRole.reference));
      final CanvasEdge changed = _edge('e1', role: EdgeRole.lastFrame);
      expect(k.matches(changed), isTrue);
      expect(findEdgeByEndpoints(<CanvasEdge>[changed], k), same(changed));
    });

    test('类型不同不算同一条', () {
      // 同两端一条 data、一条 narrative：各找各的。
      final CanvasEdge data = _edge('d', type: EdgeType.data);
      final CanvasEdge narrative = _edge('n', type: EdgeType.narrative);
      final List<CanvasEdge> live = <CanvasEdge>[data, narrative];

      expect(
        findEdgeByEndpoints(live, EdgeEndpoints.of(narrative)),
        same(narrative),
      );
      expect(findEdgeByEndpoints(live, EdgeEndpoints.of(data)), same(data));
      expect(EdgeEndpoints.of(data).matches(narrative), isFalse);
    });

    test('方向反了不算同一条', () {
      final EdgeEndpoints k = EdgeEndpoints.of(_edge('e1'));
      expect(k.matches(_edge('e2', source: 't', target: 's')), isFalse);
    });

    test('找不到 ⇒ null', () {
      final EdgeEndpoints k = EdgeEndpoints.of(_edge('e1'));
      expect(findEdgeByEndpoints(const <CanvasEdge>[], k), isNull);
      expect(
        findEdgeByEndpoints(<CanvasEdge>[_edge('e2', target: 'other')], k),
        isNull,
      );
    });
  });
}
