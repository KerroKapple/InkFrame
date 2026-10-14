// SilentNotificationSoundService：什么都不播的实现。
//
// notificationSoundServiceProvider 的默认值——测试环境里没有初始化 media_kit、也没有
// 系统音频，默认安静；main.dart 用真正的播放实现覆盖它。
import '../core/interfaces/notification_sound_service.dart';

class SilentNotificationSoundService implements NotificationSoundService {
  const SilentNotificationSoundService();

  @override
  Future<void> play(NotificationSound sound, {String? customFilePath}) async {}
}
