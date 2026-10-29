// 画布内提示（从 canvas_view 抽出，供画布各处 + 快捷键删除路径共用）。
//
// 走全应用唯一的通知出口 toastServiceProvider（窗口右下角的通知卡），不再自己往
// ScaffoldMessenger 塞 SnackBar。函数名沿用旧名，画布里的调用点不用跟着改。
// 拿 container 用 listen: false：这是一次性的副作用，不该让调用方订阅任何东西。
//
// 撤销卡两种：
//   - 按步（[showCanvasUndoSnackWith]，context 版 [showCanvasUndoSnack] 给 canvasId + stepId）：卡背后的操作
//     已登记进画布撤销栈，卡片只是提醒、栈才是本体——卡上「撤销」只撤卡上这一步（undoSpecific），卡 8 秒收起后
//     Ctrl Z / ⌘Z 照样撤；这一步离开栈（被撤、作废、关画布丢栈）时卡跟着收起（bindCard）。
//   - 回调（[showUndoToast]，context 版只给 onUndo）：不进栈，卡收起之后就撤不回了。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../providers/canvas_history_controller.dart';
import 'canvas_history_actions.dart';

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

/// 删除防误伤（PL-4a）：弹一张可撤销卡。撤销卡停 8 秒（ToastKind.undo 的契约），不点就自行收起。
///
/// 两种用法二选一：
/// - 给 [canvasId] + [stepId]：卡背后的操作已经 record 进这张画布的撤销栈，按步出卡并绑到那一步
///   （见 [showCanvasUndoSnackWith]）——卡片收起之后 Ctrl Z / ⌘Z 仍能撤。
/// - 只给 [onUndo]：回调卡、不进栈（转调 [showUndoToast]）；卡片收起之后就撤不回了。
///
/// 这里按 context 现取容器与文案；调用点在 await 之后、context 可能已失效的，在 await 之前取好容器与文案，
/// 改用 [showCanvasUndoSnackWith] / [showUndoToast]。
void showCanvasUndoSnack(
  BuildContext context, {
  required String message,
  String? canvasId,
  String? stepId,
  VoidCallback? onUndo,
}) {
  assert(
    (canvasId != null && stepId != null && onUndo == null) ||
        (canvasId == null && stepId == null && onUndo != null),
    'showCanvasUndoSnack: pass either canvasId + stepId, or onUndo alone',
  );
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final AppLocalizations l = context.l10n;
  if (canvasId != null && stepId != null) {
    showCanvasUndoSnackWith(
      container,
      l,
      message: message,
      canvasId: canvasId,
      stepId: stepId,
    );
    return;
  }
  final VoidCallback? callback = onUndo;
  if (callback == null) return;
  showUndoToast(
    container.read(toastServiceProvider),
    message: message,
    undoLabel: l.commonUndo,
    onUndo: callback,
  );
}

/// 按步出撤销卡（不碰 context）：主按钮「撤销」= 按步撤销 [stepId]（util/canvas_history_actions.dart 的
/// runCanvasUndoStep：在栈顶等同 Ctrl Z，在栈中间只撤这一步、从栈里抽掉），撤销后的选中 / 平移 / 胶囊 /
/// 失败卡与 Ctrl Z 同一套；随后把卡绑到这一步上，这一步离开栈时卡跟着收起，关了画布再点也什么都不做。
///
/// [container] 与 [l] 由调用方在 await 之前取好：调用点（删除钮、拖动换道的卡片插槽、检查器入边行）写库回来时
/// 往往已经卸载。
void showCanvasUndoSnackWith(
  ProviderContainer container,
  AppLocalizations l, {
  required String message,
  required String canvasId,
  required String stepId,
}) {
  final ToastHandle handle = container.read(toastServiceProvider).show(
        message,
        kind: ToastKind.undo,
        primary: ToastAction(
          l.commonUndo,
          () => unawaited(
            runCanvasUndoStep(
              container.read,
              canvasId: canvasId,
              stepId: stepId,
              l: l,
              isMac: defaultTargetPlatform == TargetPlatform.macOS,
            ),
          ),
        ),
      );
  container
      .read(canvasHistoryControllerProvider(canvasId).notifier)
      .bindCard(stepId, handle);
}

/// 回调撤销卡的唯一拼法（[showCanvasUndoSnack] 的 onUndo 用法也转调这里）：undo 卡 + 主按钮 [undoLabel]
/// 触发 [onUndo]。不进撤销栈。
///
/// 不碰 context：调用方在 await 之前取好 [toasts] 与文案，写库回来再调本函数。
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
