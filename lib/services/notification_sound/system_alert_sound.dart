// SystemAlertSound：「系统提示音」这一档的出声缝——播用户在系统里选的那个声音。
//
// NotificationSoundPlayer 只认这个抽象；生产实现 PlatformSystemAlertSound 在 main.dart 装配。
//
// - Windows：winmm 的 PlaySoundW("Notification.Default", SND_ALIAS | SND_ASYNC | SND_NODEFAULT)，
//   即「声音」控制面板里「通知」那一项——用户换的声音、设成「无」都跟着走。
//   SND_NODEFAULT：这一项没设声音时就不响，不退回系统默认的「叮」。
//   SND_ASYNC：立即返回，不卡 UI 线程；PlaySound 异步播放时自己复制一份名字，
//   所以调用一返回就可以释放那段 UTF-16。
// - macOS：SystemSound.play(SystemSoundType.alert)，引擎侧就是 NSBeep()——用户在
//   「声音 › 提醒音」里选的那个，音量跟「提醒音量」走。
// - 其它平台：没有对应的「用户选的提示音」，不出声。
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException, SystemSound, SystemSoundType;

import '../../core/logging/logger_service.dart';

abstract class SystemAlertSound {
  /// 播一次系统提示音。失败只记日志、绝不抛。
  Future<void> play();
}

typedef _PlaySoundNative = Int32 Function(
  Pointer<Utf16> pszSound,
  Pointer<Void> hmod,
  Uint32 fdwSound,
);
typedef _PlaySoundDart = int Function(
  Pointer<Utf16> pszSound,
  Pointer<Void> hmod,
  int fdwSound,
);

class PlatformSystemAlertSound implements SystemAlertSound {
  PlatformSystemAlertSound({required LoggerService logger}) : _logger = logger;

  final LoggerService _logger;

  static const String _logModule = 'notifications.sound';

  /// 注册表 HKCU\AppEvents\Schemes\Apps\.Default 下「通知」事件的别名。
  static const String _windowsNotificationAlias = 'Notification.Default';

  // mmsystem.h 的 PlaySound 标志位。
  static const int _sndAsync = 0x0001;
  static const int _sndNoDefault = 0x0002;
  static const int _sndAlias = 0x00010000;

  /// 第一次播放时才打开 winmm.dll、查 PlaySoundW，之后复用。
  _PlaySoundDart? _playSound;

  @override
  Future<void> play() async {
    if (Platform.isWindows) {
      _playWindows();
    } else if (Platform.isMacOS) {
      await _playMacOS();
    }
  }

  void _playWindows() {
    final Pointer<Utf16> alias =
        _windowsNotificationAlias.toNativeUtf16(allocator: calloc);
    try {
      final _PlaySoundDart playSound = _playSound ??= DynamicLibrary.open(
        'winmm.dll',
      ).lookupFunction<_PlaySoundNative, _PlaySoundDart>('PlaySoundW');
      final int ok = playSound(
        alias,
        nullptr,
        _sndAlias | _sndAsync | _sndNoDefault,
      );
      if (ok == 0) {
        // 「通知」一项被设成「无」时也会走到这里——那是用户的选择，不算故障，记 info。
        _logger.info(_logModule, 'notification_sound.system_not_played');
      }
    } on ArgumentError catch (e) {
      // DynamicLibrary.open / lookupFunction 失败都抛 ArgumentError（winmm.dll 打不开、
      // 找不到 PlaySoundW）。
      _logger.warn(
        _logModule,
        'notification_sound.system_unavailable',
        extra: <String, Object?>{'error': e.toString()},
      );
    } finally {
      calloc.free(alias);
    }
  }

  Future<void> _playMacOS() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on PlatformException catch (e) {
      _logger.warn(
        _logModule,
        'notification_sound.system_failed',
        extra: <String, Object?>{'code': e.code},
      );
    } on MissingPluginException catch (e) {
      _logger.warn(
        _logModule,
        'notification_sound.system_failed',
        extra: <String, Object?>{'error': e.toString()},
      );
    }
  }
}
