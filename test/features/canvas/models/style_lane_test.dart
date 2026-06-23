import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';

void main() {
  test('fromRow maps columns', () {
    final lane = StyleLane.fromRow({
      'id': 'l1', 'canvas_id': 'c1', 'label': 'Day', 'style_prompt': 'warm',
      'sort_order': 2, 'tint_color': '#FF8A50', 'size': 320.0,
    });
    expect(lane.id, 'l1');
    expect(lane.canvasId, 'c1');
    expect(lane.label, 'Day');
    expect(lane.stylePrompt, 'warm');
    expect(lane.sortOrder, 2);
    expect(lane.tintColor, '#FF8A50');
    expect(lane.size, 320.0);
  });
  test('fromRow tolerates nulls with defaults', () {
    final lane = StyleLane.fromRow({'id': 'l', 'canvas_id': 'c'});
    expect(lane.label, '');
    expect(lane.stylePrompt, '');
    expect(lane.sortOrder, 0);
    expect(lane.tintColor, isNull);
    expect(lane.size, 400.0);
  });
  test('copyWith + equality', () {
    const a = StyleLane(id: 'l', canvasId: 'c', label: 'x');
    expect(a.copyWith(label: 'y').label, 'y');
    expect(a.copyWith(), a);
  });
}
