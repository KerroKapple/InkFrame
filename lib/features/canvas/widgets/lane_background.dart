// 泳道背景层：CustomPaint。底色由数据驱动（effectiveLaneTint），分界线色由调用方传入 token。
// collapsedIds 中的泳道不绘色填充，但仍绘分界线。
import 'package:flutter/material.dart';

import '../models/style_lane.dart';
import '../util/lane_geometry.dart';
import '../util/lane_tint.dart';

class LaneBackground extends StatelessWidget {
  const LaneBackground({
    super.key,
    required this.lanes,
    required this.direction,
    required this.canvasExtent,
    required this.dividerColor,
    this.collapsedIds = const <String>{},
  });

  final List<StyleLane> lanes;
  final LaneDirection direction;
  final double canvasExtent;
  final Color dividerColor;
  /// 折叠态泳道 id 集：不绘色填充，仍绘分界线。
  final Set<String> collapsedIds;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(canvasExtent),
      painter: _LanePainter(
        lanes: lanes,
        direction: direction,
        canvasExtent: canvasExtent,
        dividerColor: dividerColor,
        collapsedIds: collapsedIds,
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  _LanePainter({
    required this.lanes,
    required this.direction,
    required this.canvasExtent,
    required this.dividerColor,
    required this.collapsedIds,
  });

  final List<StyleLane> lanes;
  final LaneDirection direction;
  final double canvasExtent;
  final Color dividerColor;
  final Set<String> collapsedIds;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = laneRects(
      lanes: [for (final l in lanes) (id: l.id, size: l.size)],
      direction: direction,
      canvasExtent: canvasExtent,
    );
    final line = Paint()
      ..color = dividerColor
      ..strokeWidth = 1;
    for (var i = 0; i < lanes.length; i++) {
      final rect = rects[i];
      // 折叠泳道不绘色填充。
      if (!collapsedIds.contains(lanes[i].id)) {
        final tint = effectiveLaneTint(
          tintColor: lanes[i].tintColor,
          stylePrompt: lanes[i].stylePrompt,
        );
        if (tint != null) {
          canvas.drawRect(rect, Paint()..color = tint.withValues(alpha: 0.10));
        }
      }
      // 分界线：泳道末端 1px 细线（首条不画起始线）。
      if (i > 0) {
        if (direction == LaneDirection.horizontal) {
          canvas.drawLine(Offset(0, rect.top), Offset(canvasExtent, rect.top), line);
        } else {
          canvas.drawLine(Offset(rect.left, 0), Offset(rect.left, canvasExtent), line);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LanePainter old) =>
      old.direction != direction ||
      old.dividerColor != dividerColor ||
      old.collapsedIds != collapsedIds ||
      !_sameLanes(old.lanes, lanes);

  bool _sameLanes(List<StyleLane> a, List<StyleLane> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
