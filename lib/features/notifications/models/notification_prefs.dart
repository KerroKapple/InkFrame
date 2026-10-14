// 通知相关偏好的取值。AppPreferences 里存字符串（与 theme_preference 同一做法），
// 设置页、ToastCenter、提示音都经这里换成枚举，非法值一律退默认。
import '../../../core/interfaces/notification_sound_service.dart';

/// 通知卡停留多久。
enum ToastDwell {
  /// 按类型的默认时长（提示 / 完成 4 秒、警告 6 秒、撤销 8 秒）。
  standard,

  /// 默认时长 × 2。
  long,

  /// 都不自动关闭，等用户关（失败卡本来就不自动关）。
  never,
}

NotificationSound notificationSoundFromPref(String value) =>
    NotificationSound.values.firstWhere(
      (s) => s.name == value,
      orElse: () => NotificationSound.inkframe,
    );

ToastDwell toastDwellFromPref(String value) => ToastDwell.values.firstWhere(
      (d) => d.name == value,
      orElse: () => ToastDwell.standard,
    );
