// CanvasToolRail：左侧工具条 37px（稿 36 + 1px 右沿），七个 26×26 格。
//
// 接线：
//   选择 = 不在连线模式（点击 = 退出连线模式）
//   平移 = 仓库没有独立的平移工具态（InteractiveViewer 拖空白即平移）→ 禁用
//   连线 = 选中恰好一个节点时可用；点击进入 / 退出连线模式（linkModeController）
//   文本 / 图像 / 视频节点 = addNode（视口中心落点，与 FAB 同源）
//   泳道 = 新建泳道对话框（与 LaneToolbar 同源）
// 图标沿用稿上的 12×12（+1.5 边 = 15）描边方框占位，实现时换项目图标集。
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/link_mode_controller.dart';
import '../util/canvas_snackbars.dart';
import '../util/node_position.dart';
import 'lane_edit_dialog.dart';

class CanvasToolRail extends ConsumerWidget {
  const CanvasToolRail({super.key, required this.canvasId});

  final String canvasId;

  /// 稿是 content-box：width 36 + border-right 1。
  static const double width = 37;

  static Key keyOf(String tool) => ValueKey<String>('canvasTool-$tool');

  Offset _pickPosition(WidgetRef ref, CanvasNodeType type) =>
      pickViewportCenteredNodePosition(
        random: Random(),
        transform: ref.read(canvasTransformControllerProvider(canvasId)).value,
        viewportSize: ref.read(canvasViewportSizeProvider(canvasId)),
        nodeSize: defaultNodeSize(type),
      );

  Future<void> _addNode(
    BuildContext context,
    WidgetRef ref,
    CanvasNodeType type,
  ) async {
    final String label = context.l10n.canvasNodeDefaultLabel;
    final String failed = context.l10n.canvasAddNodeFailed;
    try {
      await ref.read(canvasNodesControllerProvider(canvasId).notifier).addNode(
            label: label,
            type: type,
            position: _pickPosition(ref, type),
          );
    } on InkError catch (_) {
      if (context.mounted) showCanvasSnack(context, failed);
    }
  }

  Future<void> _addLane(BuildContext context, WidgetRef ref) async {
    final r = await showLaneEditDialog(context);
    if (r == null || !context.mounted) return;
    final String failed = context.l10n.laneCreateFailed;
    try {
      await ref.read(canvasLanesControllerProvider(canvasId).notifier).createLane(
            label: r.label,
            stylePrompt: r.stylePrompt,
            tintColor: r.tintColor,
          );
    } on InkError catch (_) {
      if (context.mounted) showCanvasSnack(context, failed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.inkColors;
    final l = context.l10n;
    final String? linkSource = ref.watch(linkModeControllerProvider(canvasId));
    final Set<String> selected = ref.watch(canvasSelectionControllerProvider(canvasId));
    final bool linking = linkSource != null;
    final bool canLink = linking || selected.length == 1;

    void toggleLink() {
      final ctrl = ref.read(linkModeControllerProvider(canvasId).notifier);
      if (linking) {
        ctrl.cancel();
      } else {
        ctrl.start(selected.first);
      }
    }

    final List<_Tool> tools = <_Tool>[
      _Tool('select', l.canvasToolSelect, _Shape.square1, active: !linking,
          onTap: linking ? () => ref.read(linkModeControllerProvider(canvasId).notifier).cancel() : null),
      _Tool('pan', l.canvasToolPan, _Shape.circle, onTap: null),
      _Tool('link', l.canvasToolLink, _Shape.pill, active: linking, onTap: canLink ? toggleLink : null),
      _Tool('text', l.canvasToolTextNode, _Shape.square0,
          onTap: () => _addNode(context, ref, CanvasNodeType.text)),
      _Tool('image', l.canvasToolImageNode, _Shape.square2,
          onTap: () => _addNode(context, ref, CanvasNodeType.image)),
      _Tool('video', l.canvasToolVideoNode, _Shape.square3,
          onTap: () => _addNode(context, ref, CanvasNodeType.video)),
      _Tool('lane', l.canvasToolLane, _Shape.cupBottom, onTap: () => _addLane(context, ref)),
    ];

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: InkSpacing.s6),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border(right: BorderSide(color: c.borderStrong)),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < tools.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: InkSpacing.s2),
            _ToolCell(key: keyOf(tools[i].id), tool: tools[i]),
          ],
        ],
      ),
    );
  }
}

enum _Shape { square1, circle, pill, square0, square2, square3, cupBottom }

class _Tool {
  const _Tool(this.id, this.name, this.shape, {this.active = false, required this.onTap});
  final String id;
  final String name;
  final _Shape shape;
  final bool active;
  final VoidCallback? onTap;
}

class _ToolCell extends StatefulWidget {
  const _ToolCell({super.key, required this.tool});
  final _Tool tool;

  @override
  State<_ToolCell> createState() => _ToolCellState();
}

class _ToolCellState extends State<_ToolCell> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.inkColors;
    final _Tool t = widget.tool;
    final bool enabled = t.onTap != null;
    final Color fg = t.active ? c.onAccent : (enabled ? c.fg3 : c.fg6);
    return Semantics(
      button: true,
      enabled: enabled,
      label: t.name,
      child: Tooltip(
        message: t.name,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: t.onTap,
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.active ? c.accent : (_hover && enabled ? c.surface5 : null),
                borderRadius: BorderRadius.circular(InkRadius.s3),
              ),
              // 稿是 content-box：12×12 + 1.5px 边 ⇒ 15×15。
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  border: Border.all(color: fg, width: 1.5),
                  borderRadius: _radius(t.shape),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static BorderRadius _radius(_Shape s) => switch (s) {
        _Shape.square1 => BorderRadius.circular(InkRadius.s1),
        _Shape.circle => BorderRadius.circular(InkRadius.pill),
        _Shape.pill => const BorderRadius.horizontal(
            left: Radius.circular(InkRadius.s1),
            right: Radius.circular(InkRadius.bentoBtn),
          ),
        _Shape.square0 => BorderRadius.zero,
        _Shape.square2 => BorderRadius.circular(InkRadius.xs),
        _Shape.square3 => BorderRadius.circular(InkRadius.s3),
        _Shape.cupBottom => const BorderRadius.vertical(
            bottom: Radius.circular(InkRadius.bentoBtn),
          ),
      };
}
