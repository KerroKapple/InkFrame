// 命令面板动作集（PL-1 首版：写死 ≤6 个，全部来自已存在的真实能力）。
//
// 动作按当前路由上下文组装（canvas / gallery / settings / studio）；
// label 经 context.l10n 解析后快照进 CommandAction，执行闭包在面板关闭后
// 由调用方以 (context, ref) 触发，await 之后一律先查 context.mounted。
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/preferences.dart';
import '../../core/errors/ink_error.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/l10n_x.dart';
import '../canvas/models/canvas_edge.dart';
import '../canvas/models/canvas_node.dart';
import '../canvas/providers/canvas_edges_controller.dart';
import '../canvas/providers/canvas_nodes_controller.dart';
import '../canvas/providers/canvas_transform_controller.dart';
import '../canvas/util/node_position.dart';
import '../export/util/export_order.dart';
import '../export/widgets/export_video_dialog.dart';
import '../shell/models/shell_state.dart';
import '../shell/providers/shell_controller.dart';
import '../studio/project_import_flow.dart';

/// 单个可执行命令：图标 + 已本地化 label + 执行闭包。
@immutable
class CommandAction {
  const CommandAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.run,
  });

  final String id;
  final IconData icon;
  final String label;
  final Future<void> Function(BuildContext context, WidgetRef ref) run;
}

/// 组装当前上下文可用的命令（≤6）。
///
/// - canvas 打开：三种新建节点 + 导出视频（有可导出 result 时）+ 返回/设置
/// - gallery：返回 Studio + 设置
/// - settings：返回 Studio
/// - showcase：返回 Studio + 设置
/// - studio 首页：导入项目 + 内置示例 + 设置（零项目空态下项目卡菜单不存在,
///   导入必须能从这里够到——2026-08-31 审计 P0-3）
List<CommandAction> buildCommandActions(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  final s = ref.read(shellControllerProvider);
  // fix round 1（M-4）：overlay 判断提到最前，与 app.dart 的 overlay-first
  // 判序保持一致（R25）——浮层可以盖在画布或画廊之上（openOverlay 刻意保留
  // canvasId/project），若 overlay 判断排在后面，"画布/画廊上开着 Settings
  // 时按 ⌘K" 会拿到画布/画廊动作集而非当前真正可见的 Settings 动作集。
  if (s.overlay != null) {
    return switch (s.overlay!) {
      ShellOverlay.settings => <CommandAction>[_backToStudio(l)],
      ShellOverlay.showcase => <CommandAction>[
          _backToStudio(l),
          _openSettings(l),
        ],
    };
  }
  final canvasId = s.canvasId;
  if (canvasId != null) {
    // 画布打开期间 CanvasScreen 常驻 watch 该 provider，read 即为已加载态。
    final videoNodes = exportableVideoNodes(
      ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
          const <CanvasNode>[],
    );
    final canExport =
        videoNodes.isNotEmpty && videoNodes.first.projectId != null;
    return <CommandAction>[
      CommandAction(
        id: 'addImageNode',
        icon: Icons.add_photo_alternate_outlined,
        label: l.canvasAddImageNode,
        run: (c, r) => _addNode(c, r, canvasId, CanvasNodeType.image),
      ),
      CommandAction(
        id: 'addVideoNode',
        icon: Icons.videocam_outlined,
        label: l.canvasAddVideoNode,
        run: (c, r) => _addNode(c, r, canvasId, CanvasNodeType.video),
      ),
      CommandAction(
        id: 'addShotNode',
        icon: Icons.movie_outlined,
        label: l.canvasAddShotNode,
        run: (c, r) => _addNode(c, r, canvasId, CanvasNodeType.shot),
      ),
      if (canExport)
        CommandAction(
          id: 'exportVideo',
          icon: Icons.file_download_outlined,
          label: l.exportVideoTooltip,
          run: (c, r) async => _openExport(c, r, canvasId),
        ),
      _backToStudio(l),
      _openSettings(l),
    ];
  }
  if (s.tab == ShellTab.gallery && s.project != null) {
    return <CommandAction>[_backToStudio(l), _openSettings(l)];
  }
  // studio：内置示例是全局动作,项目卡菜单在零项目空态下不存在——命令面板
  // 与空态 CTA 一起保证零项目用户也够得到（评审 P1-1）。2026-08-31 审计 P0：
  // 导入项目此前在这里完全够不到，见 studio/project_import_flow.dart。
  return <CommandAction>[
    _importProject(l),
    _openShowcase(l),
    _openSettings(l),
  ];
}

Future<void> _addNode(
  BuildContext context,
  WidgetRef ref,
  String canvasId,
  CanvasNodeType type,
) async {
  final label = context.l10n.canvasNodeDefaultLabel;
  final failedMsg = context.l10n.canvasAddNodeFailed;
  try {
    await ref.read(canvasNodesControllerProvider(canvasId).notifier).addNode(
          label: label,
          type: type,
          // 债150：视口中心落点（视口未上报回退旧固定区随机）。
          position: pickViewportCenteredNodePosition(
            random: Random(),
            transform:
                ref.read(canvasTransformControllerProvider(canvasId)).value,
            viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
            nodeSize: defaultNodeSize(type),
          ),
        );
  } on InkError {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(failedMsg),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

void _openExport(BuildContext context, WidgetRef ref, String canvasId) {
  // EX-1′：与顶栏入口同一条排序路径（narrative 链序）。
  final videoNodes = orderVideoNodesForExport(
    allNodes: ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasNode>[],
    edges: ref.read(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[],
  );
  final projectId = videoNodes.isEmpty ? null : videoNodes.first.projectId;
  if (projectId == null) return; // 面板打开到执行之间节点已变化：静默不弹
  showExportVideoDialog(context, projectId: projectId, videoNodes: videoNodes);
}

CommandAction _backToStudio(AppLocalizations l) => CommandAction(
      id: 'backToStudio',
      icon: Icons.arrow_back,
      label: l.commandBackToStudio,
      run: (context, ref) async {
        ref.read(shellControllerProvider.notifier).goTab(ShellTab.studio);
        // 主动回首页 = 下次启动停留 Studio（fix round 1，R26：T6 之前 lib 里
        // 唯一承载"用户主动回首页"语义的写点就是这行；删掉后这条语义在 lib
        // 里变成静默的洞——T11 若要替换机制应是深思熟虑的决定，不该是继承
        // 一次迁移期间的疏漏，先恢复。fire-and-forget）。
        unawaited(
          ref.read(preferencesServiceProvider).update(
                (p) => p.copyWith(clearLastCanvas: true),
              ),
        );
      },
    );

CommandAction _openShowcase(AppLocalizations l) => CommandAction(
      id: 'openShowcase',
      icon: Icons.photo_library_outlined,
      label: l.showcaseEntryLabel,
      run: (context, ref) async {
        ref
            .read(shellControllerProvider.notifier)
            .openOverlay(ShellOverlay.showcase);
      },
    );

CommandAction _importProject(AppLocalizations l) => CommandAction(
      id: 'importProject',
      icon: Icons.unarchive_outlined,
      label: l.studioImportProject,
      run: (context, ref) => runProjectImportFlow(context, ref),
    );

CommandAction _openSettings(AppLocalizations l) => CommandAction(
      id: 'openSettings',
      icon: Icons.settings_outlined,
      label: l.studioOpenSettings,
      run: (context, ref) async {
        ref
            .read(shellControllerProvider.notifier)
            .openOverlay(ShellOverlay.settings);
      },
    );
