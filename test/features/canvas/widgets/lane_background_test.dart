import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/lane_background.dart';

void main() {
  testWidgets('renders a CustomPaint for lanes', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LaneBackground(
        lanes: [StyleLane(id: 'a', canvasId: 'c', size: 100, tintColor: '#FF8A50')],
        direction: LaneDirection.horizontal,
        canvasExtent: 400,
        dividerColor: Color(0xFF333333),
        railFallbackColor: Color(0xFF3A3A3A),
      ),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  // Lanes 稿改动 2：道首 3px 色轨——横向在左缘竖贯整道，竖向在上缘横贯整道。
  test('laneRailRect：横向左缘 3px 竖贯，竖向上缘 3px 横贯', () {
    const lane = Rect.fromLTWH(0, 176, 1280, 184);
    expect(laneRailRect(lane, LaneDirection.horizontal), const Rect.fromLTWH(0, 176, 3, 184));
    const vlane = Rect.fromLTWH(236, 0, 268, 480);
    expect(laneRailRect(vlane, LaneDirection.vertical), const Rect.fromLTWH(236, 0, 268, 3));
  });
}
