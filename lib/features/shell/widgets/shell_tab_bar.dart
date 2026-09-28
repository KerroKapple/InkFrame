// ShellTabBar：标签条的接线层——把 ShellState 翻译成 InkShellTabBar 的纯数据。
//
// 呈现全在 lib/theme/components/ink_shell_tab_bar.dart（它不认识 ShellTab，
// 见那边的头注与 test/quality/no_reverse_layer_import_test.dart）。本层只管三件
// 事：谁是当前标签、每格叫什么、点了去哪。另外两件（Workspace v2 稿）：
// - after = 面包屑（标签 › 竖线 › 面包屑）
// - actions = 画布标签且有画布时的三个按钮：导入脚本（对话框）/ 序列预览（= 序列标签）/
//   导出视频（= 导出标签，主按钮）。序列与导出在本仓库已升格为标签，按钮只是稿上的快捷入口。
//
// 【标签条绝不进 chrome 的槽位】整条 InkWindowChrome 包在 DragToMoveArea 里，
// 其 onDoubleTap 让其中任何单击等满 kDoubleTapTimeout(300ms)。标签是全应用最高
// 频交互，300ms 延迟是真 UX 回归，还会给每个外壳测试加固定 400ms 税。
// 判据留在这里：**若哪天 test/_harness/shell_app.dart 的 tapShellTab() 必须补
// pump(400ms) 才稳，说明有人把标签条挪进了 chrome，回退。**
//
// 【顺序】由 ShellTab.values 决定——声明序 == 标签条渲染序 == 保活宿主 children
// 序，三者由 shell_tab_order_test.dart 钉死。
//
// 【keyOf 保持 public】测试靠它定位 chip；_labelOf / _iconOf 只有本文件用，收成私有。
//
// 【Key 是跨层契约】ValueKey('shellTab-<name>') 在这里构造、由 theme 层原样落到
// chip 上。改这个取值会让 tapShellTab() 与整个 shell_tab_bar_test.dart 全体
// churn，不要"顺手规范化"。
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/components/ink_shell_tab_bar.dart';
import '../../../theme/components/ws_primitives.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_transform_controller.dart';
import '../../canvas/util/node_position.dart';
import '../../gallery/models/gallery_item.dart';
import '../../gallery/providers/gallery_view.dart';
import '../../gallery/widgets/gallery_actions.dart';
import '../../../core/di/database_restore.dart';
import '../../../core/di/project_archive.dart';
import '../../storyboard/widgets/script_import_dialog.dart';
import '../../studio/project_import_flow.dart';
import '../../studio/providers/project_export_busy.dart';
import '../../studio/studio_home_screen.dart' show showStudioNewProjectDialog;
import '../models/shell_state.dart';
import '../providers/shell_controller.dart';
import 'shell_breadcrumb.dart';

class ShellTabBar extends ConsumerWidget {
  const ShellTabBar({super.key});

  static String _labelOf(AppLocalizations l, ShellTab tab) => switch (tab) {
        ShellTab.studio => l.shellTabStudio,
        ShellTab.canvas => l.shellTabCanvas,
        ShellTab.sequence => l.shellTabSequence,
        ShellTab.gallery => l.shellTabGallery,
        ShellTab.export => l.shellTabExport,
      };

  static IconData _iconOf(ShellTab tab) => switch (tab) {
        ShellTab.studio => Icons.home_outlined,
        ShellTab.canvas => Icons.account_tree_outlined,
        ShellTab.sequence => Icons.view_timeline_outlined,
        ShellTab.gallery => Icons.collections_outlined,
        ShellTab.export => Icons.movie_creation_outlined,
      };

  static Key keyOf(ShellTab tab) => ValueKey<String>('shellTab-${tab.name}');

  static const Key importScriptKey = Key('shellAction-importScript');
  static const Key sequencePreviewKey = Key('shellAction-sequencePreview');
  static const Key exportVideoKey = Key('shellAction-exportVideo');
  static const Key importPackageKey = Key('shellAction-importPackage');
  static const Key newProjectKey = Key('shellAction-newProject');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ShellState s = ref.watch(shellControllerProvider);
    final AppLocalizations l = context.l10n;
    final ShellNavigator nav = ref.read(shellControllerProvider.notifier);
    final String? canvasId = s.canvasId;
    final bool showActions = s.tab == ShellTab.canvas && canvasId != null;
    final ProjectRef? project = s.project;
    if (s.tab == ShellTab.studio) {
      // 稿：Studio 标签无面包屑；右侧「导入项目包」（次级）+「新建项目」（主）。
      final bool importBusy = ref.watch(projectImportBusyProvider) ||
          ref.watch(databaseRestoreBusyProvider) ||
          ref.watch(projectExportBusyProvider);
      return InkShellTabBar(
        actions: <Widget>[
          _Action(
            key: importPackageKey,
            label: l.studioImportPackage,
            onTap: importBusy ? () {} : () => runProjectImportFlow(context, ref),
            child: Opacity(opacity: importBusy ? 0.5 : 1, child: WsSecondaryButton(l.studioImportPackage)),
          ),
          _Action(
            key: newProjectKey,
            label: l.studioNewProject,
            onTap: () => showStudioNewProjectDialog(context, ref),
            child: WsPrimaryButton(l.studioNewProject, bordered: false),
          ),
        ],
        items: _items(l, s, nav),
      );
    }
    if (s.tab == ShellTab.gallery && project != null) {
      return InkShellTabBar(
        after: const ShellBreadcrumb(),
        actions: <Widget>[_GallerySaveAsCharacter(project: project)],
        items: _items(l, s, nav),
      );
    }
    return InkShellTabBar(
      after: const ShellBreadcrumb(),
      actions: !showActions
          ? const <Widget>[]
          : <Widget>[
              _Action(
                key: importScriptKey,
                label: l.shellActionImportScript,
                onTap: () => showScriptImportDialog(
                  context,
                  canvasId: canvasId,
                  // 整条链从视口中心起铺（与 FAB 同源）。
                  origin: pickViewportCenteredNodePosition(
                    random: Random(),
                    transform: ref.read(canvasTransformControllerProvider(canvasId)).value,
                    viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
                    nodeSize: defaultNodeSize(CanvasNodeType.shot),
                  ),
                ),
                child: WsSecondaryButton(l.shellActionImportScript),
              ),
              _Action(
                key: sequencePreviewKey,
                label: l.shellActionSequencePreview,
                onTap: () => nav.goTab(ShellTab.sequence),
                child: WsSecondaryButton(l.shellActionSequencePreview),
              ),
              _Action(
                key: exportVideoKey,
                label: l.shellActionExportVideo,
                onTap: () => nav.goTab(ShellTab.export),
                child: WsPrimaryButton(l.shellActionExportVideo),
              ),
            ],
      items: _items(l, s, nav),
    );
  }

  static List<InkShellTabBarItem> _items(AppLocalizations l, ShellState s, ShellNavigator nav) =>
      <InkShellTabBarItem>[
        for (final ShellTab t in ShellTab.values)
          InkShellTabBarItem(
            key: keyOf(t),
            label: _labelOf(l, t),
            icon: _iconOf(t),
            selected: t == s.tab,
            onTap: () => nav.goTab(t),
          ),
      ];
}

/// 画廊标签的「存为角色」：作用于选中集的锚点，且锚点得是图片（GA-4 只收图片）。
/// 稿上旁边的「已选 N · 发送到画布」没有后端，不画。
class _GallerySaveAsCharacter extends ConsumerStatefulWidget {
  const _GallerySaveAsCharacter({required this.project});
  final ProjectRef project;

  static const Key key_ = Key('shellAction-gallerySaveAsCharacter');

  @override
  ConsumerState<_GallerySaveAsCharacter> createState() => _GallerySaveAsCharacterState();
}

class _GallerySaveAsCharacterState extends ConsumerState<_GallerySaveAsCharacter> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final GalleryItem? anchor = ref.watch(galleryAnchorItemProvider(widget.project.id));
    final bool enabled = !_busy && anchor != null && anchor.kind == GalleryItemKind.image;
    return Semantics(
      button: true,
      enabled: enabled,
      label: l.gallerySaveAsCharacter,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          key: _GallerySaveAsCharacter.key_,
          behavior: HitTestBehavior.opaque,
          onTap: !enabled
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await gallerySaveAsCharacter(context, ref, projectId: widget.project.id, item: anchor);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Opacity(opacity: enabled ? 1 : 0.5, child: WsSecondaryButton(l.gallerySaveAsCharacter)),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({super.key, required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: child),
      ),
    );
  }
}
