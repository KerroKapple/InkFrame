// MediaKitVideoPlayerService：media_kit 版 VideoPlayerService 实现。

import 'package:media_kit/media_kit.dart';

import '../core/interfaces/video_player_service.dart';

class MediaKitVideoPlayerService implements VideoPlayerService {
  @override
  VideoPlayerHandle create() => _MediaKitHandle(Player());
}

class _MediaKitHandle implements VideoPlayerHandle {
  _MediaKitHandle(this._player);
  final Player _player;

  @override
  Future<void> open(String filePath) =>
      _player.open(Media(filePath), play: true);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration at) => _player.seek(at);

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration?> get durationStream => _player.stream.duration;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Object get rawPlayer => _player;
}
