// ThumbnailService 抽象：从本地视频抽首帧缩略图。
//
// 实现：MediaKitThumbnailService（Player.screenshot 抽帧）。
// thumbnailServiceProvider 类型保持可空——null 是 JobQueueService 的
// 跳过抽帧开关（headless / 测试场景），并非"未实现占位"。

import 'dart:io';

abstract class ThumbnailService {
  /// 把 [videoPath] 的首帧写到 [destination]。
  /// 任何失败（解码 / 写盘）→ 抛 [ThumbnailError]。
  Future<File> extractFirstFrame({
    required String videoPath,
    required File destination,
  });
}

class ThumbnailError implements Exception {
  const ThumbnailError(this.reason, {this.cause});
  final String reason;
  final Object? cause;

  @override
  String toString() => 'ThumbnailError($reason)';
}
