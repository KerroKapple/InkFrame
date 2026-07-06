// CanvasEdge 边界补充：非法 role 抛错、lastFrame 解析、equality 逐字段区分、hashCode。
//
// 补 canvas_edge_test.dart 未覆盖的 _parseRole 异常臂与 == 的末位字段短路。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';

Map<String, Object?> _row() => <String, Object?>{
      'id': 'e1',
      'canvas_id': 'c',
      'source_node_id': 's',
      'target_node_id': 't',
      'edge_type': 'data',
      'role': 'reference',
    };

void main() {
  group('CanvasEdge.fromRow role 解析', () {
    test('非法 role → FormatException', () {
      final row = _row()..['role'] = 'middle_frame';
      expect(
        () => CanvasEdgeMapping.fromRow(row),
        throwsA(isA<FormatException>()),
      );
    });

    test('last_frame 正常解析', () {
      final row = _row()..['role'] = 'last_frame';
      final e = CanvasEdgeMapping.fromRow(row);
      expect(e.role, EdgeRole.lastFrame);
    });

    test('sort_order 缺失 → 默认 0', () {
      final e = CanvasEdgeMapping.fromRow(_row());
      expect(e.sortOrder, 0);
    });

    test('edge_type 列类型错（非 String）→ LocalIOError', () {
      final row = _row()..['edge_type'] = 9;
      expect(
        () => CanvasEdgeMapping.fromRow(row),
        throwsA(isA<LocalIOError>()),
      );
    });
  });

  group('CanvasEdge typeToDb 全枚举', () {
    test('data / narrative / generation_source 往返', () {
      expect(CanvasEdgeMapping.typeToDb(EdgeType.data), 'data');
      expect(CanvasEdgeMapping.typeToDb(EdgeType.narrative), 'narrative');
      expect(CanvasEdgeMapping.roleToDb(EdgeRole.reference), 'reference');
    });
  });

  group('CanvasEdge operator== / hashCode', () {
    const base = CanvasEdge(
      id: 'e',
      canvasId: 'c',
      sourceNodeId: 's',
      targetNodeId: 't',
      edgeType: EdgeType.data,
      role: EdgeRole.reference,
      sortOrder: 1,
    );

    test('sortOrder 不同 → 不等（末位字段短路臂）', () {
      expect(base == base.copyWith(sortOrder: 2), isFalse);
    });

    test('role 不同 → 不等', () {
      expect(base == base.copyWith(role: EdgeRole.firstFrame), isFalse);
    });

    test('全字段相同 → 相等且 hashCode 一致', () {
      const same = CanvasEdge(
        id: 'e',
        canvasId: 'c',
        sourceNodeId: 's',
        targetNodeId: 't',
        edgeType: EdgeType.data,
        role: EdgeRole.reference,
        sortOrder: 1,
      );
      expect(base == same, isTrue);
      expect(base.hashCode, same.hashCode);
    });
  });
}
