// VideoConfigInspector：单选 video config 节点时的参数面板（Workspace v2 稿的三组）。
//
//   模型     供应商 / 片长 / 预估费用
//   关键帧   入边（起始帧 / 结束帧 / 参考帧 的连线 + 角色）
//   镜头运动 运镜方式 / 景别 / 机位角度 / 运镜幅度 / 焦段（P3 镜头语言：全量枚举，不按 provider 能力位隐藏）
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
import '../../../core/models/shot_language.dart';
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
  ShotLanguage _lang = ShotLanguage.empty;

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

    // P3：运镜不再钳到 provider 的 supportedCameras——它是导演意图，落库 + 注入提示词；
    // 是否作为参数下发由 GenerationController 按能力位决定。
    _camera = parseCameraMovement(tc['camera']);
    _lang = widget.node.shotLanguage;
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

  void _submit() {
    final prompt = _prompt.trim();
    if (prompt.isEmpty || _providerId == null) return;
    _submitCtrl.submit(<String, Object?>{
      'prompt': prompt,
      'provider_id': _providerId,
      if (_durationSec != null) 'duration_ms': _durationSec! * 1000,
      if (_camera != null) 'camera': _camera!.name,
      ..._lang.toTypeConfigPatch(),
    });
  }

  /// 镜头语言四字段：改一项即落盘该项（空值写 null = 清除）。
  void _saveLang(ShotLanguage next) {
    setState(() => _lang = next);
    _submitCtrl.saveConfig(next.toTypeConfigPatch());
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
                        // 换 provider 不动运镜（导演意图与 provider 无关，P3）。
                        setState(() {
                          _providerId = v;
                          _durationSec = newDuration;
                        });
                        _submitCtrl.saveConfig(<String, Object?>{
                          'provider_id': v,
                          if (newDuration != null)
                            'duration_ms': newDuration * 1000,
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
        // 镜头运动（P3，稿的五行）：运镜方式 / 景别 / 机位角度 / 运镜幅度（滑杆）/ 焦段。
        // 全部是导演意图：落库 + 英文注入提示词（shot_language_prompt.dart）；provider 不支持
        // camera 能力位时 GenerationController 只注入不下发参数，这里不再按能力位隐藏。
        InspectorGroup(
          title: l.inspectorGroupCamera,
          children: [
            InspectorRow(
              label: l.inspectorVideoCameraLabel,
              child: InspectorDropdown<CameraMovement>(
                value: _camera,
                hint: l.inspectorShotLanguageUnset,
                items: [
                  for (final c in CameraMovement.values)
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
            ),
            InspectorRow(
              label: l.inspectorShotSizeLabel,
              child: InspectorDropdown<ShotSize>(
                value: _lang.shotSize,
                hint: l.inspectorShotLanguageUnset,
                items: [
                  for (final s in ShotSize.values)
                    DropdownMenuItem(value: s, child: Text(shotSizeLabel(context, s))),
                ],
                onChanged: busy ? null : (v) => _saveLang(_lang.copyWith(shotSize: v)),
              ),
            ),
            InspectorRow(
              label: l.inspectorCameraAngleLabel,
              child: InspectorDropdown<CameraAngle>(
                value: _lang.cameraAngle,
                hint: l.inspectorShotLanguageUnset,
                items: [
                  for (final a in CameraAngle.values)
                    DropdownMenuItem(value: a, child: Text(cameraAngleLabel(context, a))),
                ],
                onChanged: busy ? null : (v) => _saveLang(_lang.copyWith(cameraAngle: v)),
              ),
            ),
            InspectorRow(
              label: l.inspectorMotionStrengthLabel,
              child: InspectorSlider(
                value: _lang.motionStrength,
                divisions: (1 / kMotionStrengthStep).round(),
                label: _lang.motionStrength == null
                    ? l.inspectorShotLanguageUnset
                    : motionStrengthLabel(_lang.motionStrength!),
                onChanged: busy
                    ? null
                    : (v) => _saveLang(_lang.copyWith(
                          motionStrength: (v / kMotionStrengthStep).round() * kMotionStrengthStep,
                        )),
              ),
            ),
            InspectorRow(
              label: l.inspectorFocalLengthLabel,
              child: InspectorDropdown<int>(
                value: _lang.focalLengthMm,
                hint: l.inspectorShotLanguageUnset,
                items: [
                  for (final mm in kFocalLengthsMm)
                    DropdownMenuItem(value: mm, child: Text(focalLengthLabel(context, mm))),
                ],
                onChanged: busy ? null : (v) => _saveLang(_lang.copyWith(focalLengthMm: v)),
              ),
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
