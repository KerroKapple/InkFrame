// VideoPlayerService：对底层视频播放器的抽象（ADR-0006：media_kit）。
//
// UI / widget 不直接依赖 media_kit；通过本接口 + Riverpod 注入。
// 每个 Lightbox 实例独立 create() 出 handle，关闭时 handle.dispose() 释放。
//
// 生产实现：MediaKitVideoPlayerService。测试可 Fake。

abstract class VideoPlayerService {
  /// 创建一个独立的播放 handle。调用方负责调 dispose。
  VideoPlayerHandle create();
}

abstract class VideoPlayerHandle {
  Future<void> open(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration at);

  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;

  Future<void> dispose();

  /// media_kit 的 Player 对象——仅给 media_kit_video 的 Video widget 构造
  /// VideoController 用。接口返回 [Object] 避免把 media_kit 类型泄漏到 core 层。
  Object get rawPlayer;
}
