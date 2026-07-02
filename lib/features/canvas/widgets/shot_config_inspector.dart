// ShotConfigInspector：单选 shot 节点时的最简参数面板（分镜骨架）。
//
// shot 是真实节点类型（image/text/video/shot），此前无编辑面板。本面板先提供分镜
// 备注（type_config.shot_notes），作为后续 storyboard→shot→序列 流水线的编辑起点。
// 持久化经 InspectorSubmitController.saveConfig（防抖），与 image/video 面板同构。
// 「用本镜备注生成图像」：以 shot_notes 为 prompt 在旁侧新建 image config 节点，
// 并挂一条 narrative 边（shot→image），复用现有生成链路（M3 §1 首切片）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/inspector_submit_controller.dart';

class ShotConfigInspector extends ConsumerStatefulWidget {
  const ShotConfigInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  ConsumerState<ShotConfigInspector> createState() =>
      _ShotConfigInspectorState();
}

class _ShotConfigInspectorState extends ConsumerState<ShotConfigInspector> {
  final TextEditingController _notesCtrl = TextEditingController();
  Timer? _debounce;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final n = widget.node.typeConfig['shot_notes'];
    if (n is String) _notesCtrl.text = n;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // 备注是否为空 → 生成按钮可用性
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
          .saveConfig(<String, Object?>{'shot_notes': value});
    });
  }

  bool get _canGenerate =>
      !_busy && _notesCtrl.text.trim().isNotEmpty && widget.node.canvasId != null;

  /// 以当前备注为 prompt 新建 image config 节点（shot 右侧偏移一格），
  /// 并加 narrative 边 shot→image。notifier 与文案在 await 前取好：面板中途
  /// 销毁也保证「节点+边」成对落地。失败仅 snackbar，节点/连线失败分开报。
  Future<void> _generateImageFromNotes() async {
    final canvasId = widget.node.canvasId;
    final notes = _notesCtrl.text.trim();
    if (canvasId == null || notes.isEmpty || _busy) return;
    final label = context.l10n.canvasNodeDefaultLabel;
    final addFailedMsg = context.l10n.canvasAddNodeFailed;
    final linkFailedMsg = context.l10n.inspectorShotLinkFailed;
    final position = widget.node.position +
        Offset(widget.node.size.width + InkSpacing.xxl, 0);
    final nodes = ref.read(canvasNodesControllerProvider(canvasId).notifier);
    final edges = ref.read(canvasEdgesControllerProvider(canvasId).notifier);
    setState(() => _busy = true);
    try {
      final CanvasNode created;
      try {
        created = await nodes.addNode(
          label: label,
          type: CanvasNodeType.image,
          position: position,
          typeConfig: <String, Object?>{'prompt': notes},
        );
      } on InkError catch (_) {
        _showSnack(addFailedMsg);
        return;
      }
      try {
        await edges.addEdge(
          sourceNodeId: widget.node.id,
          targetNodeId: created.id,
          edgeType: EdgeType.narrative,
        );
      } on InkError catch (_) {
        _showSnack(linkFailedMsg);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(InkSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(left: BorderSide(color: colors.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.inspectorShotTitle,
              style: typo.title.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.lg),
            Text(
              context.l10n.inspectorShotNotesLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            InkInput(
              controller: _notesCtrl,
              hintText: context.l10n.inspectorShotNotesHint,
              minLines: 4,
              maxLines: 10,
              onChanged: _onChanged,
            ),
            const SizedBox(height: InkSpacing.lg),
            FilledButton.icon(
              onPressed: _canGenerate ? _generateImageFromNotes : null,
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                size: InkSpacing.md,
              ),
              label: Text(context.l10n.inspectorShotGenerateImage),
            ),
          ],
        ),
      ),
    );
  }
}
