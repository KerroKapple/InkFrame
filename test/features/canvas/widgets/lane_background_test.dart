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
      ),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
