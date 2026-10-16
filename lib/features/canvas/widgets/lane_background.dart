// 泳道背景层：CustomPaint。底色由数据驱动（effectiveLaneTint），分界线色由调用方传入 token。
//
// Lanes 稿：道体铺 0.10 alpha 的弱底色（不干扰缩略图），道首（横向左缘 / 竖向上缘）加一条
// 3px 满饱和色轨——远看能分辨，近看不抢戏；没有 tint 的道色轨取 control。
// collapsedIds 中的泳道收成 kCollapsedLaneSize 的轨：不铺底色，色轨与分界线照画。
// 拖卡片途中，松手会换进的那条道（dropTargetLaneId，判定见 util/drop_placement.dart 的 cardDropTargetLane）
// 叠一层强调色弱底 + 一圈强调色描边：换道之前就看得见要进哪条道。
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
    required this.railFallbackColor,
    this.collapsedIds = const <String>{},
    this.dropTargetLaneId,
    this.dropTargetColor,
  });

  final List<StyleLane> lanes;
  final LaneDirection direction;
  final double canvasExtent;
  final Color dividerColor;
  /// 没有 tint（既没手动指定也没推断命中）的道，色轨用这个色（token control）。
  final Color railFallbackColor;
  /// 折叠态泳道 id 集：收成 36px 轨，不铺底色。
  final Set<String> collapsedIds;

  /// 拖卡片途中松手会换进的那条道（高亮）；null = 不换道 / 没在拖。
  final String? dropTargetLaneId;

  /// 目标道高亮用的颜色（token accent）；null 时不画高亮。
  final Color? dropTargetColor;

  /// 稿：道首色轨 3px。
  static const double railThickness = 3;

  /// 目标道高亮：弱底的不透明度与描边粗细。
  static const double dropTargetFillAlpha = 0.12;
  static const double dropTargetStroke = 2;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(canvasExtent),
      painter: _LanePainter(
        lanes: lanes,
        direction: direction,
        canvasExtent: canvasExtent,
        dividerColor: dividerColor,
        railFallbackColor: railFallbackColor,
        collapsedIds: collapsedIds,
        dropTargetLaneId: dropTargetLaneId,
        dropTargetColor: dropTargetColor,
      ),
    );
  }
}

/// 道首色轨的矩形：横向在左缘竖贯整道，竖向在上缘横贯整道。
Rect laneRailRect(Rect lane, LaneDirection direction) =>
    direction == LaneDirection.horizontal
        ? Rect.fromLTWH(lane.left, lane.top, LaneBackground.railThickness, lane.height)
        : Rect.fromLTWH(lane.left, lane.top, lane.width, LaneBackground.railThickness);

class _LanePainter extends CustomPainter {
  _LanePainter({
    required this.lanes,
    required this.direction,
    required this.canvasExtent,
    required this.dividerColor,
    required this.railFallbackColor,
    required this.collapsedIds,
    required this.dropTargetLaneId,
    required this.dropTargetColor,
  });

  final List<StyleLane> lanes;
  final LaneDirection direction;
  final double canvasExtent;
  final Color dividerColor;
  final Color railFallbackColor;
  final Set<String> collapsedIds;
  final String? dropTargetLaneId;
  final Color? dropTargetColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rects = laneRects(
      lanes: collapseLaneSlices(
        [for (final l in lanes) (id: l.id, size: l.size)],
        collapsedIds,
      ),
      direction: direction,
      canvasExtent: canvasExtent,
    );
    final line = Paint()
      ..color = dividerColor
      ..strokeWidth = 1;
    for (var i = 0; i < lanes.length; i++) {
      final rect = rects[i];
      final tint = effectiveLaneTint(
        tintColor: lanes[i].tintColor,
        stylePrompt: lanes[i].stylePrompt,
      );
      // 折叠泳道不绘色填充。
      if (!collapsedIds.contains(lanes[i].id) && tint != null) {
        canvas.drawRect(rect, Paint()..color = tint.withValues(alpha: 0.10));
      }
      // 道首 3px 色轨（折叠态照画：远看仍能分辨这是哪条道）。
      canvas.drawRect(
        laneRailRect(rect, direction),
        Paint()..color = tint ?? railFallbackColor,
      );
      // 分界线：泳道末端 1px 细线（首条不画起始线）。
      if (i > 0) {
        if (direction == LaneDirection.horizontal) {
          canvas.drawLine(Offset(0, rect.top), Offset(canvasExtent, rect.top), line);
        } else {
          canvas.drawLine(Offset(rect.left, 0), Offset(rect.left, canvasExtent), line);
        }
      }
    }
    _paintDropTarget(canvas, rects);
  }

  /// 拖卡片的目标道：弱底 + 内描边，画在底色与分界线之上（卡片仍在这一层之上）。
  void _paintDropTarget(Canvas canvas, List<Rect> rects) {
    final Color? color = dropTargetColor;
    final String? target = dropTargetLaneId;
    if (color == null || target == null) return;
    for (var i = 0; i < lanes.length; i++) {
      if (lanes[i].id != target) continue;
      final Rect rect = rects[i];
      canvas.drawRect(
        rect,
        Paint()..color = color.withValues(alpha: LaneBackground.dropTargetFillAlpha),
      );
      canvas.drawRect(
        rect.deflate(LaneBackground.dropTargetStroke / 2),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = LaneBackground.dropTargetStroke,
      );
      return;
    }
  }

  @override
  bool shouldRepaint(covariant _LanePainter old) =>
      old.direction != direction ||
      old.dividerColor != dividerColor ||
      old.railFallbackColor != railFallbackColor ||
      old.collapsedIds != collapsedIds ||
      old.dropTargetLaneId != dropTargetLaneId ||
      old.dropTargetColor != dropTargetColor ||
      !_sameLanes(old.lanes, lanes);

  bool _sameLanes(List<StyleLane> a, List<StyleLane> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
