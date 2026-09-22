// 外壳面包屑：studio › project › canvas（Workspace v2 稿：标签栏竖线右侧，
// 各段 fg6 › fg6 / 项目 fg3 / 画布 fg1，段间 4px）。
//
// 【必须条件 watch】——canvasId == null 时只显示项目名、**不碰 canvasRepository**；
// 非 null 时才 watch currentCanvasNameProvider。否则每个 boot 级 widget test 都得
// 额外密封画布仓储，密封面被凭空炸开一圈（app_toast_messenger_test 就没封它）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../canvas/providers/current_canvas_name.dart';
import '../../studio/controllers/studio_state.dart';
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';

class ShellBreadcrumb extends ConsumerWidget {
  const ShellBreadcrumb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final String studioName =
        ref.watch(currentStudioProvider) ?? l.studioDefaultName;
    final ProjectRef? project =
        ref.watch(shellControllerProvider.select((ShellState s) => s.project));
    final String? canvasId =
        ref.watch(shellControllerProvider.select((ShellState s) => s.canvasId));

    final TextStyle root = typo.body.copyWith(color: colors.fg6);
    final TextStyle mid = typo.body.copyWith(color: colors.fg3);
    final TextStyle leaf = typo.body.copyWith(color: colors.fg1);
    final TextStyle chev = typo.body.copyWith(color: colors.fg6);

    final bool hasCanvas = canvasId != null;
    final List<Widget> parts = <Widget>[
      Text(studioName, style: root),
      _chev(chev),
      Text(project?.name ?? l.shellBreadcrumbNoProject,
          style: hasCanvas ? mid : leaf),
    ];
    if (hasCanvas) {
      final String canvasName = ref.watch(currentCanvasNameProvider).valueOrNull ??
          l.canvasDefaultName;
      parts
        ..add(_chev(chev))
        ..add(Text(canvasName, style: leaf));
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
  }

  Widget _chev(TextStyle s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.xs),
        child: Text('›', style: s),
      );
}
