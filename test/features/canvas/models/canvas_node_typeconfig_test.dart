import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  test('promptText / textContent：非 String 值返回 null 不抛', () {
    const n = CanvasNode(
      id: 'n1',
      label: '',
      type: CanvasNodeType.text,
      typeConfig: <String, Object?>{'prompt': 123, 'text': true},
    );
    expect(n.promptText, isNull);
    expect(n.textContent, isNull);
  });

  test('promptText / textContent：String 值原样返回', () {
    const n = CanvasNode(
      id: 'n2',
      label: '',
      type: CanvasNodeType.text,
      typeConfig: <String, Object?>{'prompt': '画一只猫', 'text': '旁白'},
    );
    expect(n.promptText, '画一只猫');
    expect(n.textContent, '旁白');
  });
}
