// GalleryGraph：画廊一次聚合读出来的「项目图」——各画布的节点 / 连线 / 批量 slot / 基底风格。
//
// 画廊的产物列表（GalleryItem）、筛选分组计数、右栏信息、血缘反查全从这一份图上算，
// 不各自再去查库。手写不可变值对象（同 ShellState：build_runner 工具链受阻）。
import 'package:flutter/foundation.dart';

import '../../canvas/models/canvas_edge.dart';
import '../../canvas/models/canvas_node.dart';

@immutable
class GalleryCanvasInfo {
  const GalleryCanvasInfo({
    required this.id,
    required this.name,
    this.baseStylePrefix = '',
  });
  final String id;
  final String name;
  final String baseStylePrefix;
}

/// batch_results 里一条成功 slot（只保留画廊要用的列）。
@immutable
class GalleryBatchSlot {
  const GalleryBatchSlot({
    required this.nodeId,
    required this.canvasId,
    required this.slotIndex,
    required this.outputUrl,
    required this.createdAt,
    this.promoted = false,
  });
  final String nodeId;
  final String canvasId;
  final int slotIndex;
  final String outputUrl;
  final DateTime createdAt;
  final bool promoted;
}

@immutable
class GalleryGraph {
  const GalleryGraph({
    required this.canvases,
    required this.nodesByCanvas,
    required this.edgesByCanvas,
    required this.slotsByNode,
  });

  static const GalleryGraph empty = GalleryGraph(
    canvases: <GalleryCanvasInfo>[],
    nodesByCanvas: <String, List<CanvasNode>>{},
    edgesByCanvas: <String, List<CanvasEdge>>{},
    slotsByNode: <String, List<GalleryBatchSlot>>{},
  );

  /// 画布按 listByProject 的顺序。
  final List<GalleryCanvasInfo> canvases;
  final Map<String, List<CanvasNode>> nodesByCanvas;
  final Map<String, List<CanvasEdge>> edgesByCanvas;
  /// config 节点 id → 它的成功 slot（按 slotIndex 升序）。
  final Map<String, List<GalleryBatchSlot>> slotsByNode;

  GalleryCanvasInfo? canvas(String id) {
    for (final GalleryCanvasInfo c in canvases) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<CanvasNode> nodesOf(String canvasId) =>
      nodesByCanvas[canvasId] ?? const <CanvasNode>[];

  List<CanvasEdge> edgesOf(String canvasId) =>
      edgesByCanvas[canvasId] ?? const <CanvasEdge>[];

  List<GalleryBatchSlot> slotsOf(String nodeId) =>
      slotsByNode[nodeId] ?? const <GalleryBatchSlot>[];
}
