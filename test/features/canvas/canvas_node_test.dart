// CanvasNode 模型单测——覆盖 NodeRole / 可选字段 / copyWith / equality。

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  group('CanvasNode', () {
    test('默认 role = config，projectId/canvasId/sourceNodeId 为 null', () {
      const n = CanvasNode(id: 'n1', label: 'A', type: CanvasNodeType.image);
      expect(n.role, NodeRole.config);
      expect(n.projectId, isNull);
      expect(n.canvasId, isNull);
      expect(n.sourceNodeId, isNull);
    });

    test('带全字段构造', () {
      const n = CanvasNode(
        id: 'r1',
        label: 'Result',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        projectId: 'p1',
        canvasId: 'c1',
        sourceNodeId: 'cfg1',
        position: Offset(10, 20),
        size: Size(150, 100),
      );
      expect(n.role, NodeRole.result);
      expect(n.projectId, 'p1');
      expect(n.canvasId, 'c1');
      expect(n.sourceNodeId, 'cfg1');
      expect(n.position, const Offset(10, 20));
      expect(n.size, const Size(150, 100));
    });

    test('copyWith 可修改 role 与 sourceNodeId', () {
      const n = CanvasNode(id: 'n1', label: 'A', type: CanvasNodeType.image);
      final n2 = n.copyWith(role: NodeRole.result, sourceNodeId: 'cfg1');
      expect(n2.id, 'n1'); // id 不变
      expect(n2.role, NodeRole.result);
      expect(n2.sourceNodeId, 'cfg1');
      // 原对象不变
      expect(n.role, NodeRole.config);
      expect(n.sourceNodeId, isNull);
    });

    test('equality 覆盖新字段', () {
      const a = CanvasNode(id: 'x', label: 'A', type: CanvasNodeType.image);
      const b = CanvasNode(
        id: 'x',
        label: 'A',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        sourceNodeId: 'cfg',
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality 相同字段返回 true', () {
      const a = CanvasNode(
        id: 'x',
        label: 'A',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        projectId: 'p',
        canvasId: 'c',
        sourceNodeId: 'cfg',
        position: Offset(1, 2),
        size: Size(10, 20),
      );
      const b = CanvasNode(
        id: 'x',
        label: 'A',
        type: CanvasNodeType.image,
        role: NodeRole.result,
        projectId: 'p',
        canvasId: 'c',
        sourceNodeId: 'cfg',
        position: Offset(1, 2),
        size: Size(10, 20),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
