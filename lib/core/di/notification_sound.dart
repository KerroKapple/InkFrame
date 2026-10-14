// notificationSoundServiceProvider：通知提示音。
//
// 默认安静（测试里没有 media_kit / 系统音频）；main.dart 覆盖成真正的播放实现。
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/silent_notification_sound_service.dart';
import '../interfaces/notification_sound_service.dart';

final notificationSoundServiceProvider = Provider<NotificationSoundService>(
  (ref) => const SilentNotificationSoundService(),
  name: 'notificationSoundServiceProvider',
);
