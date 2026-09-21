// 画廊标签体（T7 薄壳；真身与脏刷新在 T9）。
//
// 读 activeProjectProvider，为 null 时出空态；非 null 时把两个必填参透传给
// GalleryScreen——GalleryScreen 的构造签名【不动】（6 个 pump 点 + 1 个 golden
// 用例直接 pump 它）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../gallery/widgets/gallery_screen.dart';
import '../../models/shell_state.dart';
import '../../providers/active_project.dart';
import '../../providers/shell_controller.dart';
import '../shell_empty_state.dart';

class GalleryTab extends ConsumerWidget {
  const GalleryTab({super.key, required this.isVisible});

  final bool isVisible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProjectRef? project = ref.watch(activeProjectProvider);
    if (project == null) {
      final l = context.l10n;
      return ShellEmptyState(
        icon: Icons.collections_outlined,
        title: l.shellBreadcrumbNoProject,
        ctaLabel: l.shellGoToStudio,
        onCta: () =>
            ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio),
      );
    }
    return GalleryScreen(projectId: project.id, projectName: project.name);
  }
}
