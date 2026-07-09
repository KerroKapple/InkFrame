// ThumbnailService 抽象：从本地视频抽首帧缩略图 + 顺带探针视频元数据。
//
// 实现：MediaKitThumbnailService（Player.screenshot 抽帧 + player.state 读元数据）。
// thumbnailServiceProvider 类型保持可空——null 是 JobQueueService 的
// 跳过抽帧开关（headless / 测试场景），并非"未实现占位"。

import 'dart:io';

abstract class ThumbnailService {
  /// 把 [videoPath] 的首帧写到 [destination]，并顺带探针时长 / 宽 / 高。
  /// 任何失败（解码 / 写盘）→ 抛 [ThumbnailError]。
  Future<VideoProbeResult> extractFirstFrame({
    required String videoPath,
    required File destination,
  });
}

/// 视频探针结果：首帧缩略图 + 可选元数据（毫秒时长 / 像素宽高）。
/// 手写不可变值类型（codegen 阻断，不用 freezed）。元数据不可得时为 null，绝不臆造。
class VideoProbeResult {
  const VideoProbeResult({
    required this.thumbnail,
    this.durationMs,
    this.width,
    this.height,
  });

  /// 从底层 player 探针的原始时长 / 宽 / 高构造：非正值（0 / 负 / null）
  /// 一律视为不可得 → null，绝不臆造。thumbnail 恒非空。
  factory VideoProbeResult.fromProbe({
    required File thumbnail,
    Duration? duration,
    int? width,
    int? height,
  }) {
    final ms = duration?.inMilliseconds ?? 0;
    return VideoProbeResult(
      thumbnail: thumbnail,
      durationMs: ms > 0 ? ms : null,
      width: (width != null && width > 0) ? width : null,
      height: (height != null && height > 0) ? height : null,
    );
  }

  /// 首帧缩略图文件（恒非空——抽帧成功才返回结果）。
  final File thumbnail;

  /// 视频时长（毫秒）；不可得为 null。
  final int? durationMs;

  /// 视频像素宽 / 高；不可得为 null。
  final int? width;
  final int? height;
}

class ThumbnailError implements Exception {
  const ThumbnailError(this.reason, {this.cause});
  final String reason;
  final Object? cause;

  @override
  String toString() => 'ThumbnailError($reason)';
}
