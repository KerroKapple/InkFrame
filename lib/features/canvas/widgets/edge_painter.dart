// EdgePainter：在画布垫底层绘制连线（Workspace v2 稿 + 画布重设计稿 › 画布交互）。
//
// 几何与 hitTestEdge 同源（util/edge_geometry.dart）；外观由 util/edge_style.dart 判定
// （类型 + 角色 + 是否在当前链路 → 颜色槽 / 线宽 / 线型 / 箭头 / 标签），本层只照着画：
//   - 存量边与推导出来的产出线（util/lineage_edges.dart）都画；产出线最弱，先画、垫底。
//   - 终点开口箭头沿曲线**终点切线**取向（PathMetric.getTangentForOffset），尖端落在
//     端口外缘——曲线怎么进端口，箭头就怎么指，不再写死主轴方向。
//   - 首帧 / 尾帧 / 参考三种数据线一律在曲线弧长中点挂标签胶囊：底 = 画布底色（盖住
//     胶囊下那段线），1px 描边与 10px 文字都用连线色。标签等所有线画完再统一画，
//     不会被后画的线压住。
// 端口圆点由 NodeCard 自己画，本层不画。
//
// 从出端口拖线时的实时虚线（[PendingWirePainter]，画布重设计稿 › 拖线到空白处 → 建节点）也在本文件：
// 同一条 edgePath 贝塞尔、同一个虚线切法，只是它画在卡片之上（canvas_view 舞台的最上层），
// 拖过别的卡片时线不会被压住。
import 'dart:math' as math;
import 'dart:ui' show PathMetric, Tangent;

import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../util/edge_geometry.dart';
import '../util/edge_style.dart';
import '../util/lane_geometry.dart';
import '../util/lineage_edges.dart';

/// 标签胶囊内边距：横向留一点呼吸，竖向贴着 10px 字的行高。
const EdgeInsets _kLabelPadding = EdgeInsets.symmetric(
  horizontal: InkSpacing.s5,
  vertical: InkSpacing.s2,
);

/// 一个待画的标签：画完全部连线后统一画在最上面。
typedef _PendingLabel = ({EdgeLabelKind kind, Color color, Offset at});

/// 拖线中的实时虚线线宽（稿：1.75，与首帧 / 尾帧数据线同宽）。
const double kPendingWireWidth = 1.75;

/// 实时虚线的线型：画 4、空 3。
const EdgeDash kPendingWireDash = (on: 4.0, off: 3.0);

/// 实时虚线在指针那头的实心点半径。
const double kPendingWireDotRadius = 3.5;

class EdgePainter extends CustomPainter {
  EdgePainter({
    required this.edges,
    required this.nodes,
    required this.palette,
    required this.labelStyle,
    required this.firstFrameLabel,
    required this.lastFrameLabel,
    required this.referenceLabel,
    this.lineage = const <LineageEdge>[],
    this.direction = LaneDirection.horizontal,
    this.selectedNodeIds = const <String>{},
    this.selectedEdgeId,
    this.dragNodeId,
    this.dragDelta = Offset.zero,
  });

  /// 存量边（edges 表）。
  final List<CanvasEdge> edges;

  /// 由 source_node_id 推导出来的产出线：只画，不落库、点不中。
  final List<LineageEdge> lineage;

  final List<CanvasNode> nodes;

  /// 颜色槽 → 颜色（令牌由 canvas_view 取），外加标签胶囊底色。
  final EdgePalette palette;

  /// 标签字体（10px micro），颜色由本层按连线色覆盖。
  final TextStyle labelStyle;
  final String firstFrameLabel;
  final String lastFrameLabel;
  final String referenceLabel;

  /// 泳道主轴——决定出/入锚点方位与曲线走向。
  final LaneDirection direction;

  /// 与这些节点相连的线视为「当前链路」→ accent。
  final Set<String> selectedNodeIds;
  final String? selectedEdgeId;

  /// 拖拽中节点及其实时位移——连线跟手（拖拽位移未提交 controller 前先补到锚点上）。
  final String? dragNodeId;
  final Offset dragDelta;

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.isEmpty || (edges.isEmpty && lineage.isEmpty)) return;
    final Map<String, CanvasNode> nodeById = <String, CanvasNode>{
      for (final CanvasNode n in nodes) n.id: n,
    };
    final List<_PendingLabel> labels = <_PendingLabel>[];

    // 产出线最弱，先画、垫在最底下；它点不中，谈不上「被选中」，只看端点。
    for (final LineageEdge l in lineage) {
      _paintEdge(
        canvas,
        nodeById,
        sourceId: l.sourceNodeId,
        targetId: l.targetNodeId,
        type: EdgeType.generationSource,
        role: EdgeRole.reference,
        selected: false,
        labels: labels,
      );
    }
    for (final CanvasEdge e in edges) {
      _paintEdge(
        canvas,
        nodeById,
        sourceId: e.sourceNodeId,
        targetId: e.targetNodeId,
        type: e.edgeType,
        role: e.role,
        selected: e.id == selectedEdgeId,
        labels: labels,
      );
    }
    _paintLabels(canvas, labels);
  }

  void _paintEdge(
    Canvas canvas,
    Map<String, CanvasNode> nodeById, {
    required String sourceId,
    required String targetId,
    required EdgeType type,
    required EdgeRole role,
    required bool selected,
    required List<_PendingLabel> labels,
  }) {
    final CanvasNode? src = nodeById[sourceId];
    final CanvasNode? dst = nodeById[targetId];
    if (src == null || dst == null) return;
    var p1 = edgeSourceAnchor(src, direction: direction);
    var p2 = edgeTargetAnchor(dst, direction: direction);
    if (src.id == dragNodeId) p1 += dragDelta;
    if (dst.id == dragNodeId) p2 += dragDelta;

    final bool onChain = selected ||
        selectedNodeIds.contains(src.id) ||
        selectedNodeIds.contains(dst.id);
    final EdgeStyle style =
        resolveEdgeStyle(type: type, role: role, onChain: onChain);
    final Color color = palette.colorOf(style.colorSlot);

    final Path path = edgePath(p1, p2, direction: direction);
    final EdgeDash? dash = style.dash;
    canvas.drawPath(
      dash == null ? path : _dashed(path, dash),
      Paint()
        ..color = color
        ..strokeWidth = style.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = style.dotted ? StrokeCap.round : StrokeCap.butt,
    );

    final PathMetric? metric = _firstMetric(path);
    // 起止重合：没有切线，也就没有箭头与中点。
    if (metric == null) return;
    _paintArrowHead(canvas, metric, style, color);
    if (style.label == EdgeLabelKind.none) return;
    final Offset? mid = metric.getTangentForOffset(metric.length / 2)?.position;
    if (mid != null) labels.add((kind: style.label, color: color, at: mid));
  }

  static PathMetric? _firstMetric(Path path) {
    final Iterator<PathMetric> it = path.computeMetrics().iterator;
    return it.moveNext() ? it.current : null;
  }

  static Path _dashed(Path src, EdgeDash dash) {
    final Path out = Path();
    for (final PathMetric metric in src.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final double end = math.min(d + dash.on, metric.length);
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d += dash.on + dash.off;
      }
    }
    return out;
  }

  /// 开口箭头：尖端落在曲线终点，两翼沿终点切线往回收。
  static void _paintArrowHead(
    Canvas canvas,
    PathMetric metric,
    EdgeStyle style,
    Color color,
  ) {
    final Tangent? end = metric.getTangentForOffset(metric.length);
    if (end == null) return;
    final double norm = end.vector.distance;
    if (norm == 0) return;
    final Offset dir = end.vector / norm;
    final Offset side = Offset(-dir.dy, dir.dx) * style.arrow.halfWidth;
    final Offset tip = end.position;
    final Offset back = tip - dir * style.arrow.length;
    final Offset wingA = back + side;
    final Offset wingB = back - side;
    canvas.drawPath(
      Path()
        ..moveTo(wingA.dx, wingA.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(wingB.dx, wingB.dy),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 标签胶囊：同文字同色的标签一帧只排一次版，帧尾统一释放。
  void _paintLabels(Canvas canvas, List<_PendingLabel> pending) {
    if (pending.isEmpty) return;
    final Map<(EdgeLabelKind, Color), TextPainter> laidOut =
        <(EdgeLabelKind, Color), TextPainter>{};
    try {
      for (final _PendingLabel label in pending) {
        final TextPainter text = laidOut.putIfAbsent(
          (label.kind, label.color),
          () => TextPainter(
            text: TextSpan(
              text: _labelText(label.kind),
              style: labelStyle.copyWith(color: label.color),
            ),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout(),
        );
        final Rect textRect = Rect.fromCenter(
          center: label.at,
          width: text.width,
          height: text.height,
        );
        final RRect chip = RRect.fromRectAndRadius(
          _kLabelPadding.inflateRect(textRect),
          const Radius.circular(InkRadius.s3),
        );
        canvas.drawRRect(
          chip,
          Paint()
            ..color = palette.chipFill
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          chip,
          Paint()
            ..color = label.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = kEdgeLabelBorderWidth,
        );
        text.paint(canvas, textRect.topLeft);
      }
    } finally {
      for (final TextPainter t in laidOut.values) {
        t.dispose();
      }
    }
  }

  String _labelText(EdgeLabelKind kind) => switch (kind) {
        EdgeLabelKind.firstFrame => firstFrameLabel,
        EdgeLabelKind.lastFrame => lastFrameLabel,
        EdgeLabelKind.reference => referenceLabel,
        EdgeLabelKind.none => '',
      };

  @override
  bool shouldRepaint(covariant EdgePainter old) {
    return old.edges != edges ||
        old.lineage != lineage ||
        old.nodes != nodes ||
        old.palette != palette ||
        old.labelStyle != labelStyle ||
        old.firstFrameLabel != firstFrameLabel ||
        old.lastFrameLabel != lastFrameLabel ||
        old.referenceLabel != referenceLabel ||
        old.direction != direction ||
        old.selectedNodeIds != selectedNodeIds ||
        old.selectedEdgeId != selectedEdgeId ||
        old.dragNodeId != dragNodeId ||
        old.dragDelta != dragDelta;
  }
}

/// 从出端口拖线时的实时虚线：源节点出点 → 指针。
///
/// 曲线与存量连线是同一条贝塞尔（edgePath，出点同 edgeSourceAnchor），所以松手连上之后那条线的起头
/// 和拖的时候一模一样；颜色由调用方给（accent），线宽 / 虚线 / 末端实心点见上面三个常量。
class PendingWirePainter extends CustomPainter {
  PendingWirePainter({
    required this.source,
    required this.to,
    required this.color,
    this.direction = LaneDirection.horizontal,
  });

  /// 拖线的源节点，坐标已是渲染位置（舞台坐标 + 分道位移，见 displacedNodes）。
  final CanvasNode source;

  /// 指针（舞台坐标）。
  final Offset to;

  final Color color;

  /// 泳道主轴——决定出点方位与曲线走向，与 [EdgePainter.direction] 同源。
  final LaneDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = edgePath(
      edgeSourceAnchor(source, direction: direction),
      to,
      direction: direction,
    );
    canvas.drawPath(
      EdgePainter._dashed(path, kPendingWireDash),
      Paint()
        ..color = color
        ..strokeWidth = kPendingWireWidth
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      to,
      kPendingWireDotRadius,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant PendingWirePainter oldDelegate) =>
      oldDelegate.source != source ||
      oldDelegate.to != to ||
      oldDelegate.color != color ||
      oldDelegate.direction != direction;
}
