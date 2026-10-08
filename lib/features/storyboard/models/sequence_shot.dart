// 序列预览里的一「镜」。
//
// 不是画布节点的镜像——是「按叙事链走一遍、每镜该显示什么、显示多久」的
// 播放清单条目。构建规则见 `util/sequence_builder.dart`。
//
// 与 canvas 的 CanvasNode / CanvasEdge 一样手写不可变类而非 freezed：
// 与该 feature 既有惯例一致，且规避 build_runner 卡点（BOARD 债 145）。

import 'package:flutter/foundation.dart';

/// 这一镜实际能放出什么。
enum SequenceArtifactKind {
  image,
  video,

  /// 还没生成任何产物——放 notes 占位，但**照样计时**（卡面要求），
  /// 这样预览的总时长就是成片的预期时长。
  none,
}

/// 没有任何时长信息时每镜停留多久。
const int kDefaultShotDurationMs = 3000;

@immutable
class SequenceShot {
  const SequenceShot({
    required this.nodeId,
    required this.kind,
    required this.durationMs,
    this.label = '',
    this.notes,
    this.relativePath,
    this.canvasId,
    this.thumbnailRelativePath,
    this.artifactNodeId,
    this.width,
    this.height,
  });

  /// 链上贡献这一镜的节点 id（shot 节点，或没有 shot 包裹时的 config 节点）。
  final String nodeId;

  final SequenceArtifactKind kind;

  /// 这一镜停留多久。视频以真实播放进度推进，本值是**兜底**
  /// （拿不到 duration / 播放器不推进时不至于卡死在一镜）。
  final int durationMs;

  final String label;

  /// 无产物时展示的文字（shot_notes，退而求其次用 config 的 prompt）。
  final String? notes;

  /// 产物的**画布相对**路径；[kind] 为 none 时为 null。
  final String? relativePath;

  /// 产物所属画布 id——解析绝对路径要用（同一序列理论上同画布，
  /// 但不做此假设，跟着产物走）。
  final String? canvasId;

  /// 缩略图的画布相对路径（视频取 thumbnail_url，图片就是产物本身）；无产物为 null。
  /// 序列视图的叙事链行 / V1 片段用它，不为列表去解视频。
  final String? thumbnailRelativePath;

  /// 贡献这一镜产物的 **result 节点 id**；无产物为 null。
  ///
  /// 为什么不让下游自己从 [nodeId] 反查：sequence_builder 会把后继 config 的产物
  /// 「借」给前面的 shot（见该文件头注），借来的产物挂在**别人**名下，
  /// `latestResultFor(sourceNodeId: shot.nodeId)` 查不到。P6 交付要按镜取
  /// provider / seed / 提示词 / 像素尺寸，必须有这条回指。
  final String? artifactNodeId;

  /// 产物像素宽高（视频由 XM-1 抽帧探针写入 type_config）。
  /// **抽帧失败时这两个字段就是缺的**——缺了算「未知」，不等于不一致（P6 画幅检查口径）。
  final int? width;
  final int? height;

  Duration get duration => Duration(milliseconds: durationMs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SequenceShot &&
          nodeId == other.nodeId &&
          kind == other.kind &&
          durationMs == other.durationMs &&
          label == other.label &&
          notes == other.notes &&
          relativePath == other.relativePath &&
          canvasId == other.canvasId &&
          thumbnailRelativePath == other.thumbnailRelativePath &&
          artifactNodeId == other.artifactNodeId &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(
        nodeId,
        kind,
        durationMs,
        label,
        notes,
        relativePath,
        canvasId,
        thumbnailRelativePath,
        artifactNodeId,
        width,
        height,
      );

  @override
  String toString() =>
      'SequenceShot($nodeId, $kind, ${durationMs}ms, path=$relativePath)';
}
