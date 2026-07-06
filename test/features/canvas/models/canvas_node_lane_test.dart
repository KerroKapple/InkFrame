import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';

void main() {
  test('fromRow maps lane_id and ignore_lane_style', () {
    final n = CanvasNodeMapping.fromRow({
      'id': 'n', 'canvas_id': 'c', 'type': 'image', 'node_role': 'config',
      'lane_id': 'lane-1', 'type_config': {'ignore_lane_style': true},
    });
    expect(n.laneId, 'lane-1');
    expect(n.ignoreLaneStyle, isTrue);
  });
  test('laneId null + ignore defaults false', () {
    final n = CanvasNodeMapping.fromRow({
      'id': 'n', 'canvas_id': 'c', 'type': 'image', 'node_role': 'config',
    });
    expect(n.laneId, isNull);
    expect(n.ignoreLaneStyle, isFalse);
  });
  test('copyWith sets and clears laneId', () {
    const n = CanvasNode(id: 'n', label: '', type: CanvasNodeType.image, laneId: 'a');
    expect(n.copyWith(laneId: 'b').laneId, 'b');
    expect(n.copyWith(clearLaneId: true).laneId, isNull);
    expect(n.copyWith().laneId, 'a');
  });
}
