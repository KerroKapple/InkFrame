// 画布内 snackbar 提示（从 canvas_view 抽出，供画布各处 + 快捷键删除路径共用）。

import 'package:flutter/material.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';

const _kSnackBarDuration = Duration(seconds: 2);

// 删除防误伤（PL-4a）：Deleted · [Undo] 的驻留时长即撤销窗口（~5s）。
const _kUndoSnackBarDuration = Duration(seconds: 5);

/// 画布内轻量提示条。
void showCanvasSnack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text), duration: _kSnackBarDuration));
}

/// 删除防误伤（PL-4a）：弹一条带 Undo 动作的 snackbar，[onUndo] 在窗口内点击时
/// 触发复原；窗口内不点 → snackbar 自行消失，软删生效。
void showCanvasUndoSnack(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final colors = context.inkColors;
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: _kUndoSnackBarDuration,
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          textColor: colors.accent,
          onPressed: onUndo,
        ),
      ),
    );
}
