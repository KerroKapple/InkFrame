// CanvasNode：画布上的节点 UI 模型。
//
// 此阶段为 UI 本地 state，不接 DB。后续 T6 集成时
// 由 Service 层从 Repository 的 Map<String,Object?> 转换。

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

@immutable
class CanvasNode {
  const CanvasNode({
    required this.id,
    required this.label,
    required this.type,
    this.position = Offset.zero,
    this.size = const Size(200, 160),
  });

  final String id;
  final String label;
  final CanvasNodeType type;
  final Offset position;
  final Size size;

  CanvasNode copyWith({
    String? label,
    CanvasNodeType? type,
    Offset? position,
    Size? size,
  }) =>
      CanvasNode(
        id: id,
        label: label ?? this.label,
        type: type ?? this.type,
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
          position == other.position &&
          size == other.size;

  @override
  int get hashCode => Object.hash(id, label, type, position, size);
}

enum CanvasNodeType { image, text, video, shot }
