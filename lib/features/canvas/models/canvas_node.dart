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

  CanvasNode copyWith({
    String? label,
    CanvasNodeType? type,
    NodeRole? role,
    String? projectId,
    String? canvasId,
    String? sourceNodeId,
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
        Object.hashAll(typeConfig.entries
            .map((e) => Object.hash(e.key, e.value))),
        position,
        size,
      );
}

enum CanvasNodeType { image, text, video, shot }

extension CanvasNodeMapping on CanvasNode {
  /// 从 NodeRepository.listByCanvas 返回的单行 Map 构造 UI 模型。
  ///
  /// 容错：type 非法 → throw；role 非法 → throw（schema CHECK 已保护，UI 层再加一道断言）。
  /// 其余可选字段缺失 → null / 默认值。
  static CanvasNode fromRow(Map<String, Object?> row) {
    final typeStr = row['type'] as String;
    final roleStr = row['node_role'] as String;
    return CanvasNode(
      id: row['id']!.toString(),
      label: (row['label'] as String?) ?? '',
      type: CanvasNodeType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => throw FormatException('Unknown node type: $typeStr'),
      ),
      role: NodeRole.values.firstWhere(
        (e) => e.name == roleStr,
        orElse: () => throw FormatException('Unknown node role: $roleStr'),
      ),
      projectId: row['project_id'] as String?,
      canvasId: row['canvas_id']?.toString(),
      sourceNodeId: row['source_node_id']?.toString(),
      typeConfig: _parseTypeConfig(row['type_config']),
      position: Offset(
        _asDouble(row['position_x']) ?? 0,
        _asDouble(row['position_y']) ?? 0,
      ),
      size: Size(
        _asDouble(row['width']) ?? 240,
        _asDouble(row['height']) ?? 240,
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

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
