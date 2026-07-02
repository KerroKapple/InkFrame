// lib/features/canvas/widgets/canvas_add_node_fab.dart
//
// 画布右下角的"添加节点"FAB。原本住在 app.dart，S2 下沉到 canvas slice 自治。
// 弹 PopupMenu 让用户选 image / video，再写入 canvasNodesControllerProvider。

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_x.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../util/node_position.dart';

class CanvasAddNodeFab extends ConsumerWidget {
  const CanvasAddNodeFab({super.key, required this.canvasId, this.random});

  final String canvasId;

  /// 随机源注入口（测试用）；null 时每次取系统熵。
  final Random? random;

  Offset _pickPosition() => pickRandomNodePosition(random ?? Random());

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
            position: _pickPosition(),
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

    final selected = await showMenu<CanvasNodeType>(
      context: context,
      position: position,
      items: <PopupMenuEntry<CanvasNodeType>>[
        PopupMenuItem<CanvasNodeType>(
          value: CanvasNodeType.image,
          child: Row(
            children: <Widget>[
              const Icon(Icons.add_photo_alternate_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddImageNode),
            ],
          ),
        ),
        PopupMenuItem<CanvasNodeType>(
          value: CanvasNodeType.video,
          child: Row(
            children: <Widget>[
              const Icon(Icons.videocam_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddVideoNode),
            ],
          ),
        ),
        PopupMenuItem<CanvasNodeType>(
          value: CanvasNodeType.shot,
          child: Row(
            children: <Widget>[
              const Icon(Icons.movie_outlined),
              const SizedBox(width: InkSpacing.sm),
              Text(context.l10n.canvasAddShotNode),
            ],
          ),
        ),
      ],
    );
    if (selected == null || !context.mounted) return;
    await _addNode(context, ref, selected);
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
