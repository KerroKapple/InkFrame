// CanvasEdge 模型单测：fromRow / enum 往返 / equality。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';

void main() {
  group('CanvasEdge', () {
    test('fromRow 解析 data 连线（默认 role = reference）', () {
      final row = <String, Object?>{
        'id': 'e1',
        'canvas_id': 'cvx',
        'source_node_id': 's',
        'target_node_id': 't',
        'edge_type': 'data',
        'role': null,
        'sort_order': 0,
      };
      final e = CanvasEdgeMapping.fromRow(row);
      expect(e.edgeType, EdgeType.data);
      expect(e.role, EdgeRole.reference);
    });

    test('fromRow 解析 narrative / generation_source / first_frame', () {
      final narr = CanvasEdgeMapping.fromRow(<String, Object?>{
        'id': 'e1',
        'canvas_id': 'c',
        'source_node_id': 's',
        'target_node_id': 't',
        'edge_type': 'narrative',
        'role': 'reference',
      });
      expect(narr.edgeType, EdgeType.narrative);
      final gs = CanvasEdgeMapping.fromRow(<String, Object?>{
        'id': 'e2',
        'canvas_id': 'c',
        'source_node_id': 's',
        'target_node_id': 't',
        'edge_type': 'generation_source',
        'role': 'reference',
      });
      expect(gs.edgeType, EdgeType.generationSource);
      final ff = CanvasEdgeMapping.fromRow(<String, Object?>{
        'id': 'e3',
        'canvas_id': 'c',
        'source_node_id': 's',
        'target_node_id': 't',
        'edge_type': 'data',
        'role': 'first_frame',
      });
      expect(ff.role, EdgeRole.firstFrame);
    });

    test('非法 edge_type → FormatException', () {
      expect(
        () => CanvasEdgeMapping.fromRow(<String, Object?>{
          'id': 'e',
          'canvas_id': 'c',
          'source_node_id': 's',
          'target_node_id': 't',
          'edge_type': 'bogus',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('DB 字符串往返', () {
      expect(CanvasEdgeMapping.typeToDb(EdgeType.generationSource),
          'generation_source');
      expect(CanvasEdgeMapping.roleToDb(EdgeRole.firstFrame), 'first_frame');
      expect(CanvasEdgeMapping.roleToDb(EdgeRole.lastFrame), 'last_frame');
    });

    test('equality + copyWith 保留 id / endpoints', () {
      const a = CanvasEdge(
        id: 'e',
        canvasId: 'c',
        sourceNodeId: 's',
        targetNodeId: 't',
        edgeType: EdgeType.data,
      );
      final b = a.copyWith(role: EdgeRole.firstFrame, sortOrder: 2);
      expect(b.id, a.id);
      expect(b.sourceNodeId, a.sourceNodeId);
      expect(b.role, EdgeRole.firstFrame);
      expect(b.sortOrder, 2);
      expect(a == b, isFalse);
    });
  });
}
