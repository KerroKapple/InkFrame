// NotificationSoundService：通知到达时的提示音（设置 › 常规 › 通知 › 提示音）。
//
// 只在「后台事件到达」时响（生成 / 导出完成或失败），用户自己刚做的操作不响——
// 这个取舍在 ToastService.show 的 chime 参数上做，本服务只管按选择出声。
// 契约层，不依赖 Flutter / media_kit。

/// 提示音的来源。
enum NotificationSound {
  /// InkFrame 自带的提示音（原创合成，tool/sounds 生成，assets/sounds 打包）。
  inkframe,

  /// 系统提示音：Windows 的「通知」声音 / macOS 的提示音，跟随系统设置。
  system,

  /// 用户自选的音频文件（导入时复制进数据目录，只播前几秒）。
  custom,

  /// 不出声。
  off,
}

abstract class NotificationSoundService {
  /// 按选择播一次。失败只记日志、绝不抛——提示音不能打断任何流程。
  ///
  /// [customFilePath] 只在 [NotificationSound.custom] 时使用：数据目录里那份拷贝的绝对路径；
  /// 为 null 或文件不存在时静默不响。
  Future<void> play(NotificationSound sound, {String? customFilePath});
}
