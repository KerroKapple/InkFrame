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

  /// 本标签此刻是否可见。
  ///
  /// 【T7 刻意不读】——签名先立住是为了 T9 的"不可见→可见且脏时才 invalidate"
  /// 脏刷新（galleryDirtyProvider）。本步读了也无处可用，与其写个假用法，不如
  /// 在这里写明白：读代码的人不会误以为画廊今天已经有可见性行为。
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
