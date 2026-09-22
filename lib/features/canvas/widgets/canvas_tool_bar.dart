// CanvasToolBar：画布标签自己的工具条（44）。
//
// 取代已删除的 CanvasTopChrome：小 logo / 面包屑 / ⌘K 上移到外壳 chrome，
// 「回 Studio」由标签条承担，序列预览与导出视频各自升格为标签（T10 填真身），
// 只剩「基底风格」这一条画布专属动作留在画布 surface 上。
//
// 不在 DragToMoveArea 里 ⇒ 单击一帧落地，测试不再需要 pump(400ms) 越过
// kDoubleTapTimeout。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_tool_bar.dart';
import '../providers/canvas_base_style.dart';
import '../providers/current_canvas_id.dart';
import 'base_style_editor_dialog.dart';

class CanvasToolBar extends ConsumerWidget {
  const CanvasToolBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? canvasId = ref.watch(currentCanvasIdProvider);
    return InkToolBar(
      actions: <Widget>[
        if (canvasId != null) _BaseStyleButton(canvasId: canvasId),
      ],
    );
  }
}

class _BaseStyleButton extends ConsumerWidget {
  const _BaseStyleButton({required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final l = context.l10n;
    return Tooltip(
      message: l.baseStyleEditTooltip,
      child: IconButton(
        icon: Icon(Icons.palette_outlined, size: 18, color: colors.fg2),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        splashRadius: 16,
        onPressed: () => _openEditor(context, ref),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    // 必须 await 真实加载：provider 是 autoDispose，未被 inspector watch 时
    // .valueOrNull 为 null，会用空值预填覆盖已存基底风格（数据丢失）。
    ({String prefix, String suffix}) cur;
    try {
      cur = await ref.read(canvasBaseStyleProvider(canvasId).future);
    } on InkError catch (e) {
      // 读失败必须中止（#199 评审 P2-3）:空预填打开编辑器,用户一保存就把
      // 已存前后缀覆盖为空——自由文本域无护栏,提示后不开门。
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10nAsyncError(context, e))),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.baseStyleUpdateFailed)),
      );
    }
  }
}
