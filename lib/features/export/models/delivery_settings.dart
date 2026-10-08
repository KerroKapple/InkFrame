// 交付设置（P6）——按项目持久化的那一小撮，落在 `projects.delivery_settings`
// （JSONB，迁移 v8）。
//
// 为什么只有这六项：稿上交付面板有十来行，但其余全是定值，给它们存一份只会让
// 「能改」这件事看起来成立——帧率只读（没有字段，取自序列）、命名模板没有引擎、
// 转码只有「保持源」一种、轨道只有 V1、占位镜头固定「导出为空隙 + 标记」。
// 真正会变的就是目标软件、时间码起点，和四个开关。
//
// 手写不可变类而非 freezed：与 features/sequence、features/canvas 的既有惯例一致，
// 且规避 build_runner 卡点（BOARD 债 145）。
import 'package:flutter/foundation.dart';

import '../../sequence/util/timecode.dart' show kSequenceFps;

/// 稿上的默认时间码起点 01:00:00:00。
const int kDeliveryDefaultTcStartFrames = kSequenceFps * 3600;

/// 目标软件。四段照稿画，但只有两段真有写出器。
enum DeliveryTarget {
  resolve('resolve'),
  premiere('premiere'),
  finalCut('final_cut'),
  jianying('jianying');

  const DeliveryTarget(this.wire);

  /// 落库 / JSON 用的英文字面量（内部协议，不随 UI 语言变）。
  final String wire;

  /// 这一档会写出 EDL 吗。Resolve 与 Premiere 都吃 CMX3600。
  bool get writesEdl =>
      this == DeliveryTarget.resolve || this == DeliveryTarget.premiere;

  /// 有没有写出器。Final Cut（FCPXML）与剪映（草稿 JSON）都还没有——
  /// UI 必须把这两档标成「待支持」，不能让它们看起来能导。
  bool get supported => writesEdl;

  static DeliveryTarget fromWire(Object? wire) {
    for (final DeliveryTarget t in DeliveryTarget.values) {
      if (t.wire == wire) return t;
    }
    return DeliveryTarget.resolve;
  }
}

@immutable
class DeliverySettings {
  const DeliverySettings({
    required this.target,
    required this.timecodeStartFrames,
    required this.relativePaths,
    required this.markersFromScenes,
    required this.shotLanguageInComments,
    required this.promptInMetadata,
  });

  /// 稿上那一屏的初始态。
  static const DeliverySettings defaults = DeliverySettings(
    target: DeliveryTarget.resolve,
    timecodeStartFrames: kDeliveryDefaultTcStartFrames,
    relativePaths: true,
    markersFromScenes: true,
    shotLanguageInComments: true,
    promptInMetadata: false,
  );

  final DeliveryTarget target;

  /// EDL 记录端的起点，单位帧。
  final int timecodeStartFrames;

  /// 媒体引用写相对路径（随文件夹搬迁）。
  final bool relativePaths;

  /// 场次边界导成时间线标记。
  final bool markersFromScenes;

  /// 镜头语言写进片段备注。
  final bool shotLanguageInComments;

  /// 提示词写进 metadata.json。稿上唯一默认关着的开关。
  final bool promptInMetadata;

  DeliverySettings copyWith({
    DeliveryTarget? target,
    int? timecodeStartFrames,
    bool? relativePaths,
    bool? markersFromScenes,
    bool? shotLanguageInComments,
    bool? promptInMetadata,
  }) => DeliverySettings(
    target: target ?? this.target,
    timecodeStartFrames: timecodeStartFrames ?? this.timecodeStartFrames,
    relativePaths: relativePaths ?? this.relativePaths,
    markersFromScenes: markersFromScenes ?? this.markersFromScenes,
    shotLanguageInComments:
        shotLanguageInComments ?? this.shotLanguageInComments,
    promptInMetadata: promptInMetadata ?? this.promptInMetadata,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'target': target.wire,
    'tc_start_frames': timecodeStartFrames,
    'relative_paths': relativePaths,
    'markers_from_scenes': markersFromScenes,
    'shot_language_in_comments': shotLanguageInComments,
    'prompt_in_metadata': promptInMetadata,
  };

  /// 容错解析：缺失 / 类型不符 / 非法值一律退默认，**绝不抛**。
  /// 旧项目这一列是空对象；手改坏了的值也可能进来，一个坏字段不该让项目打不开。
  factory DeliverySettings.fromMap(Map<String, Object?>? m) {
    if (m == null) return defaults;
    bool flag(String k, bool fallback) {
      final Object? v = m[k];
      return v is bool ? v : fallback;
    }

    final Object? tc = m['tc_start_frames'];
    return DeliverySettings(
      target: DeliveryTarget.fromWire(m['target']),
      // 负起点在 EDL 里写不出来，当坏值处理。
      timecodeStartFrames: tc is int && tc >= 0
          ? tc
          : kDeliveryDefaultTcStartFrames,
      relativePaths: flag('relative_paths', true),
      markersFromScenes: flag('markers_from_scenes', true),
      shotLanguageInComments: flag('shot_language_in_comments', true),
      promptInMetadata: flag('prompt_in_metadata', false),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliverySettings &&
          other.target == target &&
          other.timecodeStartFrames == timecodeStartFrames &&
          other.relativePaths == relativePaths &&
          other.markersFromScenes == markersFromScenes &&
          other.shotLanguageInComments == shotLanguageInComments &&
          other.promptInMetadata == promptInMetadata;

  @override
  int get hashCode => Object.hash(
    target,
    timecodeStartFrames,
    relativePaths,
    markersFromScenes,
    shotLanguageInComments,
    promptInMetadata,
  );
}
