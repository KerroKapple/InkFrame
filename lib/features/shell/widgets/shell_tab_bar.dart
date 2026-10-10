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
//
// 【右侧动作的可达性】每个动作的点击壳都是 theme 层的 InkActivatable（与标签
// chip 同一件）：可 Tab 聚焦、Enter / Space 激活、聚焦画 accent 环、onTap == null
// 即不可聚焦。#249 只改了 chip，这排动作还是裸 GestureDetector，同一条标签栏上
// 两套语义；2026-10-10 抽出共用件后一起换过来（BOARD 210）。
// 用例：test/features/shell/shell_tab_bar_actions_a11y_test.dart。
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_shell_tab_bar.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../canvas/models/canvas_node.dart';
import '../../canvas/providers/canvas_nodes_controller.dart';
import '../../canvas/providers/canvas_selection_controller.dart';
import '../../canvas/providers/canvas_transform_controller.dart';
import '../../export/delivery_keys.dart';
import '../../export/models/delivery_plan.dart';
import '../../export/open_export_dialog.dart';
import '../../export/providers/delivery_controller.dart';
import '../../export/providers/delivery_plan_provider.dart';
import '../../export/run_delivery.dart';
import '../../export/util/delivery_check_labels.dart';
import '../../export/util/delivery_preflight.dart';
import '../../export/util/delivery_target_labels.dart';
import '../../sequence/models/sequence_lens.dart';
import '../../sequence/providers/sequence_lens_provider.dart';
import '../../sequence/providers/sequence_playhead.dart';
import '../util/tab_availability.dart';
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
import '../providers/active_project.dart';
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
  static const Key locateInCanvasKey = Key('shellAction-locateInCanvas');
  static const Key exportMp4Key = Key('shellAction-exportMp4');

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
            // 在途 ⇒ null（既不可点也不可聚焦）。原先是空闭包：点得动、看着可点、
            // 什么都不发生——接上键盘可达后还会变成"能聚焦、按回车没反应"的假可达。
            onTap: importBusy ? null : () => runProjectImportFlow(context, ref),
            child: Opacity(opacity: importBusy ? 0.5 : 1, child: InkSecondaryButton(l.studioImportPackage)),
          ),
          _Action(
            key: newProjectKey,
            label: l.studioNewProject,
            onTap: () => showStudioNewProjectDialog(context, ref),
            child: InkPrimaryButton(l.studioNewProject, bordered: false),
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
    if (s.tab == ShellTab.sequence && canvasId != null) {
      // Timeline 稿：回到画布定位（次级）| 导出 mp4（次级）| 交付到 {目标}（主，P6）。
      // 导出的可用性 = 有可导出 video result 且外壳有项目上下文（BOARD 210）。
      final SequenceLens lens = ref.watch(sequenceLensProvider(canvasId));
      final int shotIndex = ref.watch(sequencePlayheadProvider(canvasId).select((SequencePlayhead p) => p.index));
      final bool canLocate = shotIndex < lens.shots.length;
      final bool canExport =
          ref.watch(canvasNodesControllerProvider(canvasId).select(canExportVideo)) && project != null;
      // 交付进行中：除「序列」标签本身与主按钮外，整条标签栏锁住（任务书 §3）。
      final bool busy = ref.watch(deliveryBusyProvider);
      return InkShellTabBar(
        after: _lockable(busy, const ShellBreadcrumb()),
        actions: <Widget>[
          _lockable(
            busy,
            _Action(
              key: locateInCanvasKey,
              label: l.shellActionLocateInCanvas,
              onTap: !canLocate
                  ? null
                  : () {
                      // 与 galleryLocateInCanvas 同序：先切标签再选中。
                      nav.goTab(ShellTab.canvas);
                      ref.read(canvasSelectionControllerProvider(canvasId).notifier).select(lens.shots[shotIndex].nodeId);
                    },
              child: Opacity(opacity: canLocate ? 1 : 0.5, child: InkSecondaryButton(l.shellActionLocateInCanvas)),
            ),
          ),
          _lockable(
            busy,
            _Action(
              key: exportMp4Key,
              label: l.shellActionExportMp4,
              onTap: !canExport ? null : () => openExportVideoDialogForCanvas(context, ref, canvasId),
              child: Opacity(opacity: canExport ? 1 : 0.5, child: InkSecondaryButton(l.shellActionExportMp4)),
            ),
          ),
          _DeliverButton(canvasId: canvasId),
        ],
        items: _items(
          l,
          s,
          nav,
          lockedExcept: busy ? ShellTab.sequence : null,
          trailingTab: ShellTab.sequence,
          trailingOn: !busy
              ? null
              : _DeliveryProgressRing(
                  fraction:
                      (ref.watch(deliveryControllerProvider) as DeliveryRunning)
                          .fraction,
                ),
        ),
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
                child: InkSecondaryButton(l.shellActionImportScript),
              ),
              _Action(
                key: sequencePreviewKey,
                label: l.shellActionSequencePreview,
                onTap: () => nav.goTab(ShellTab.sequence),
                child: InkSecondaryButton(l.shellActionSequencePreview),
              ),
              _Action(
                key: exportVideoKey,
                label: l.shellActionExportVideo,
                onTap: () => nav.goTab(ShellTab.export),
                child: InkPrimaryButton(l.shellActionExportVideo),
              ),
            ],
      items: _items(l, s, nav),
    );
  }

  /// [lockedExcept] 非 null ⇒ 除它之外的每一格都**不可点 + 降 0.5**
  /// （P6 交付进行中；onTap 给 null 而不是空闭包）。
  static List<InkShellTabBarItem> _items(
    AppLocalizations l,
    ShellState s,
    ShellNavigator nav, {
    ShellTab? lockedExcept,
    Widget? trailingOn,
    ShellTab? trailingTab,
  }) =>
      <InkShellTabBarItem>[
        for (final ShellTab t in ShellTab.values)
          InkShellTabBarItem(
            key: keyOf(t),
            label: _labelOf(l, t),
            icon: _iconOf(t),
            selected: t == s.tab,
            dimmed: lockedExcept != null && t != lockedExcept,
            onTap: lockedExcept != null && t != lockedExcept
                ? null
                : () => nav.goTab(t),
            trailing: t == trailingTab ? trailingOn : null,
          ),
      ];

  /// 锁住一块：吞掉指针 + **排除焦点** + 降 0.5。标签栏里除「序列」格与主按钮
  /// 之外的东西都走它。
  ///
  /// 【ExcludeFocus 不是多余的】动作接上键盘可达之后，IgnorePointer 只挡指针、
  /// 完全不挡 Tab / 回车——键盘用户能在交付途中按回车把标签切走。「锁住」必须
  /// 两条路一起封。用例：shell_tab_bar_actions_a11y_test.dart「交付锁也锁键盘」。
  static Widget _lockable(bool locked, Widget child) => !locked
      ? child
      : ExcludeFocus(
          child: IgnorePointer(child: Opacity(opacity: 0.5, child: child)),
        );
}

/// 标签栏右侧的交付主按钮（P6 §3）。
///
/// 可用性与 Tooltip 全部来自 deliveryPreflightProvider —— 与面板里那份检查清单
/// **同源**，不另算一遍（否则按钮亮着而清单写着阻断，用户只能靠猜）。
class _DeliverButton extends ConsumerWidget {
  const _DeliverButton({required this.canvasId});

  final String canvasId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = context.l10n;
    final DeliveryPlan plan = ref.watch(deliveryPlanProvider(canvasId));
    final DeliveryPreflight preflight = ref.watch(deliveryPreflightProvider(canvasId));
    final DeliveryState delivery = ref.watch(deliveryControllerProvider);
    final String projectName = ref.watch(activeProjectProvider)?.name ?? '';

    if (delivery is DeliveryRunning) {
      final String label = delivery.total > 0
          ? l.deliveryActionProgress(delivery.done, delivery.total)
          : l.deliveryActionRunning;
      // 交付中：按钮不可点（onTap null，不是空闭包），文案变进度。
      return _Action(
        key: DeliveryKeys.deliverButton,
        label: label,
        onTap: null,
        child: InkPrimaryButton(label, bordered: false),
      );
    }

    final DeliveryCheck? blocking = preflight.firstBlocking;
    final bool enabled = plan.shots.isNotEmpty && blocking == null;
    final String label = l.deliveryActionLabel(
      deliveryTargetLabel(l, plan.settings.target),
    );
    // 禁用时 Tooltip 写第一条阻断原因；没有阻断只是序列空 ⇒ 写「还没有镜」。
    final String tooltip = enabled
        ? label
        : blocking != null
            ? deliveryCheckHeadline(l, blocking, projectName: projectName)
            : l.deliveryActionEmpty;
    return Tooltip(
      message: tooltip,
      child: _Action(
        key: DeliveryKeys.deliverButton,
        label: label,
        onTap: enabled ? () => runDeliveryForCanvas(ref, canvasId) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: InkPrimaryButton(label, bordered: false),
        ),
      ),
    );
  }
}

/// 「序列」标签右侧的 12px 进度环（任务书 §3.4）。分母未知时转圈。
class _DeliveryProgressRing extends StatelessWidget {
  const _DeliveryProgressRing({required this.fraction});

  final double? fraction;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: DeliveryKeys.progressRing,
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          value: fraction,
          color: context.inkColors.accent,
        ),
      );
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
    // 走 _Action（即 InkActivatable）而不是自己再排一遍
    // Semantics + MouseRegion + GestureDetector——那份手抄件正是两套可达性语义的来源。
    return _Action(
      key: _GallerySaveAsCharacter.key_,
      label: l.gallerySaveAsCharacter,
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
      child: Opacity(opacity: enabled ? 1 : 0.5, child: InkSecondaryButton(l.gallerySaveAsCharacter)),
    );
  }
}

/// 标签栏右侧一个动作的点击壳。可达性（聚焦 / Enter / Space / 光标 / Semantics /
/// 焦点环）全部来自 theme 层的 [InkActivatable]——与标签 chip 同一件，一个外壳上
/// 不该有两套可达性语义（BOARD 210）。本件只做"把 label 与 child 递进去"。
class _Action extends StatelessWidget {
  const _Action({super.key, required this.label, required this.onTap, required this.child});
  final String label;

  /// null = 此刻不可点，**并且不可聚焦**。不要传空闭包
  /// （test/quality/no_dead_interactive_test.dart）。
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkActivatable(
        onTap: onTap,
        semanticLabel: label,
        // 子件是稿尺寸的呈现件（InkSecondaryButton / InkPrimaryButton，3px 圆角）。
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) => child,
      );
}
