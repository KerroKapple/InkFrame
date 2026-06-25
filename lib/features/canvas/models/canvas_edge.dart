// CanvasEdge：画布 UI 侧连线模型（对应 schema edges 表）。
//
// P1 scope 先覆盖 data / generation_source / narrative 三类。本文件不维护
// source/target 端点坐标——渲染时从节点表动态查 position，避免状态冗余。

import 'package:flutter/foundation.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';

/// 连线类型（对应 schema `edges.edge_type`）。
enum EdgeType { data, narrative, generationSource }

/// data 连线的 role（对应 schema `edges.role`）；其他类型固定 [EdgeRole.reference]。
enum EdgeRole { reference, firstFrame, lastFrame }

@immutable
class CanvasEdge {
  const CanvasEdge({
    required this.id,
    required this.canvasId,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.edgeType,
    this.role = EdgeRole.reference,
    this.sortOrder = 0,
  });

  final String id;
  final String canvasId;
  final String sourceNodeId;
  final String targetNodeId;
  final EdgeType edgeType;
  final EdgeRole role;
  final int sortOrder;

  CanvasEdge copyWith({
    EdgeRole? role,
    int? sortOrder,
  }) =>
      CanvasEdge(
        id: id,
        canvasId: canvasId,
        sourceNodeId: sourceNodeId,
        targetNodeId: targetNodeId,
        edgeType: edgeType,
        role: role ?? this.role,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasEdge &&
          id == other.id &&
          canvasId == other.canvasId &&
          sourceNodeId == other.sourceNodeId &&
          targetNodeId == other.targetNodeId &&
          edgeType == other.edgeType &&
          role == other.role &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(id, canvasId, sourceNodeId, targetNodeId,
      edgeType, role, sortOrder);
}

extension CanvasEdgeMapping on CanvasEdge {
  /// EdgeRepository row → UI model。
  static CanvasEdge fromRow(Map<String, Object?> row) {
    final typeStr = row.reqString(EdgeCol.edgeType);
    final roleStr = row.optString(EdgeCol.role) ?? 'reference';
    return CanvasEdge(
      id: row.reqId(EdgeCol.id),
      canvasId: row.reqId(EdgeCol.canvasId),
      sourceNodeId: row.reqId(EdgeCol.sourceNodeId),
      targetNodeId: row.reqId(EdgeCol.targetNodeId),
      edgeType: _parseType(typeStr),
      role: _parseRole(roleStr),
      sortOrder: row.optInt(EdgeCol.sortOrder) ?? 0,
    );
  }

  static EdgeType _parseType(String s) => switch (s) {
        'data' => EdgeType.data,
        'narrative' => EdgeType.narrative,
        'generation_source' => EdgeType.generationSource,
        _ => throw FormatException('Unknown edge_type: $s'),
      };

  static EdgeRole _parseRole(String s) => switch (s) {
        'reference' => EdgeRole.reference,
        'first_frame' => EdgeRole.firstFrame,
        'last_frame' => EdgeRole.lastFrame,
        _ => throw FormatException('Unknown edge role: $s'),
      };

  /// UI → Repository 写入时用的 snake_case 值。
  static String typeToDb(EdgeType t) => switch (t) {
        EdgeType.data => 'data',
        EdgeType.narrative => 'narrative',
        EdgeType.generationSource => 'generation_source',
      };

  static String roleToDb(EdgeRole r) => switch (r) {
        EdgeRole.reference => 'reference',
        EdgeRole.firstFrame => 'first_frame',
        EdgeRole.lastFrame => 'last_frame',
      };
}
