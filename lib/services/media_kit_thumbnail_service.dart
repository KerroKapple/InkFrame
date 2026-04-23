// MediaKitThumbnailService：用 media_kit 的 Player.screenshot 抽视频首帧。
//
// 流程：Player.open(play: false) → seek(Duration.zero) → 300ms 等待解码 →
// screenshot(format: 'image/jpeg') → 写入 destination → dispose。
// 任一步失败均转成 [ThumbnailError]。

import 'dart:io';

import 'package:media_kit/media_kit.dart';

import '../core/interfaces/thumbnail_service.dart';

class MediaKitThumbnailService implements ThumbnailService {
  @override
  Future<File> extractFirstFrame({
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
      return destination;
    } catch (e) {
      if (e is ThumbnailError) rethrow;
      throw ThumbnailError('media_kit_failed', cause: e);
    } finally {
      await player.dispose();
    }
  }
}
