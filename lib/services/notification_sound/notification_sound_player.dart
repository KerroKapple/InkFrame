// NotificationSoundPlayer：NotificationSoundService 的真实现——按设置里的选择出声。
//
// - InkFrame 默认 → AudioClipPlayer.playAsset（打包的提示音，tool/sounds 生成）
// - 系统提示音 → SystemAlertSound（Windows「通知」/ macOS 提醒音，跟随系统设置）
// - 自定义 → AudioClipPlayer.playFile，最多播 kCustomNotificationSoundMaxPlay；
//   路径为 null 或文件已不在（被删 / 数据目录被清）就静默不响
// - 关闭 → 什么都不做
//
// 节流：距上一次**真正出声**不到 1200 ms 的请求直接丢掉——一批任务同时完成时只响一声，
// 不连成一串。被丢掉的请求不顺延窗口；关闭、自定义文件缺失这类「本来就不响」的请求
// 也不占窗口。时钟回拨（距上次为负）不算在窗口内，否则回拨多久就哑多久。
//
// 契约是「绝不抛」：两条缝各自承诺不抛，这里再兜一层——提示音失败只记日志，不能把
// 调用方（通知卡、设置页的试听）带崩。
import 'dart:io';

import '../../core/constants/notification_sound.dart';
import '../../core/interfaces/notification_sound_service.dart';
import '../../core/logging/logger_service.dart';
import 'audio_clip_player.dart';
import 'system_alert_sound.dart';

/// InkFrame 默认提示音的资产键（pubspec 声明 assets/sounds/；文件由
/// tool/sounds/generate_notification_chime.dart 生成）。
const String kNotificationChimeAsset = 'assets/sounds/notification.wav';

class NotificationSoundPlayer implements NotificationSoundService {
  NotificationSoundPlayer({
    required AudioClipPlayer clips,
    required SystemAlertSound systemSound,
    required Clock clock,
    required LoggerService logger,
  })  : _clips = clips,
        _systemSound = systemSound,
        _clock = clock,
        _logger = logger;

  final AudioClipPlayer _clips;
  final SystemAlertSound _systemSound;
  final Clock _clock;
  final LoggerService _logger;

  static const String _logModule = 'notifications.sound';

  /// 两次出声之间的最短间隔。
  static const Duration _throttle = Duration(milliseconds: 1200);

  /// 上一次真正出声的时刻；null = 还没响过。
  DateTime? _lastPlayedAt;

  @override
  Future<void> play(NotificationSound sound, {String? customFilePath}) async {
    try {
      switch (sound) {
        case NotificationSound.off:
          return;
        case NotificationSound.inkframe:
          if (!_admit()) return;
          await _clips.playAsset(kNotificationChimeAsset);
        case NotificationSound.system:
          if (!_admit()) return;
          await _systemSound.play();
        case NotificationSound.custom:
          final String? path = customFilePath;
          if (path == null || !await File(path).exists()) return;
          // 存在性检查是异步的：节流判定放在它之后、出声之前，中间没有 await，
          // 两个并发请求不会都挤过窗口。
          if (!_admit()) return;
          await _clips.playFile(
            path,
            maxDuration: kCustomNotificationSoundMaxPlay,
          );
      }
    } on Object catch (e) {
      // 「绝不抛」契约的最后一道闸：缝的实现方失手漏出来的任何东西都停在这里。
      _logger.warn(
        _logModule,
        'notification_sound.play_failed',
        extra: <String, Object?>{'sound': sound.name, 'error': e.toString()},
      );
    }
  }

  /// 节流判定：放行就记下这一刻。
  bool _admit() {
    final DateTime now = _clock.nowUtc();
    final DateTime? last = _lastPlayedAt;
    if (last != null) {
      final Duration since = now.difference(last);
      if (!since.isNegative && since < _throttle) return false;
    }
    _lastPlayedAt = now;
    return true;
  }

  /// 释放底层播放器（main.dart 在容器销毁时调用）。
  Future<void> dispose() => _clips.dispose();
}
