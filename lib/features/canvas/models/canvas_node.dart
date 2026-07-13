// CanvasNode：画布上的节点 UI 模型。
//
// S1a 起补齐 PRD §4 核心字段：
//   - role (config / result) — 决定是否可编辑/发起生成
//   - projectId / canvasId — 生成落盘路径需要；单测允许为空
//   - sourceNodeId — result 节点的溯源 config（PRD §4.5.1 孤儿语义）
//
// 此阶段仍为 UI 本地 state；S1b 起由 CanvasScreenController 从 NodeRepository 拉。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/db/columns.dart';
import '../../../core/db/row_reader.dart';

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
    this.laneId,
    this.typeConfig = const <String, Object?>{},
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

  /// 所属泳道 id（schema nodes.lane_id）；不在任何泳道时为 null。
  final String? laneId;

  /// 对应 schema nodes.type_config JSONB。常用键：
  ///   config 节点：prompt / provider_id / resolution / aspect_ratio
  ///   result 节点：image_url (相对路径)
  final Map<String, Object?> typeConfig;

  final Offset position;
  final Size size;

  /// 便捷获取 result 节点的相对图像路径；config 节点或未设置时为 null。
  String? get imageUrl {
    final v = typeConfig['image_url'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// video result 节点的相对视频路径；非 video 或未设置时为 null。
  String? get videoUrl {
    final v = typeConfig['video_url'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// video result 节点的首帧缩略图相对路径；未抽帧时为 null。
  String? get thumbnailUrl {
    final v = typeConfig['thumbnail_url'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// video config 节点的时长（毫秒）；未设置返回 null。
  int? get durationMs {
    final v = typeConfig['duration_ms'];
    return v is int ? v : null;
  }

  /// video config 节点的运镜名（CameraMovement.name）；未设置返回 null。
  String? get cameraName {
    final v = typeConfig['camera'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// video config 节点的生成模式（"t2v" / "i2v"）；未设置返回 null，
  /// 生成时按 incoming data edges 自动推断（见 GenerationController）。
  String? get videoMode {
    final v = typeConfig['mode'];
    return v is String && v.isNotEmpty ? v : null;
  }

  /// config 节点用户 prompt 文本；非 String 或未设置时为 null。
  String? get promptText {
    final v = typeConfig['prompt'];
    return v is String ? v : null;
  }

  /// text 节点正文（type_config.text）；非 String 或未设置时为 null。
  String? get textContent {
    final v = typeConfig['text'];
    return v is String ? v : null;
  }

  /// 该节点是否忽略所属泳道的风格（type_config.ignore_lane_style）。
  bool get ignoreLaneStyle => typeConfig['ignore_lane_style'] == true;

  CanvasNode copyWith({
    String? label,
    CanvasNodeType? type,
    NodeRole? role,
    String? projectId,
    String? canvasId,
    String? sourceNodeId,
    String? laneId,
    bool clearLaneId = false,
    Map<String, Object?>? typeConfig,
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
        laneId: clearLaneId ? null : (laneId ?? this.laneId),
        typeConfig: typeConfig ?? this.typeConfig,
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
          laneId == other.laneId &&
          mapEquals(typeConfig, other.typeConfig) &&
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
        laneId,
        Object.hashAllUnordered(
            typeConfig.entries.map((e) => Object.hash(e.key, e.value))),
        position,
        size,
      );
}

enum CanvasNodeType { image, text, video, shot }

/// 各类型新建节点的默认尺寸——media 类放大容纳预览，text/shot 保持紧凑。
/// 仅作用于新建（addNode 未显式传 size）；已存节点尺寸以 DB 行为准。
Size defaultNodeSize(CanvasNodeType type) => switch (type) {
      CanvasNodeType.image => const Size(260, 220),
      CanvasNodeType.video => const Size(280, 220),
      CanvasNodeType.shot => const Size(240, 200),
      CanvasNodeType.text => const Size(220, 160),
    };

extension CanvasNodeMapping on CanvasNode {
  /// 从 NodeRepository.listByCanvas 返回的单行 Map 构造 UI 模型。
  ///
  /// 容错：type 非法 → throw；role 非法 → throw（schema CHECK 已保护，UI 层再加一道断言）。
  /// 其余可选字段缺失 → null / 默认值。
  static CanvasNode fromRow(Map<String, Object?> row) {
    final typeStr = row.reqString(NodeCol.type);
    final roleStr = row.reqString(NodeCol.nodeRole);
    return CanvasNode(
      id: row.reqId(NodeCol.id),
      label: row.optString(NodeCol.label) ?? '',
      type: CanvasNodeType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => throw FormatException('Unknown node type: $typeStr'),
      ),
      role: NodeRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => throw FormatException('Unknown node role: $roleStr'),
      ),
      projectId: row.optId(NodeCol.projectId),
      canvasId: row.optId(NodeCol.canvasId),
      sourceNodeId: row.optId(NodeCol.sourceNodeId),
      laneId: row.optId(NodeCol.laneId),
      typeConfig: _parseTypeConfig(row[NodeCol.typeConfig]),
      position: Offset(
        row.optDouble(NodeCol.positionX) ?? 0,
        row.optDouble(NodeCol.positionY) ?? 0,
      ),
      size: Size(
        row.optDouble(NodeCol.width) ?? 240,
        row.optDouble(NodeCol.height) ?? 240,
      ),
    );
  }
}

Map<String, Object?> _parseTypeConfig(Object? raw) {
  if (raw == null) return const <String, Object?>{};
  if (raw is Map<String, Object?>) return Map.unmodifiable(raw);
  if (raw is Map) {
    return Map.unmodifiable(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map.unmodifiable(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    } on FormatException {
      // 无效 JSON → 当空对象处理
    }
  }
  return const <String, Object?>{};
}

