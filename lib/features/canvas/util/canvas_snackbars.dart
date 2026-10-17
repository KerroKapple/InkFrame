// 画布内提示（从 canvas_view 抽出，供画布各处 + 快捷键删除路径共用）。
//
// 走全应用唯一的通知出口 toastServiceProvider（窗口右下角的通知卡），不再自己往
// ScaffoldMessenger 塞 SnackBar。函数名沿用旧名，画布里的调用点不用跟着改。
// 拿 container 用 listen: false：这是一次性的副作用，不该让调用方订阅任何东西。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../notifications/providers/toast_service_provider.dart';

/// 画布内一句话提示。画布里报的几乎都是失败（建 / 删 / 挪 / 改没成），所以默认
/// [ToastKind.error]——失败卡不自动消失，等用户关。不是失败的（「已删除」「已连线」）
/// 由调用方显式传 [kind]。
void showCanvasSnack(
  BuildContext context,
  String text, {
  ToastKind kind = ToastKind.error,
}) {
  _toastsOf(context).show(text, kind: kind);
}

/// 删除防误伤（PL-4a）：弹一张可撤销卡，主按钮「撤销」触发 [onUndo] 复原。
///
/// 撤销卡停 8 秒（ToastKind.undo 的契约）；这段时间里不点，卡片自行收起，软删生效。
/// 画布没有撤销快捷键——卡片收起之后就撤不回了。
///
/// 这里按 context 现取通知服务与「撤销」文案；调用点在 await 之后、context 可能已失效的，改用 [showUndoToast]。
void showCanvasUndoSnack(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  showUndoToast(
    _toastsOf(context),
    message: message,
    undoLabel: context.l10n.commonUndo,
    onUndo: onUndo,
  );
}

/// 撤销卡的唯一拼法（[showCanvasUndoSnack] 也转调这里）：undo 卡 + 主按钮 [undoLabel] 触发 [onUndo]。
///
/// 不碰 context：舞台上那几层（删边钮、拖卡片换道）在 await 写库期间就可能被拆掉，
/// 调用方在 await 之前取好 [toasts] 与文案，写库回来再调本函数。
void showUndoToast(
  ToastService toasts, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  toasts.show(
    message,
    kind: ToastKind.undo,
    primary: ToastAction(undoLabel, onUndo),
  );
}

ToastService _toastsOf(BuildContext context) =>
    ProviderScope.containerOf(context, listen: false).read(toastServiceProvider);
