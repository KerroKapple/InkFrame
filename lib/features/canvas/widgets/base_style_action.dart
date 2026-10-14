// 基底风格编辑入口（原 CanvasToolBar 的唯一动作，工具条本身随 Workspace v2 稿撤掉）。
//
// 入口挂在画布底部提示词条的「基础风格」标签上（canvas_prompt_bar.dart）。
// 读 / 写失败都走全应用唯一的通知出口 toastServiceProvider（错误卡，等用户关）。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../core/interfaces/toast_service.dart';
import '../../../l10n/l10n_x.dart';
import '../../notifications/providers/toast_service_provider.dart';
import '../providers/canvas_base_style.dart';
import 'base_style_editor_dialog.dart';

/// 读当前基底风格 → 对话框 → 写回。读失败必须中止（#199 评审 P2-3）：
/// 空预填打开编辑器，用户一保存就把已存前后缀覆盖为空——自由文本域无护栏。
Future<void> openBaseStyleEditor(
  BuildContext context,
  WidgetRef ref,
  String canvasId,
) async {
  // 必须 await 真实加载：provider 是 autoDispose，未被 watch 时 .valueOrNull
  // 为 null，会用空值预填覆盖已存基底风格（数据丢失）。
  ({String prefix, String suffix}) cur;
  try {
    cur = await ref.read(canvasBaseStyleProvider(canvasId).future);
  } on InkError catch (e) {
    if (!context.mounted) return;
    ref
        .read(toastServiceProvider)
        .show(l10nAsyncError(context, e), kind: ToastKind.error);
    return;
  }
  if (!context.mounted) return;
  final r = await showBaseStyleEditorDialog(
    context,
    prefix: cur.prefix,
    suffix: cur.suffix,
  );
  if (!context.mounted) return;
  if (r == null) return;
  try {
    await setBaseStyle(ref, canvasId, prefix: r.prefix, suffix: r.suffix);
  } on InkError catch (_) {
    if (!context.mounted) return;
    ref
        .read(toastServiceProvider)
        .show(context.l10n.baseStyleUpdateFailed, kind: ToastKind.error);
  }
}
