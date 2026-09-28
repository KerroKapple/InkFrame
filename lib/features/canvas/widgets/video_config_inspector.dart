// VideoConfigInspector：单选 video config 节点时的参数面板（Workspace v2 稿的三组）。
//
//   模型     供应商 / 片长 / 预估费用
//   关键帧   入边（起始帧 / 结束帧 / 参考帧 的连线 + 角色）
//   镜头运动 运镜方式（provider 声明 supportedCameras 才有）
// 之后是既有的角色区（maxRefImages>0 才挂）与生成状态。
//
// 提示词不在这里编辑——画布底部提示词条是唯一入口（稿）；本面板只读 node.promptText。
// mode（t2v vs i2v）在 GenerationController 根据 incoming data edges 自动推断。
// 稿上的「模型 / 帧率 / 画幅」在 provider 能力表里没有对应字段，不画。
// camera 枚举经 `util/camera_labels.dart` 映射展示（SB-3 起与 shot 面板共享）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/tokens.dart';
import '../../generation/services/cost_estimator.dart';
import '../models/canvas_node.dart';
import '../providers/inspector_submit_controller.dart';
import '../util/camera_labels.dart';
import 'characters_section.dart';
import 'inspector_rows.dart';
import 'inspector_status_panel.dart';
import 'node_inputs_section.dart';

class VideoConfigInspector extends ConsumerStatefulWidget {
  const VideoConfigInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  ConsumerState<VideoConfigInspector> createState() =>
      _VideoConfigInspectorState();
}

class _VideoConfigInspectorState extends ConsumerState<VideoConfigInspector> {
  String? _providerId;
  int? _durationSec;
  CameraMovement? _camera;

  InspectorSubmitController get _submitCtrl =>
      ref.read(inspectorSubmitControllerProvider(widget.node.id).notifier);

  String get _prompt => widget.node.promptText ?? '';

  @override
  void initState() {
    super.initState();
    final caps = _videoCaps();
    final tc = widget.node.typeConfig;

    final savedProviderId = tc['provider_id'] as String?;
    // 默认值链：节点已存 > 上次使用（须仍在能力列表）> first。
    final lastUsed =
        ref.read(preferencesServiceProvider).current.lastVideoProviderId;
    final lastUsedValid =
        lastUsed != null && caps.any((c) => c.providerId == lastUsed)
            ? lastUsed
            : null;
    _providerId = savedProviderId ??
        lastUsedValid ??
        (caps.isNotEmpty ? caps.first.providerId : null);
    final selected = _selectedCaps(caps);
    // 钳制到当前 provider 支持集，避免 DropdownButton "value 不在 items" 断言：
    // 持久化的旧值若不被当前 provider 支持，退回 first / null。
    final supportedDur = selected?.supportedDurations ?? const <int>[];
    final savedDurMs = tc['duration_ms'];
    final savedDurSec = savedDurMs is int ? savedDurMs ~/ 1000 : null;
    _durationSec = (savedDurSec != null && supportedDur.contains(savedDurSec))
        ? savedDurSec
        : (supportedDur.isNotEmpty ? supportedDur.first : null);

    final supportedCam = selected?.supportedCameras ?? const <CameraMovement>[];
    final savedCam = _parseCamera(tc['camera']);
    _camera = (savedCam != null && supportedCam.contains(savedCam))
        ? savedCam
        : (supportedCam.isNotEmpty ? supportedCam.first : null);
  }

  List<ProviderCapabilities> _videoCaps() => ref
      .read(providerCapabilitiesListProvider)
      .where(
        (c) =>
            c.modes.contains(GenerationMode.textToVideo) ||
            c.modes.contains(GenerationMode.imageToVideo),
      )
      .toList(growable: false);

  ProviderCapabilities? _selectedCaps(List<ProviderCapabilities> all) {
    if (_providerId == null || all.isEmpty) return null;
    return all.firstWhere(
      (c) => c.providerId == _providerId,
      orElse: () => all.first,
    );
  }

  CameraMovement? _parseCamera(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    for (final c in CameraMovement.values) {
      if (c.name == raw) return c;
    }
    return null;
  }

  void _submit() {
    final prompt = _prompt.trim();
    if (prompt.isEmpty || _providerId == null) return;
    _submitCtrl.submit(<String, Object?>{
      'prompt': prompt,
      'provider_id': _providerId,
      if (_durationSec != null) 'duration_ms': _durationSec! * 1000,
      if (_camera != null) 'camera': _camera!.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final caps = _videoCaps();
    final selected = _selectedCaps(caps);
    final l = context.l10n;
    final submitState = ref.watch(
      inspectorSubmitControllerProvider(widget.node.id),
    );
    final busy =
        submitState is InspectorSubmitSubmitting ||
        submitState is InspectorSubmitRunning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorGroup(
          title: l.inspectorGroupModel,
          children: [
            InspectorRow(
              label: l.inspectorProviderLabel,
              child: InspectorDropdown<String>(
                value: _providerId,
                items: [
                  for (final c in caps)
                    DropdownMenuItem(
                      value: c.providerId,
                      child: Text(c.displayName ?? c.providerId),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        final next = caps.firstWhere((c) => c.providerId == v);
                        final newDuration = next.supportedDurations.isNotEmpty
                            ? next.supportedDurations.first
                            : null;
                        final newCamera = next.supportedCameras.isNotEmpty
                            ? next.supportedCameras.first
                            : null;
                        setState(() {
                          _providerId = v;
                          _durationSec = newDuration;
                          _camera = newCamera;
                        });
                        _submitCtrl.saveConfig(<String, Object?>{
                          'provider_id': v,
                          if (newDuration != null)
                            'duration_ms': newDuration * 1000,
                          if (newCamera != null) 'camera': newCamera.name,
                        });
                        // 记住上次使用（fire-and-forget，服务内部吞盘错误）。
                        ref.read(preferencesServiceProvider).update(
                              (p) => p.copyWith(lastVideoProviderId: v),
                            );
                      },
              ),
            ),
            InspectorRow(
              label: l.inspectorVideoDurationLabel,
              child: InspectorDropdown<int>(
                value: _durationSec,
                items: [
                  if (selected != null)
                    for (final d in selected.supportedDurations)
                      DropdownMenuItem(
                        value: d,
                        child: Text(l.inspectorVideoDurationOption(d)),
                      ),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _durationSec = v);
                        _submitCtrl.saveConfig(<String, Object?>{
                          'duration_ms': v * 1000,
                        });
                      },
              ),
            ),
            if (selected != null)
              InspectorRow(
                label: l.inspectorEstimatedCostLabel,
                child: InspectorValue(
                  formatCostUsd(
                    estimateCostUsd(
                      selected.costModel,
                      durationSeconds: _durationSec ?? 0,
                    ),
                  ),
                  mono: true,
                  accent: true,
                ),
              ),
          ],
        ),
        // 入边（首/尾帧、参考图连线）：i2v 的首尾帧语义由此处 role 切换驱动，
        // GenerationController 按 role 分流到 firstFramePath/lastFramePath。
        InspectorGroup(
          title: l.inspectorGroupKeyframes,
          children: [
            if (widget.node.canvasId != null)
              NodeInputsSection(targetNode: widget.node, selectedCaps: selected),
            Padding(
              padding: const EdgeInsets.fromLTRB(InkSpacing.s12, InkSpacing.xs, InkSpacing.s12, 0),
              child: InspectorValue(l.inspectorVideoModeAuto),
            ),
          ],
        ),
        // 运镜：仅当当前 provider 真正声明了 supportedCameras 才展示——
        // 否则整组只剩说明（当前所有 provider 均为空，避免一个永远空的死下拉）。
        InspectorGroup(
          title: l.inspectorGroupCamera,
          children: [
            if (selected != null && selected.supportedCameras.isNotEmpty)
              InspectorRow(
                label: l.inspectorVideoCameraLabel,
                child: InspectorDropdown<CameraMovement>(
                  value: _camera,
                  items: [
                    for (final c in selected.supportedCameras)
                      DropdownMenuItem(
                        value: c,
                        child: Text(cameraMovementLabel(context, c)),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _camera = v);
                          _submitCtrl.saveConfig(<String, Object?>{
                            'camera': v.name,
                          });
                        },
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                child: InspectorValue(l.inspectorCameraUnsupported),
              ),
          ],
        ),
        // CH-2：角色区（CH-1 视频注入的用户入口）。门控对齐注入门：
        // 仅 maxRefImages>0 挂载——与 image 侧「常挂+警示文案」有意不同，
        // 视频多数 provider 无 ref 能力,常挂=一屏死区。
        if (selected != null && selected.maxRefImages > 0)
          InspectorGroup(
            title: l.inspectorCharactersLabel,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                child: CharactersSection(
                  targetNode: widget.node,
                  selectedCaps: selected,
                  requireImageToImageMode: false,
                ),
              ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(InkSpacing.s12),
          child: InspectorStatusBinding(
            nodeId: widget.node.id,
            providerId: _providerId,
            promptEmpty: _prompt.trim().isEmpty,
            generateLabel: l.inspectorVideoGenerate,
            disabledEmptyPromptText: l.inspectorVideoGenerateDisabledEmptyPrompt,
            disabledNoKeyText: l.inspectorVideoGenerateDisabledNoKey,
            onSubmit: _submit,
          ),
        ),
      ],
    );
  }
}
