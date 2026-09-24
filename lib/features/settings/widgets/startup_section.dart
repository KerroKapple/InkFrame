// StartupSection — 启动行为偏好（T11），常规页语言下面的一行。
//
// 目前只有一项：启动时是否打开上次的画布（shellKeepLastCanvas，默认开）。
// 这是「下次启动是否回到上次画布」的唯一真相源——lib 里没有任何其它写点
// 会背着用户清掉会话记录（见 restore_last_session.dart 头注）。
//
// 样式照 Screens 稿的分组框行（并发与配额那种）：surface2 底 + control 边 + 圆角 4，
// 行 = 148 标签 | 控件，下面一行 11px 说明。稿上没有画这一行，是按拍板新增的。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../providers/shell_keep_last_canvas_controller.dart';

class StartupSection extends ConsumerWidget {
  const StartupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final t = context.inkTypography;
    final bool keep = ref.watch(shellKeepLastCanvasControllerProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.md, vertical: InkSpacing.s14),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.control),
        borderRadius: BorderRadius.circular(InkRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 标签占满剩余宽度、开关靠右（用户 2026-09-25）：148 的标签列在英文下会折行，不放宽列。
          Row(
            children: <Widget>[
              Expanded(
                child: Text(context.l10n.shellKeepLastCanvasTitle, style: t.body.copyWith(color: c.fg4)),
              ),
              const SizedBox(width: InkSpacing.s12),
              Switch(
                value: keep,
                onChanged: ref.read(shellKeepLastCanvasControllerProvider.notifier).setEnabled,
              ),
            ],
          ),
          const SizedBox(height: InkSpacing.s10),
          Text(
            context.l10n.shellKeepLastCanvasSubtitle,
            style: t.meta.copyWith(color: c.fg6, height: 1.5),
          ),
        ],
      ),
    );
  }
}
