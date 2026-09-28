// 画廊标签体（T9 真身）。
//
// 读 activeProjectProvider，为 null 时出空态；非 null 时把两个必填参透传给
// GalleryScreen——GalleryScreen 的构造签名【不动】（6 个 pump 点 + 1 个 golden
// 用例直接 pump 它）。
//
// 另一半职责：脏刷新。isVisible 由 false → true 且 galleryDirtyProvider 为真
// 时，invalidate 一次 galleryGraphProvider(projectId) 再清脏。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../gallery/providers/gallery_controller.dart';
import '../../../gallery/providers/gallery_graph_provider.dart';
import '../../../gallery/widgets/gallery_screen.dart';
import '../../models/shell_state.dart';
import '../../providers/active_project.dart';
import '../../providers/gallery_dirty.dart';
import '../../providers/shell_controller.dart';
import '../shell_empty_state.dart';

class GalleryTab extends ConsumerStatefulWidget {
  const GalleryTab({super.key, required this.isVisible});

  /// 本标签此刻是否可见。
  ///
  /// 【T9 已接上】false → true 的那一跳是脏刷新的唯一触发沿：后台生成完成
  /// 时不刷（用户看不见，刷了只是白费一次聚合查询），等用户真的切回画廊再刷。
  ///
  /// 【F5：这不是实时刷新，是 by design】用户正盯着画廊时后台生成完成，画廊
  /// 原地不动——得切走再切回才更新。要做成实时的话，就是"用户滚到一半、列表
  /// 在脚底下变长"，那是另一种体验决策，不在 T9 范围内。
  final bool isVisible;

  @override
  ConsumerState<GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends ConsumerState<GalleryTab> {
  @override
  void didUpdateWidget(covariant GalleryTab old) {
    super.didUpdateWidget(old);
    // 只认上升沿：可见→可见的重建（换项目、主题变化…）不该触发刷新。
    if (old.isVisible || !widget.isVisible) return;
    _refreshIfDirty();
  }

  /// 【绝不在 build/didUpdateWidget 里同步 invalidate】didUpdateWidget 跑在
  /// build 阶段内，同步改 provider 图会被 Riverpod 断言掉（"Tried to modify a
  /// provider while the widget tree was building"）。一律推到帧后。
  void _refreshIfDirty() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 可见性【只在 didUpdateWidget 那一处判断】——这里再判一次会让
      // "不可见就别刷" 这条语义有两个来源，变异任何一处都打不红测试。
      if (!mounted) return;
      if (!ref.read(galleryDirtyProvider)) return;
      final ProjectRef? project = ref.read(activeProjectProvider);
      if (project != null) {
        // 图是唯一读库入口；controller 也显式失效——它可能被测试 / 未来实现替换成不 watch 图的版本。
        ref.invalidate(galleryGraphProvider(project.id));
        ref.invalidate(galleryControllerProvider(project.id));
      }
      // 【F4：project == null 时脏标记被无刷新地丢掉，这是安全的】
      // 没有项目就没有 entry 可 invalidate；而 galleryControllerProvider 是
      // AutoDisposeFamily，用户之后选中任何项目时，那个 entry 本来就是全新
      // 构建的（第一次 build 就会读到最新数据）。留着脏标记只会让下一次切入
      // 画廊白刷一次刚建好的 entry。
      ref.read(galleryDirtyProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // watch 而非 read：脏标记 provider 是懒的，没有订阅者就根本不会被实例化，
    // job 转成功那一刻它的 ref.listen 压根没装上 ⇒ 脏标记永远收不到。
    // 这条 watch 就是它在画廊标签存活期间的订阅者，不是渲染用的。
    ref.watch(galleryDirtyProvider);
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
