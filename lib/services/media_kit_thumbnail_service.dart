// MediaKitThumbnailService：用 media_kit 的 Player.screenshot 抽视频首帧 +
// 顺读 player.state 探针时长 / 宽 / 高。
//
// 流程：Player.open(play: false) → seek(Duration.zero) → 300ms 等待解码 →
// screenshot(format: 'image/jpeg') → 写入 destination → 顺读 player.state → dispose。
// 任一步失败均转成 [ThumbnailError]。
// player.state 的时长 / 宽 / 高经 [VideoProbeResult.fromProbe] 归一（非正 → null，绝不臆造）。

import 'dart:io';

import 'package:media_kit/media_kit.dart';

import '../core/interfaces/thumbnail_service.dart';

class MediaKitThumbnailService implements ThumbnailService {
  @override
  Future<VideoProbeResult> extractFirstFrame({
    required String videoPath,
    required File destination,
  }) async {
    final player = Player();
    try {
      await player.open(Media(videoPath), play: false);
      await player.seek(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final bytes = await player.screenshot(format: 'image/jpeg');
      if (bytes == null || bytes.isEmpty) {
        throw const ThumbnailError('screenshot returned empty');
      }
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(bytes);
      // 首帧已解码，顺读一次 state 快照探针元数据（不可得的字段归一为 null）。
      final state = player.state;
      return VideoProbeResult.fromProbe(
        thumbnail: destination,
        duration: state.duration,
        width: state.width,
        height: state.height,
      );
    } catch (e) {
      if (e is ThumbnailError) rethrow;
      throw ThumbnailError('media_kit_failed', cause: e);
    } finally {
      await player.dispose();
    }
  }
}
