// ToastService：应用里「告诉用户发生了什么」的唯一出口——窗口右下角的通知卡。
//
// 契约层，不依赖 Flutter：回调是普通函数，缩略图传绝对路径。实现是
// features/notifications 的 ToastCenter（排队、计时、悬停暂停、去重、历史、提示音），
// 画面由 ToastLayer 画在所有路由之上（对话框开着也看得见）。
//
// 调用方约定：title / body / 按钮文案都已经过 l10n 解析；服务不认识 ARB key。

/// 通知类型：决定图标、停留时长，以及铃铛上的点是不是红的。
enum ToastKind {
  /// 普通提示，停 4 秒。
  info,

  /// 完成，停 4 秒。
  success,

  /// 警告，停 6 秒。
  warning,

  /// 失败：不自动消失，等用户关。
  error,

  /// 进行中：一直显示，直到 [ToastHandle.complete] 或 [ToastHandle.dismiss]。
  progress,

  /// 可撤销的操作，停 8 秒。卡片消失后快捷键仍能撤销——那是调用方的事，与本服务无关。
  undo,
}

/// 卡片上的一个按钮。
class ToastAction {
  const ToastAction(this.label, this.onPressed);

  final String label;
  final void Function() onPressed;
}

/// [ToastService.show] 返回的句柄：进度卡原地更新、原地变成终态，或提前关掉。
///
/// 卡片已经被用户关掉之后再调用任何方法都是安全的空操作。
abstract class ToastHandle {
  /// 只改传了的字段。[progress] 取 0..1；进度未知时一直不传。
  void update({String? title, String? body, double? progress});

  /// 原地变成终态卡并重新计时，不重放进场动画。[chime] 的含义同 [ToastService.show]。
  void complete({
    required ToastKind kind,
    required String title,
    String? body,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
    bool chime = false,
  });

  void dismiss();
}

abstract class ToastService {
  /// 弹一张通知卡。
  ///
  /// - [meta]：一行小字（项目 · 画布 · 时间这类出处）。
  /// - [thumbnailPath]：作品缩略图的绝对路径，有就替代类型图标。
  /// - [primary] / [secondary]：最多两个按钮，主按钮在右。
  /// - [dedupeKey]：同一个 key 只替换原卡、不新增（同一个任务、同一个节点反复保存失败）。
  /// - [chime]：这是一条「后台事件到达」的通知（生成 / 导出 / 下载完成或失败），按设置响一声。
  ///   用户自己刚做的操作（删除、复制、保存）不要响。
  ToastHandle show(
    String title, {
    ToastKind kind = ToastKind.info,
    String? body,
    String? meta,
    String? thumbnailPath,
    ToastAction? primary,
    ToastAction? secondary,
    String? dedupeKey,
    bool chime = false,
  });
}
