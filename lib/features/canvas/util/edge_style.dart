// 连线外观判据（画布重设计稿 › 画布交互）：连线「是什么」决定它长什么样。
//
// 纯函数 + 值对象，不碰 Canvas——EdgePainter 照着画；单测不用起画布。
//
//   语义                       线型                    线宽   颜色槽       终点     标签
//   叙事 narrative             实线                    2.0    叙事（fg4）  箭头     —
//   数据 · 首帧 firstFrame     实线                    1.75   首帧色       箭头     首帧
//   数据 · 尾帧 lastFrame      实线                    1.75   尾帧色       箭头     尾帧
//   数据 · 参考 reference      虚线 5 / 4              1.5    参考色       箭头     参考
//   产出 generationSource      点线 1.5 / 3.5（圆头）  1.25   产出（fg6）  小箭头   —
//
// 产出线有两个来源，长得一样：存量的 generation_source 边，以及由 nodes.source_node_id
// 推导出来、不落库的产出线（lineage_edges.dart）。
//
// 颜色之外还靠线型和标签区分——色弱也分得清（与令牌注释同口径）。
// 当前链路（选中这条边 / 任一端点被选中）只把颜色换成 accent（或用户自定义连线色）；
// 线宽、线型、箭头、标签都照旧：选中说的是「它在链路上」，不能把「它是什么线」抹掉。
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

import '../models/canvas_edge.dart';

/// 叙事线线宽——最粗：它是成片的骨架。
const double kNarrativeEdgeWidth = 2.0;

/// 首帧 / 尾帧数据线线宽。
const double kFrameEdgeWidth = 1.75;

/// 参考数据线线宽。
const double kReferenceEdgeWidth = 1.5;

/// 产出线线宽——最细：它只是「这张图是谁出的」的注脚。
const double kLineageEdgeWidth = 1.25;

/// 线型的一个周期：画 [on]、空 [off]（沿弧长，px）。
typedef EdgeDash = ({double on, double off});

/// 参考线：虚线 5 / 4。
const EdgeDash kReferenceEdgeDash = (on: 5.0, off: 4.0);

/// 产出线：点线 1.5 / 3.5——段短到配上圆头看起来就是一串点。
const EdgeDash kLineageEdgeDash = (on: 1.5, off: 3.5);

/// 标签胶囊的描边宽（与连线同色）。
const double kEdgeLabelBorderWidth = 1.0;

/// 颜色槽：具体颜色由调用方的 [EdgePalette] 落值（令牌在 widget 层取，本文件不碰主题）。
enum EdgeColorSlot { narrative, lineage, firstFrame, lastFrame, reference, accent }

/// 标签：只有数据线的三种角色才标；叙事线 / 产出线不标。
enum EdgeLabelKind { none, firstFrame, lastFrame, reference }

/// 终点开口箭头：尖端落在终点，沿终点切线往回 [length]，两翼各偏 [halfWidth]。
enum EdgeArrow {
  regular(length: 7, halfWidth: 3.5),
  small(length: 5, halfWidth: 2.5);

  const EdgeArrow({required this.length, required this.halfWidth});

  final double length;
  final double halfWidth;
}

/// 一条连线的外观。
@immutable
class EdgeStyle {
  const EdgeStyle({
    required this.colorSlot,
    required this.strokeWidth,
    required this.arrow,
    this.dash,
    this.dotted = false,
    this.label = EdgeLabelKind.none,
  });

  final EdgeColorSlot colorSlot;
  final double strokeWidth;

  /// null = 实线。
  final EdgeDash? dash;

  /// 点线：每一段画圆头（StrokeCap.round），短段才显成点。
  final bool dotted;

  final EdgeArrow arrow;
  final EdgeLabelKind label;

  /// 当前链路：只换颜色槽，其余照旧。
  EdgeStyle _onChain() => EdgeStyle(
        colorSlot: EdgeColorSlot.accent,
        strokeWidth: strokeWidth,
        arrow: arrow,
        dash: dash,
        dotted: dotted,
        label: label,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgeStyle &&
          colorSlot == other.colorSlot &&
          strokeWidth == other.strokeWidth &&
          dash == other.dash &&
          dotted == other.dotted &&
          arrow == other.arrow &&
          label == other.label;

  @override
  int get hashCode =>
      Object.hash(colorSlot, strokeWidth, dash, dotted, arrow, label);

  @override
  String toString() => 'EdgeStyle(${colorSlot.name}, width: $strokeWidth, '
      'dash: $dash, dotted: $dotted, arrow: ${arrow.name}, label: ${label.name})';
}

const EdgeStyle _narrative = EdgeStyle(
  colorSlot: EdgeColorSlot.narrative,
  strokeWidth: kNarrativeEdgeWidth,
  arrow: EdgeArrow.regular,
);

const EdgeStyle _firstFrame = EdgeStyle(
  colorSlot: EdgeColorSlot.firstFrame,
  strokeWidth: kFrameEdgeWidth,
  arrow: EdgeArrow.regular,
  label: EdgeLabelKind.firstFrame,
);

const EdgeStyle _lastFrame = EdgeStyle(
  colorSlot: EdgeColorSlot.lastFrame,
  strokeWidth: kFrameEdgeWidth,
  arrow: EdgeArrow.regular,
  label: EdgeLabelKind.lastFrame,
);

const EdgeStyle _reference = EdgeStyle(
  colorSlot: EdgeColorSlot.reference,
  strokeWidth: kReferenceEdgeWidth,
  arrow: EdgeArrow.regular,
  dash: kReferenceEdgeDash,
  label: EdgeLabelKind.reference,
);

const EdgeStyle _lineage = EdgeStyle(
  colorSlot: EdgeColorSlot.lineage,
  strokeWidth: kLineageEdgeWidth,
  arrow: EdgeArrow.small,
  dash: kLineageEdgeDash,
  dotted: true,
);

/// 连线语义 → 外观。[role] 只对 data 线有意义（别的类型在库里恒为 reference，这里不看）；
/// [onChain] = 这条线被选中，或任一端点被选中。
EdgeStyle resolveEdgeStyle({
  required EdgeType type,
  EdgeRole role = EdgeRole.reference,
  bool onChain = false,
}) {
  final EdgeStyle base = switch (type) {
    EdgeType.narrative => _narrative,
    EdgeType.generationSource => _lineage,
    EdgeType.data => switch (role) {
        EdgeRole.firstFrame => _firstFrame,
        EdgeRole.lastFrame => _lastFrame,
        EdgeRole.reference => _reference,
      },
  };
  return onChain ? base._onChain() : base;
}

/// 颜色槽 → 实际颜色，外加标签胶囊的底色。值由 widget 层从令牌取（stage/stage_edge_layer.dart 的 StageEdgeLayer）。
@immutable
class EdgePalette {
  const EdgePalette({
    required this.narrative,
    required this.lineage,
    required this.firstFrame,
    required this.lastFrame,
    required this.reference,
    required this.accent,
    required this.chipFill,
  });

  /// 叙事线（fg4）。
  final Color narrative;

  /// 产出线（fg6）。
  final Color lineage;
  final Color firstFrame;
  final Color lastFrame;
  final Color reference;

  /// 当前链路色：用户自定义的连线色，没设就是 accent。
  final Color accent;

  /// 标签胶囊的底：画布底色，盖住胶囊下面那段线。
  final Color chipFill;

  Color colorOf(EdgeColorSlot slot) => switch (slot) {
        EdgeColorSlot.narrative => narrative,
        EdgeColorSlot.lineage => lineage,
        EdgeColorSlot.firstFrame => firstFrame,
        EdgeColorSlot.lastFrame => lastFrame,
        EdgeColorSlot.reference => reference,
        EdgeColorSlot.accent => accent,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgePalette &&
          narrative == other.narrative &&
          lineage == other.lineage &&
          firstFrame == other.firstFrame &&
          lastFrame == other.lastFrame &&
          reference == other.reference &&
          accent == other.accent &&
          chipFill == other.chipFill;

  @override
  int get hashCode => Object.hash(
        narrative,
        lineage,
        firstFrame,
        lastFrame,
        reference,
        accent,
        chipFill,
      );
}
