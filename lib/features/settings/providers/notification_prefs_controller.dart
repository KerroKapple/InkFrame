// NotificationPrefsController：设置 › 常规 › 通知——提示音的选择、自定义文件、通知卡停留时长。
//
// 与 ShellKeepLastCanvasController 同模式：build() 自偏好播种，setter 即时更新内存态并
// fire-and-forget 落盘。偏好里存的是字符串（NotificationSound.name / ToastDwell.name），
// 经 notification_prefs.dart 的解析换成枚举，非法值退默认。
//
// 落盘之后 preferencesServiceProvider.current 同步就是新值——别处（通知卡出声、计时）
// 现读偏好即可，不必监听本控制器。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/notification_sound.dart';
import '../../../core/di/notification_sound_store.dart';
import '../../../core/di/preferences.dart';
import '../../../core/interfaces/notification_sound_service.dart';
import '../../../core/models/app_preferences.dart';
import '../../notifications/models/notification_prefs.dart';

/// 设置页这一节的状态。用记录而不是手写类：三个字段、只读、要按值比较，记录正好。
///
/// `soundFile` 是自定义提示音在 config/sounds/ 下的文件名；null = 还没选过。
typedef NotificationPrefs = ({
  NotificationSound sound,
  String? soundFile,
  ToastDwell dwell,
});

class NotificationPrefsController extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() {
    final AppPreferences p = ref.read(preferencesServiceProvider).current;
    return (
      sound: notificationSoundFromPref(p.notificationSound),
      soundFile: p.notificationSoundFile,
      dwell: toastDwellFromPref(p.toastDwell),
    );
  }

  void setSound(NotificationSound sound) {
    state = (sound: sound, soundFile: state.soundFile, dwell: state.dwell);
    _persist((AppPreferences p) => p.copyWith(notificationSound: sound.name));
  }

  void setDwell(ToastDwell dwell) {
    state = (sound: state.sound, soundFile: state.soundFile, dwell: dwell);
    _persist((AppPreferences p) => p.copyWith(toastDwell: dwell.name));
  }

  /// 按当前选择试听一次。自定义时把偏好里的文件名换成绝对路径；其余选择不碰存取层。
  /// 不抛（NotificationSoundService 的契约）。
  Future<void> preview() {
    final NotificationPrefs s = state;
    final String? customPath = s.sound == NotificationSound.custom
        ? ref.read(notificationSoundStoreProvider).resolve(s.soundFile)
        : null;
    return ref
        .read(notificationSoundServiceProvider)
        .play(s.sound, customFilePath: customPath);
  }

  /// 把用户选的文件导入数据目录，记下文件名，并切到「自定义」。
  ///
  /// 导入失败（太大 / 类型不对 / 读写失败）原样抛 LocalIOError，状态与偏好都不动——
  /// 怎么告诉用户由设置页决定。
  Future<void> importCustomSound(String sourcePath) async {
    final String fileName =
        await ref.read(notificationSoundStoreProvider).importFile(sourcePath);
    state = (
      sound: NotificationSound.custom,
      soundFile: fileName,
      dwell: state.dwell,
    );
    _persist(
      (AppPreferences p) => p.copyWith(
        notificationSound: NotificationSound.custom.name,
        notificationSoundFile: fileName,
      ),
    );
  }

  void _persist(AppPreferences Function(AppPreferences prev) mutate) {
    unawaited(ref.read(preferencesServiceProvider).update(mutate));
  }
}

final notificationPrefsControllerProvider =
    NotifierProvider<NotificationPrefsController, NotificationPrefs>(
  NotificationPrefsController.new,
  name: 'notificationPrefsControllerProvider',
);
