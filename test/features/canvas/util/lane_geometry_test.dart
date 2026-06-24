import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';

void main() {
  const lanes = [(id: 'a', size: 100.0), (id: 'b', size: 200.0)];

  test('horizontal rects stack on Y, full width', () {
    final r = laneRects(lanes: lanes, direction: LaneDirection.horizontal, canvasExtent: 4000);
    expect(r[0], const Rect.fromLTWH(0, 0, 4000, 100));
    expect(r[1], const Rect.fromLTWH(0, 100, 4000, 200));
  });

  test('vertical rects stack on X, full height', () {
    final r = laneRects(lanes: lanes, direction: LaneDirection.vertical, canvasExtent: 4000);
    expect(r[0], const Rect.fromLTWH(0, 0, 100, 4000));
    expect(r[1], const Rect.fromLTWH(100, 0, 200, 4000));
  });

  test('laneIdAtPoint horizontal picks band by Y center', () {
    expect(laneIdAtPoint(point: const Offset(10, 50), lanes: lanes, direction: LaneDirection.horizontal), 'a');
    expect(laneIdAtPoint(point: const Offset(10, 150), lanes: lanes, direction: LaneDirection.horizontal), 'b');
  });

  test('laneIdAtPoint returns null when out of bounds or empty', () {
    expect(laneIdAtPoint(point: const Offset(10, 9999), lanes: lanes, direction: LaneDirection.horizontal), isNull);
    expect(laneIdAtPoint(point: Offset.zero, lanes: const [], direction: LaneDirection.horizontal), isNull);
  });

  test('direction string round-trip', () {
    expect(laneDirectionFromString('vertical'), LaneDirection.vertical);
    expect(laneDirectionFromString('horizontal'), LaneDirection.horizontal);
    expect(laneDirectionFromString('garbage'), LaneDirection.horizontal);
    expect(laneDirectionToString(LaneDirection.vertical), 'vertical');
  });

  group('clampLaneSize', () {
    test('adds delta then clamps to kMinLaneSize floor', () {
      expect(clampLaneSize(400, 50), 450);
      expect(clampLaneSize(400, -50), 350);
      expect(clampLaneSize(100, -500), kMinLaneSize); // 下限
      expect(clampLaneSize(kMinLaneSize, -10), kMinLaneSize);
    });
  });

  group('reorderedLaneIds', () {
    final ids = ['a', 'b', 'c'];
    test('moves id to target position', () {
      expect(reorderedLaneIds(ids, 'c', 'a'), ['c', 'a', 'b']);
      expect(reorderedLaneIds(ids, 'a', 'c'), ['b', 'c', 'a']);
    });
    test('no-op when target null / same / unknown', () {
      expect(reorderedLaneIds(ids, 'a', null), ids);
      expect(reorderedLaneIds(ids, 'a', 'a'), ids);
      expect(reorderedLaneIds(ids, 'a', 'zzz'), ids);
      expect(reorderedLaneIds(ids, 'zzz', 'a'), ids);
    });
  });
}
