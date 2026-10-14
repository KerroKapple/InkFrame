// 自定义通知提示音的约束（设置 › 常规 › 通知 › 提示音 › 自定义）。
//
// 放在 core：导入服务（services/file_notification_sound_store.dart）、播放服务
// （services/notification_sound/）和设置页都要用，服务层不该反向依赖 features。

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
