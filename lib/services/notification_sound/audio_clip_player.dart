// AudioClipPlayer：播一小段音频的缝——打包的提示音资产，或用户自选的文件。
//
// NotificationSoundPlayer 只认这个抽象（测试换成记录调用的假实现，不碰 media_kit）；
// 生产实现 MediaKitAudioClipPlayer 在 main.dart 装配。
//
// MediaKitAudioClipPlayer 的几个取舍：
// - **一个**懒建的 Player：第一次响才起 mpv，之后一直复用，退出时随容器释放。
// - PlayerConfiguration.title = 'InkFrame'：默认标题是 'package:media_kit'，Windows 的
//   音量合成器里就显示这个，用户不知道是谁在响。
// - mpv 开着 keep-open=yes：播完停在末尾、文件仍装着。同一份资产再响一次只要
//   seek(0) + play()，不必重新装载；文件则每次都重新 open（同名文件可能已被换掉）。
// - 自定义文件只播前 maxDuration：到点用 Timer 调 stop()——stop 会卸载文件、放掉句柄，
//   Windows 上这份文件之后才能被下一次导入覆盖。下一次播放 / dispose 都会先取消这个 Timer。
import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../../core/logging/logger_service.dart';

abstract class AudioClipPlayer {
  /// 播打包进应用的资产（[assetKey] 形如 `assets/sounds/notification.wav`）。
  /// 失败只记日志、绝不抛。
  Future<void> playAsset(String assetKey);

  /// 播磁盘上的文件（绝对路径）。[maxDuration] 不为 null 时最多播这么久。
  /// 失败只记日志、绝不抛。
  Future<void> playFile(String path, {Duration? maxDuration});

  /// 释放播放器。之后的播放调用一律静默忽略。
  Future<void> dispose();
}

class MediaKitAudioClipPlayer implements AudioClipPlayer {
  MediaKitAudioClipPlayer({required LoggerService logger}) : _logger = logger;

  final LoggerService _logger;

  static const String _logModule = 'notifications.sound';

  Player? _player;
  Timer? _stopTimer;
  bool _disposed = false;

  /// 每次播放自增。异步链（open / seek）走完时若已不是最新一次，就不再给它挂停止计时器——
  /// 否则前一个文件的 4 秒计时器会把后面那次播放掐掉。
  int _generation = 0;

  @override
  Future<void> playAsset(String assetKey) =>
      _play('asset:///$assetKey', kind: 'asset', reuseIfLoaded: true);

  @override
  Future<void> playFile(String path, {Duration? maxDuration}) => _play(
        path,
        kind: 'file',
        reuseIfLoaded: false,
        maxDuration: maxDuration,
      );

  Future<void> _play(
    String resource, {
    required String kind,
    required bool reuseIfLoaded,
    Duration? maxDuration,
  }) async {
    if (_disposed) return;
    final int generation = ++_generation;
    _cancelStopTimer();
    try {
      final Player player = _player ??= Player(
        configuration: const PlayerConfiguration(title: 'InkFrame'),
      );
      // Media 的构造就会解析资源（资产找不到在这里就抛），所以放在 try 里。
      final Media media = Media(resource);
      final List<Media> loaded = player.state.playlist.medias;
      if (reuseIfLoaded && loaded.length == 1 && loaded.single == media) {
        await player.seek(Duration.zero);
        await player.play();
      } else {
        await player.open(media);
      }
      if (maxDuration != null && !_disposed && generation == _generation) {
        _stopTimer = Timer(
          maxDuration,
          () => unawaited(_stopIfCurrent(generation)),
        );
      }
    } catch (e) {
      // media_kit 抛的是裸 Exception / AssertionError（「Unable to load asset」「[Player] has
      // been disposed」…），没有可以 on 的具体类型——与 media_kit_thumbnail_service 同一处
      // 放行。提示音失败只记日志，绝不往上抛。路径不进日志（含用户目录名）。
      _logger.warn(
        _logModule,
        'notification_sound.clip_failed',
        extra: <String, Object?>{'kind': kind, 'error': e.toString()},
      );
    }
  }

  Future<void> _stopIfCurrent(int generation) async {
    if (_disposed || generation != _generation) return;
    _stopTimer = null;
    final Player? player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (e) {
      // 同上：media_kit 的裸异常，只记日志。
      _logger.warn(
        _logModule,
        'notification_sound.clip_stop_failed',
        extra: <String, Object?>{'error': e.toString()},
      );
    }
  }

  void _cancelStopTimer() {
    _stopTimer?.cancel();
    _stopTimer = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _cancelStopTimer();
    final Player? player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (e) {
      // 同上：media_kit 的裸异常，只记日志——退出路径不能被提示音拦住。
      _logger.warn(
        _logModule,
        'notification_sound.clip_dispose_failed',
        extra: <String, Object?>{'error': e.toString()},
      );
    }
  }
}
