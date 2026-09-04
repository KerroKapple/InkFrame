// ShotConfigInspector：单选 shot 节点时的最简参数面板（分镜骨架）。
//
// shot 是真实节点类型（image/text/video/shot），此前无编辑面板。本面板先提供分镜
// 备注（type_config.shot_notes），作为后续 storyboard→shot→序列 流水线的编辑起点。
// 持久化经 InspectorSubmitController.saveDebounced（防抖），与 image/video 面板同构。
// 「用本镜备注生成图像」：以 shot_notes 为 prompt 在旁侧新建 image config 节点，
// 并挂一条 narrative 边（shot→image），复用现有生成链路（M3 §1 首切片）。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/ink_error.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../util/camera_labels.dart';

class ShotConfigInspector extends ConsumerStatefulWidget {
  const ShotConfigInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  ConsumerState<ShotConfigInspector> createState() =>
      _ShotConfigInspectorState();
}

/// 分镜可选时长档（秒）。这里是**导演意图**，不是 provider 能力表——
/// shot 阶段还没选 provider。真正的可用集在 video inspector 按
/// `supportedDurations` 钳制（SB-4 由本节点直达视频时也走那条钳制）。
const List<int> kShotDurationOptions = <int>[3, 5, 10, 15];

class _ShotConfigInspectorState extends ConsumerState<ShotConfigInspector> {
  final TextEditingController _notesCtrl = TextEditingController();
  bool _busy = false;
  int? _durationSec;
  CameraMovement? _camera;

  @override
  void initState() {
    super.initState();
    final tc = widget.node.typeConfig;
    final n = tc['shot_notes'];
    if (n is String) _notesCtrl.text = n;

    // duration_ms 与 video 面板同键同单位（毫秒）——SB-4 直达视频时原样透传。
    // 不在档位表里的历史值不硬塞进下拉（会触发 DropdownButton 的
    // "value 不在 items" 断言），当作未设置。
    final ms = tc['duration_ms'];
    final sec = ms is int ? ms ~/ 1000 : null;
    _durationSec = kShotDurationOptions.contains(sec) ? sec : null;

    _camera = _parseCamera(tc['camera']);
  }

  /// 存的是枚举 name；认不出的值（手改 JSON / 未来枚举回滚）当未设置，不抛。
  CameraMovement? _parseCamera(Object? raw) {
    if (raw is! String) return null;
    for (final c in CameraMovement.values) {
      if (c.name == raw) return c;
    }
    return null;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  /// 预期时长换算成毫秒（未设置时 null）——与 video 面板同键同单位。
  int? get _durationMsOrNull {
    final sec = _durationSec;
    return sec == null ? null : sec * 1000;
  }

  /// 立即落盘（下拉是离散选择，不需要防抖）。saveConfig 内部已吞异常，
  /// 自动保存是 best-effort。
  void _save(Map<String, Object?> patch) {
    unawaited(
      ref
          .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
          .saveConfig(patch),
    );
  }

  void _onChanged(String value) {
    setState(() {}); // 备注是否为空 → 生成按钮可用性
    ref
        .read(inspectorSubmitControllerProvider(widget.node.id).notifier)
        .saveDebounced(<String, Object?>{'shot_notes': value});
  }

  bool get _canGenerate =>
      !_busy && _notesCtrl.text.trim().isNotEmpty && widget.node.canvasId != null;

  /// 以当前备注为 prompt 新建 image config 节点（shot 右侧偏移一格），
  /// 并加 narrative 边 shot→image。
  Future<void> _generateImageFromNotes() => _generateFromNotes(
        type: CanvasNodeType.image,
        extraConfig: const <String, Object?>{},
      );

  /// SB-4：同上，但建 video config 节点，并把本镜的**镜头级参数**（SB-3 的
  /// 预期时长 / 预期运镜）一并带过去，省得用户在 video 面板重填一遍。
  ///
  /// 带过去的是**意图**：video 面板会按所选 provider 的
  /// `supportedDurations` / `supportedCameras` 钳制，不支持的值落地即被丢回
  /// 未设置——这正是 SB-3 说的「能不能真做到由生成时收口」。
  Future<void> _generateVideoFromNotes() => _generateFromNotes(
        type: CanvasNodeType.video,
        extraConfig: <String, Object?>{
          'duration_ms': ?_durationMsOrNull,
          'camera': ?_camera?.name,
        },
      );

  /// 在 shot 右侧偏移一格新建 config 节点 + narrative 边 shot→新节点。
  ///
  /// notifier 与文案在 await 前取好：面板中途销毁也保证「节点+边」成对落地。
  /// 失败仅 snackbar，节点/连线失败分开报——建节点失败就没必要报连线。
  Future<void> _generateFromNotes({
    required CanvasNodeType type,
    required Map<String, Object?> extraConfig,
  }) async {
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
          type: type,
          position: position,
          typeConfig: <String, Object?>{'prompt': notes, ...extraConfig},
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
            Text(
              context.l10n.inspectorShotDurationLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            DropdownButton<int?>(
              value: _durationSec,
              isExpanded: true,
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                  child: Text(context.l10n.inspectorShotParamUnset),
                ),
                for (final d in kShotDurationOptions)
                  DropdownMenuItem<int?>(
                    value: d,
                    child: Text(context.l10n.inspectorVideoDurationOption(d)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() => _durationSec = v);
                      // 清空写 null 而不是省略键——省略会让 saveConfig 的
                      // merge 保留旧值，用户点了「未设置」却清不掉。
                      _save(<String, Object?>{
                        'duration_ms': v == null ? null : v * 1000,
                      });
                    },
            ),
            const SizedBox(height: InkSpacing.md),
            Text(
              context.l10n.inspectorShotCameraLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            // 列**全量**枚举：shot 记的是意图，此刻还没选 provider。
            // 生成时由 video inspector 的 supportedCameras 钳制收口。
            DropdownButton<CameraMovement?>(
              value: _camera,
              isExpanded: true,
              items: <DropdownMenuItem<CameraMovement?>>[
                DropdownMenuItem<CameraMovement?>(
                  child: Text(context.l10n.inspectorShotParamUnset),
                ),
                for (final c in CameraMovement.values)
                  DropdownMenuItem<CameraMovement?>(
                    value: c,
                    child: Text(cameraMovementLabel(context, c)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() => _camera = v);
                      _save(<String, Object?>{'camera': v?.name});
                    },
            ),
            const SizedBox(height: InkSpacing.xs),
            Text(
              context.l10n.inspectorShotParamHint,
              style: typo.caption.copyWith(color: colors.fg4),
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
            const SizedBox(height: InkSpacing.sm),
            // SB-4：直达视频。次要按钮——图片是分镜的主流程，视频是进阶动作。
            OutlinedButton.icon(
              onPressed: _canGenerate ? _generateVideoFromNotes : null,
              icon: const Icon(
                Icons.movie_creation_outlined,
                size: InkSpacing.md,
              ),
              label: Text(context.l10n.inspectorShotGenerateVideo),
            ),
          ],
        ),
      ),
    );
  }
}
