// CanvasNode：画布上的节点 UI 模型。
//
// S1a 起补齐 PRD §4 核心字段：
//   - role (config / result) — 决定是否可编辑/发起生成
//   - projectId / canvasId — 生成落盘路径需要；单测允许为空
//   - sourceNodeId — result 节点的溯源 config（PRD §4.5.1 孤儿语义）
//
// 此阶段仍为 UI 本地 state；S1b 起由 CanvasScreenController 从 NodeRepository 拉。

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 节点角色（对应 schema `nodes.node_role`）。
enum NodeRole { config, result }

@immutable
class CanvasNode {
  const CanvasNode({
    required this.id,
    required this.label,
    required this.type,
    this.role = NodeRole.config,
    this.projectId,
    this.canvasId,
    this.sourceNodeId,
    this.position = Offset.zero,
    this.size = const Size(200, 160),
  });

  final String id;
  final String label;
  final CanvasNodeType type;
  final NodeRole role;

  /// 所属项目 / 画布 id——生产 path 必填，UI 单测允许 null。
  final String? projectId;
  final String? canvasId;

  /// result 节点的溯源 config 节点 id（config 节点恒为 null）。
  final String? sourceNodeId;

  final Offset position;
  final Size size;

  CanvasNode copyWith({
    String? label,
    CanvasNodeType? type,
    NodeRole? role,
    String? projectId,
    String? canvasId,
    String? sourceNodeId,
    Offset? position,
    Size? size,
  }) =>
      CanvasNode(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
        role: role ?? this.role,
        projectId: projectId ?? this.projectId,
        canvasId: canvasId ?? this.canvasId,
        sourceNodeId: sourceNodeId ?? this.sourceNodeId,
        position: position ?? this.position,
        size: size ?? this.size,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasNode &&
          id == other.id &&
          label == other.label &&
          type == other.type &&
          role == other.role &&
          projectId == other.projectId &&
          canvasId == other.canvasId &&
          sourceNodeId == other.sourceNodeId &&
          position == other.position &&
          size == other.size;

  @override
  int get hashCode => Object.hash(
        id,
        label,
        type,
        role,
        projectId,
        canvasId,
        sourceNodeId,
        position,
        size,
      );
}

enum CanvasNodeType { image, text, video, shot }
