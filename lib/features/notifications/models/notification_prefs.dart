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

/// 自定义提示音放在数据目录 config/ 下的这个子目录里。
const String kCustomNotificationSoundDir = 'sounds';

/// 自定义提示音文件的大小上限（导入时校验）。
const int kCustomNotificationSoundMaxBytes = 2 * 1024 * 1024;

/// 自定义提示音最多播多久，超过就停。
const Duration kCustomNotificationSoundMaxPlay = Duration(seconds: 4);

/// 自定义提示音接受的扩展名（文件选择框的过滤器）。
const List<String> kCustomNotificationSoundExtensions = <String>[
  'wav',
  'mp3',
  'ogg',
  'm4a',
];

NotificationSound notificationSoundFromPref(String value) =>
    NotificationSound.values.firstWhere(
      (s) => s.name == value,
      orElse: () => NotificationSound.inkframe,
    );

ToastDwell toastDwellFromPref(String value) => ToastDwell.values.firstWhere(
      (d) => d.name == value,
      orElse: () => ToastDwell.standard,
    );
