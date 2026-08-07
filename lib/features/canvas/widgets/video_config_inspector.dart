// VideoConfigInspector：单选 video config 节点时展示的参数面板。
//
// 控件：prompt / provider / duration / camera 下拉 + 自动持久化 + 四态状态面板。
// mode（t2v vs i2v）在 GenerationController 根据 incoming data edges 自动推断。
//
// 纯 UI 层：持久化与提交状态机委托 InspectorSubmitController(nodeId)，
// 与 ImageConfigInspector 共享同一控制器和 InspectorStatusBinding。
// camera 枚举经 `util/camera_labels.dart` 映射展示（SB-3 起与 shot 面板共享），
// 不直出枚举名。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/di/providers.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../generation/services/cost_estimator.dart';
import '../models/canvas_node.dart';
import '../providers/inspector_submit_controller.dart';
import '../util/camera_labels.dart';
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
  final TextEditingController _promptCtrl = TextEditingController();
  String? _providerId;
  int? _durationSec;
  CameraMovement? _camera;

  InspectorSubmitController get _submitCtrl =>
      ref.read(inspectorSubmitControllerProvider(widget.node.id).notifier);

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
    final savedPrompt = tc['prompt'];
    if (savedPrompt is String) _promptCtrl.text = savedPrompt;
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
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

  void _onPromptChanged(String value) {
    setState(() {});
    _submitCtrl.savePromptDebounced(value);
  }

  void _submit() {
    final prompt = _promptCtrl.text.trim();
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
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final submitState = ref.watch(
      inspectorSubmitControllerProvider(widget.node.id),
    );
    final busy =
        submitState is InspectorSubmitSubmitting ||
        submitState is InspectorSubmitRunning;

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
              context.l10n.inspectorTitle,
              style: typo.title.copyWith(color: colors.fg1),
            ),
            const SizedBox(height: InkSpacing.lg),
            Text(
              context.l10n.inspectorVideoPromptLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            InkInput(
              controller: _promptCtrl,
              hintText: context.l10n.inspectorPromptHint,
              minLines: 4,
              maxLines: 8,
              onChanged: _onPromptChanged,
            ),
            const SizedBox(height: InkSpacing.md),
            Text(
              context.l10n.inspectorProviderLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            DropdownButton<String>(
              value: _providerId,
              isExpanded: true,
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
            const SizedBox(height: InkSpacing.md),
            Text(
              context.l10n.inspectorVideoDurationLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            DropdownButton<int>(
              value: _durationSec,
              isExpanded: true,
              items: [
                if (selected != null)
                  for (final d in selected.supportedDurations)
                    DropdownMenuItem(
                      value: d,
                      child: Text(context.l10n.inspectorVideoDurationOption(d)),
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
            // 运镜：仅当当前 provider 真正声明了 supportedCameras 才展示——
            // 否则隐藏整段（当前所有 provider 均为空，避免一个永远空的死下拉）。
            if (selected != null && selected.supportedCameras.isNotEmpty) ...[
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.inspectorVideoCameraLabel,
                style: typo.caption.copyWith(color: colors.fg3),
              ),
              const SizedBox(height: InkSpacing.xs),
              DropdownButton<CameraMovement>(
                value: _camera,
                isExpanded: true,
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
            ],
            const SizedBox(height: InkSpacing.md),
            Text(
              context.l10n.inspectorVideoModeAuto,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            if (selected != null) ...[
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.inspectorEstimatedCost(
                  formatCostUsd(
                    estimateCostUsd(
                      selected.costModel,
                      durationSeconds: _durationSec ?? 0,
                    ),
                  ),
                ),
                style: typo.caption.copyWith(color: colors.fg3),
              ),
            ],
            const SizedBox(height: InkSpacing.lg),
            InspectorStatusBinding(
              nodeId: widget.node.id,
              providerId: _providerId,
              promptEmpty: _promptCtrl.text.trim().isEmpty,
              generateLabel: context.l10n.inspectorVideoGenerate,
              disabledEmptyPromptText:
                  context.l10n.inspectorVideoGenerateDisabledEmptyPrompt,
              disabledNoKeyText:
                  context.l10n.inspectorVideoGenerateDisabledNoKey,
              onSubmit: _submit,
            ),
            // 入边（首/尾帧、参考图连线）：i2v 的首尾帧语义由此处 role 切换驱动，
            // GenerationController 按 role 分流到 firstFramePath/lastFramePath。
            if (widget.node.canvasId != null) ...[
              const SizedBox(height: InkSpacing.lg),
              NodeInputsSection(
                targetNode: widget.node,
                selectedCaps: selected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
