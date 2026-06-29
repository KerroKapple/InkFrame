import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  test('typeConfig 内容相同、插入顺序不同 → == 为真且 hashCode 相等', () {
    const a = CanvasNode(
      id: 'n1',
      label: 'L',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'a': 1, 'b': 2},
    );
    const b = CanvasNode(
      id: 'n1',
      label: 'L',
      type: CanvasNodeType.image,
      typeConfig: <String, Object?>{'b': 2, 'a': 1}, // 不同插入顺序
    );
    expect(a == b, isTrue);
    expect(a.hashCode, b.hashCode); // 契约：== 为真则 hashCode 必相等
  });
}
