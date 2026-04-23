// ThumbnailService 抽象：从本地视频抽首帧缩略图。
//
// T5-S3 只声明接口 + 占位 Provider（返回 null）；
// T5-S4 换 media_kit 实现。

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
