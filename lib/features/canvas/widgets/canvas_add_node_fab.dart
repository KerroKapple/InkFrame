// lib/features/canvas/widgets/canvas_add_node_fab.dart
//
// 画布右下角的"添加节点"FAB。原本住在 app.dart，S2 下沉到 canvas slice 自治。
// 弹 PopupMenu 让用户选 image / video，再写入 canvasNodesControllerProvider。
// SB-2 后菜单多一项「导入脚本」——它不建单个节点，而是开对话框批量建链。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/tokens.dart';
import '../../storyboard/widgets/script_import_dialog.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../util/node_position.dart';

/// FAB 菜单项。不能直接用 [CanvasNodeType]——「导入脚本」不是一种节点类型。
enum _FabAction { imageNode, videoNode, shotNode, importScript }

class CanvasAddNodeFab extends ConsumerWidget {
  const CanvasAddNodeFab({super.key, required this.canvasId, this.random});

  final String canvasId;

  /// 随机源注入口（测试用）；null 时每次取系统熵。
  final Random? random;

  /// 债150：视口中心落点（视口未上报时回退旧固定区随机——测试语义不变）。
  Offset _pickPosition(WidgetRef ref, CanvasNodeType type) =>
      pickViewportCenteredNodePosition(
        random: random ?? Random(),
        transform: ref.read(canvasTransformControllerProvider(canvasId)).value,
        viewportSize: ref.read(canvasViewportSizeProvider),
        nodeSize: defaultNodeSize(type),
      );

  Future<void> _addNode(
    BuildContext context,
    WidgetRef ref,
    CanvasNodeType type,
  ) async {
    try {
      await ref
          .read(canvasNodesControllerProvider(canvasId).notifier)
          .addNode(
            label: context.l10n.canvasNodeDefaultLabel,
            type: type,
            position: _pickPosition(ref, type),
          );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.canvasAddNodeFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final Offset topLeft =
        button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    );

    final selected = await showMenu<_FabAction>(
      context: context,
      position: position,
      items: <PopupMenuEntry<_FabAction>>[
        PopupMenuItem<_FabAction>(
          value: _FabAction.imageNode,
          child: Row(
            children: <Widget>[
              const Icon(Icons.add_photo_alternate_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddImageNode),
            ],
          ),
        ),
        PopupMenuItem<_FabAction>(
          value: _FabAction.videoNode,
          child: Row(
            children: <Widget>[
              const Icon(Icons.videocam_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddVideoNode),
            ],
          ),
        ),
        PopupMenuItem<_FabAction>(
          value: _FabAction.shotNode,
          child: Row(
            children: <Widget>[
              const Icon(Icons.movie_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddShotNode),
            ],
          ),
        ),
        PopupMenuItem<_FabAction>(
          value: _FabAction.importScript,
          child: Row(
            children: <Widget>[
              const Icon(Icons.playlist_add),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddImportScript),
            ],
          ),
        ),
      ],
    );
    if (selected == null || !context.mounted) return;
    switch (selected) {
      case _FabAction.imageNode:
        await _addNode(context, ref, CanvasNodeType.image);
      case _FabAction.videoNode:
        await _addNode(context, ref, CanvasNodeType.video);
      case _FabAction.shotNode:
        await _addNode(context, ref, CanvasNodeType.shot);
      case _FabAction.importScript:
        // 整条链从视口中心起铺——第一镜正对着用户，后续沿 x 轴排开。
        await showScriptImportDialog(
          context,
          canvasId: canvasId,
          origin: _pickPosition(ref, CanvasNodeType.shot),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      tooltip: context.l10n.canvasAddNodeTooltip,
      onPressed: () => _showMenu(context, ref),
      icon: const Icon(Icons.add),
      label: Text(context.l10n.canvasAddNodeTooltip),
    );
  }
}
