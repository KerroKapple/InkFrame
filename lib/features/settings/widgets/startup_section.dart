// StartupSection — 启动行为偏好（T11）。
//
// 目前只有一项：启动时是否恢复上次打开的画布（shellKeepLastCanvas，默认开）。
// 这是「下次启动是否回到上次画布」的唯一真相源——lib 里没有任何其它写点
// 会背着用户清掉会话记录（见 restore_last_session.dart 头注）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_card.dart';
import '../../../theme/tokens.dart';
import '../providers/shell_keep_last_canvas_controller.dart';

class StartupSection extends ConsumerWidget {
  const StartupSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final bool keep = ref.watch(shellKeepLastCanvasControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.shellKeepLastCanvasTitle,
          style: typo.sectionTitle.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.sm),
        InkCard(
          child: Row(
            children: <Widget>[
              Switch(
                value: keep,
                onChanged: ref
                    .read(shellKeepLastCanvasControllerProvider.notifier)
                    .setEnabled,
              ),
              const SizedBox(width: InkSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.shellKeepLastCanvasSubtitle,
                  style: typo.body.copyWith(color: colors.fg2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
