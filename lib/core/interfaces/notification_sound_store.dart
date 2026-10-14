// NotificationSoundStore：自定义提示音文件的存取（设置 › 常规 › 通知 › 提示音 › 自定义）。
//
// 导入 = 把用户选的文件复制进数据目录 `<root>/config/sounds/notification.<ext>`：之后原文件
// 挪走、删掉都不影响；偏好（AppPreferences.notificationSoundFile）里只记文件名，出声前经
// [NotificationSoundStore.resolve] 换成绝对路径。
//
// 失败一律抛 LocalIOError，`extra['reason']` 取下面几个常量之一——设置页只把「太大」
// 单独说，其余都是「这个文件用不了」，原因进日志。
// 契约层，不依赖 Flutter。

/// 导入失败的 `extra['reason']`：文件超过大小上限。
const String kNotificationSoundTooLargeReason = 'notification_sound_too_large';

/// 导入失败的 `extra['reason']`：扩展名不在白名单里。
const String kNotificationSoundUnsupportedReason =
    'notification_sound_unsupported';

/// 导入失败的 `extra['reason']`：空文件。
const String kNotificationSoundEmptyReason = 'notification_sound_empty';

/// 导入失败的 `extra['reason']`：读源文件 / 建目录 / 写入 / 改名失败（含源文件已不在）。
const String kNotificationSoundIoFailedReason = 'notification_sound_io_failed';

abstract class NotificationSoundStore {
  /// 把 [sourcePath] 复制进提示音目录，返回存下来的文件名（不含目录，形如
  /// `notification.mp3`）。
  ///
  /// - 先校验扩展名与大小，不合格就抛，**什么都不写**；
  /// - 写入走 `.partial` → rename，半截文件不会顶替上一份；
  /// - 新文件就位之后才删上一份（扩展名不同的旧文件），任何一步失败都不会落到
  ///   「一份都没有」。
  Future<String> importFile(String sourcePath);

  /// 偏好里记的文件名 → 提示音目录下的绝对路径。null / 空串 / 不是单纯的文件名
  /// （带目录、`..`）→ null。不碰磁盘：文件在不在由出声方自己查。
  String? resolve(String? fileName);
}
