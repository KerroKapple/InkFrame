// ImageConfigInspector：单选 image config 节点时的参数面板（Workspace v2 稿的三组）。
//
//   模型     供应商 / 画质 / 画幅 / 批量 / 预估费用
//   关键帧   入边（参考图 / 起始帧 / 结束帧 的连线 + 角色）/ 负向提示
//   镜头运动 固定种子 / 忽略泳道风格
// 之后是既有的预设 / 角色 / 最终提示词预览 / 生成状态四段。
//
// 提示词本身不在这里编辑——画布底部提示词条是唯一入口（稿）；本面板只读 node.promptText
// 供预设「存当前」与预览拼接；预设点选写库后 invalidate 节点控制器，提示词条随之重载。
// 稿上的「模型 / 帧率」两行在 provider 能力表里没有对应字段（只有 provider_id），不画。
//
// 纯 UI 层：持久化与提交状态机委托 InspectorSubmitController(nodeId)。

import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/preferences.dart';
import '../../../core/di/providers.dart';
import '../../../core/errors/ink_error.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_error_banner.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../generation/services/cost_estimator.dart';
import '../../generation/services/prompt_assembler.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/prompt_preset.dart';
import '../models/style_lane.dart';
import '../providers/canvas_base_style.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../providers/prompt_presets_controller.dart';
import 'characters_section.dart';
import 'inspector_rows.dart';
import 'inspector_status_panel.dart';
import 'node_inputs_section.dart';

class ImageConfigInspector extends ConsumerStatefulWidget {
  const ImageConfigInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  ConsumerState<ImageConfigInspector> createState() =>
      _ImageConfigInspectorState();
}

/// AspectRatio → 展示文案（"16:9" 等格式量，非用户散文，不入 ARB）。
String aspectRatioLabel(AspectRatio r) => switch (r) {
  AspectRatio.r1x1 => '1:1',
  AspectRatio.r16x9 => '16:9',
  AspectRatio.r9x16 => '9:16',
  AspectRatio.r4x3 => '4:3',
  AspectRatio.r3x4 => '3:4',
  AspectRatio.r21x9 => '21:9',
};

class _ImageConfigInspectorState extends ConsumerState<ImageConfigInspector> {
  final TextEditingController _seedCtrl = TextEditingController();
  final TextEditingController _negCtrl = TextEditingController();
  String? _providerId;
  Resolution? _resolution;
  AspectRatio? _aspect;
  int? _batch;
  late bool _ignoreLane;

  InspectorSubmitController get _submitCtrl =>
      ref.read(inspectorSubmitControllerProvider(widget.node.id).notifier);

  String get _prompt => widget.node.promptText ?? '';

  /// 应用预设：写 prompt + negative（节点级）并让节点控制器重载——提示词条按 node 重建。
  Future<void> _applyPreset(PromptPreset preset) async {
    setState(() => _negCtrl.text = preset.negative);
    await _submitCtrl.saveConfig(<String, Object?>{
      'prompt': preset.prompt,
      'negative_prompt': preset.negative,
    });
    final String? canvasId = widget.node.canvasId;
    if (canvasId != null) ref.invalidate(canvasNodesControllerProvider(canvasId));
  }

  @override
  void initState() {
    super.initState();
    final caps = ref.read(providerCapabilitiesListProvider);
    final tc = widget.node.typeConfig;

    final savedProviderId = tc['provider_id'] as String?;
    final savedResolution = _parseResolution(tc['resolution']);
    final defaultProviderId = caps.isNotEmpty ? caps.first.providerId : null;
    // 默认值链：节点已存 > 上次使用（须仍在能力列表，防自定义 provider 已删）> first。
    final lastUsed =
        ref.read(preferencesServiceProvider).current.lastImageProviderId;
    final lastUsedValid =
        lastUsed != null && caps.any((c) => c.providerId == lastUsed)
            ? lastUsed
            : null;
    _providerId = savedProviderId ?? lastUsedValid ?? defaultProviderId;
    final selectedCaps = caps.where((c) => c.providerId == _providerId);
    final sel = selectedCaps.isNotEmpty ? selectedCaps.first : null;
    final defaultResolution = sel != null && sel.supportedResolutions.isNotEmpty
        ? sel.supportedResolutions.first
        : null;
    _resolution = savedResolution ?? defaultResolution;

    // 宽高比 / seed / 负向 / 批量：钳制到当前 provider 能力集。
    final ratios = sel?.supportedRatios ?? const <AspectRatio>[];
    final savedAspect = _parseAspect(tc['aspect_ratio']);
    _aspect = (savedAspect != null && ratios.contains(savedAspect))
        ? savedAspect
        : (ratios.isNotEmpty ? ratios.first : null);

    final savedSeed = tc['seed'];
    if (savedSeed is int) _seedCtrl.text = savedSeed.toString();
    final savedNeg = tc['negative_prompt'];
    if (savedNeg is String) _negCtrl.text = savedNeg;

    final maxBatch = sel?.maxBatchSize ?? 1;
    final savedBatch = tc['batch_size'];
    _batch = (savedBatch is int && savedBatch >= 1 && savedBatch <= maxBatch)
        ? savedBatch
        : 1;

    _ignoreLane = widget.node.ignoreLaneStyle;
  }

  @override
  void dispose() {
    _seedCtrl.dispose();
    _negCtrl.dispose();
    super.dispose();
  }

  Resolution? _parseResolution(Object? raw) {
    if (raw is! String) return null;
    for (final r in Resolution.values) {
      if (r.name == raw) return r;
    }
    return null;
  }

  AspectRatio? _parseAspect(Object? raw) {
    if (raw is! String) return null;
    for (final a in AspectRatio.values) {
      if (a.name == raw) return a;
    }
    return null;
  }

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
    final selected = _selectedCaps(ref.read(providerCapabilitiesListProvider));
    final seed = int.tryParse(_seedCtrl.text.trim());
    final neg = _negCtrl.text.trim();
    _submitCtrl.submit(<String, Object?>{
      'prompt': prompt,
      'provider_id': _providerId,
      if (_resolution != null) 'resolution': _resolution!.name,
      if (selected != null &&
          selected.supportedRatios.isNotEmpty &&
          _aspect != null)
        'aspect_ratio': _aspect!.name,
      if (selected != null && selected.supportsNegativePrompt && neg.isNotEmpty)
        'negative_prompt': neg,
      if (selected != null && selected.supportsSeed && seed != null)
        'seed': seed,
      if (selected != null &&
          selected.supportsBatch &&
          selected.maxBatchSize > 1 &&
          _batch != null)
        'batch_size': _batch,
    });
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(providerCapabilitiesListProvider);
    final l = context.l10n;
    final selected = _selectedCaps(caps);
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
                        final newResolution = next.supportedResolutions.isNotEmpty
                            ? next.supportedResolutions.first
                            : null;
                        final newAspect = next.supportedRatios.isNotEmpty
                            ? next.supportedRatios.first
                            : null;
                        setState(() {
                          _providerId = v;
                          _resolution = newResolution;
                          _aspect = newAspect;
                          _batch = 1;
                        });
                        _submitCtrl.saveConfig(<String, Object?>{
                          'provider_id': v,
                          if (newResolution != null)
                            'resolution': newResolution.name,
                          if (newAspect != null) 'aspect_ratio': newAspect.name,
                          'batch_size': 1,
                        });
                        // 记住上次使用（fire-and-forget，服务内部吞盘错误）。
                        ref.read(preferencesServiceProvider).update(
                              (p) => p.copyWith(lastImageProviderId: v),
                            );
                      },
              ),
            ),
            InspectorRow(
              label: l.inspectorResolutionLabel,
              child: InspectorDropdown<Resolution>(
                value: _resolution,
                items: [
                  if (selected != null)
                    for (final r in selected.supportedResolutions)
                      DropdownMenuItem(value: r, child: Text(r.name)),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _resolution = v);
                        _submitCtrl.saveConfig(<String, Object?>{
                          'resolution': v.name,
                        });
                      },
              ),
            ),
            // 宽高比（provider 声明 supportedRatios 才显示）
            if (selected != null && selected.supportedRatios.isNotEmpty)
              InspectorRow(
                label: l.inspectorAspectRatioLabel,
                child: InspectorDropdown<AspectRatio>(
                  value: _aspect,
                  items: [
                    for (final r in selected.supportedRatios)
                      DropdownMenuItem(
                        value: r,
                        child: Text(aspectRatioLabel(r)),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _aspect = v);
                          _submitCtrl.saveConfig(<String, Object?>{
                            'aspect_ratio': v.name,
                          });
                        },
                ),
              ),
            // 批量数量（provider supportsBatch 且 maxBatchSize>1 才显示）
            if (selected != null &&
                selected.supportsBatch &&
                selected.maxBatchSize > 1)
              InspectorRow(
                label: l.inspectorBatchLabel,
                child: InspectorDropdown<int>(
                  value: _batch,
                  items: [
                    for (var i = 1; i <= selected.maxBatchSize; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: busy
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _batch = v);
                          _submitCtrl.saveConfig(<String, Object?>{
                            'batch_size': v,
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
                      resolution: _resolution,
                      batchSize: _batch ?? 1,
                      promptChars: _prompt.length,
                    ),
                  ),
                  mono: true,
                  accent: true,
                ),
              ),
          ],
        ),
        InspectorGroup(
          title: l.inspectorGroupKeyframes,
          children: [
            if (widget.node.canvasId != null)
              NodeInputsSection(targetNode: widget.node, selectedCaps: selected),
            // 负向提示词（provider supportsNegativePrompt 才显示）
            if (selected != null && selected.supportsNegativePrompt)
              InspectorRow(
                label: l.inspectorNegativePromptLabel,
                height: null,
                child: InkInput(
                  controller: _negCtrl,
                  hintText: l.inspectorNegativePromptHint,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (v) => _submitCtrl.saveConfig(<String, Object?>{
                    'negative_prompt': v.trim(),
                  }),
                ),
              ),
          ],
        ),
        InspectorGroup(
          title: l.inspectorGroupCamera,
          children: [
            // 随机种子（provider supportsSeed 才显示；留空 = 随机）
            if (selected != null && selected.supportsSeed)
              InspectorRow(
                label: l.inspectorSeedLabel,
                child: InkInput(
                  controller: _seedCtrl,
                  hintText: l.inspectorSeedHint,
                  onChanged: (v) => _submitCtrl.saveConfig(<String, Object?>{
                    'seed': int.tryParse(v.trim()),
                  }),
                ),
              ),
            if (widget.node.canvasId != null)
              InspectorRow(
                label: l.inspectorIgnoreLaneStyle,
                child: InspectorToggleRow(
                  value: _ignoreLane,
                  onChanged: (v) {
                    setState(() => _ignoreLane = v);
                    _submitCtrl.saveConfig(<String, Object?>{
                      'ignore_lane_style': v,
                    });
                  },
                ),
              ),
          ],
        ),
        if (widget.node.canvasId != null) ...[
          InspectorGroup(
            title: l.inspectorPresetsLabel,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                child: _PresetsSection(
                  targetNode: widget.node,
                  onApply: _applyPreset,
                  readCurrent: () => (prompt: _prompt, negative: _negCtrl.text),
                ),
              ),
            ],
          ),
          InspectorGroup(
            title: l.inspectorCharactersLabel,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                child: CharactersSection(
                  targetNode: widget.node,
                  selectedCaps: selected,
                  // image 维持原门：maxRefImages>0 且 imageToImage（CH-2 抽共享后参数化）。
                  requireImageToImageMode: true,
                ),
              ),
            ],
          ),
          InspectorGroup(
            title: l.inspectorPromptPreviewLabel,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                child: _PromptPreview(
                  node: widget.node,
                  canvasId: widget.node.canvasId!,
                  currentPrompt: _prompt,
                  ignoreLane: _ignoreLane,
                ),
              ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.all(InkSpacing.s12),
          child: InspectorStatusBinding(
            nodeId: widget.node.id,
            providerId: _providerId,
            promptEmpty: _prompt.trim().isEmpty,
            generateLabel: l.inspectorGenerate,
            disabledEmptyPromptText: l.inspectorGenerateDisabledEmptyPrompt,
            disabledNoKeyText: l.inspectorGenerateDisabledNoKey,
            onSubmit: _submit,
          ),
        ),
      ],
    );
  }
}

/// 项目级提示词预设库：点选预设 → 填入 prompt/negative；「存为预设」把当前 prompt 存起。
class _PresetsSection extends ConsumerStatefulWidget {
  const _PresetsSection({
    required this.targetNode,
    required this.onApply,
    required this.readCurrent,
  });

  final CanvasNode targetNode;
  final void Function(PromptPreset preset) onApply;
  final ({String prompt, String negative}) Function() readCurrent;

  @override
  ConsumerState<_PresetsSection> createState() => _PresetsSectionState();
}

class _PresetsSectionState extends ConsumerState<_PresetsSection> {
  @override
  Widget build(BuildContext context) {
    final projectId = widget.targetNode.projectId;
    if (projectId == null) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final presetsAsync = ref.watch(promptPresetsControllerProvider(projectId));
    final presets = presetsAsync.valueOrNull ?? const <PromptPreset>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 加载失败 → 错误横幅（此前静默降级为空 = 误报"无预设"）。
        if (presetsAsync.hasError)
          InkErrorBanner(
            message: l10nAsyncError(context, presetsAsync.error!),
          )
        else if (presets.isEmpty)
          Text(
            context.l10n.inspectorPresetsEmpty,
            style: typo.meta.copyWith(color: colors.fg5),
          )
        else
          Wrap(
            spacing: InkSpacing.xs,
            runSpacing: InkSpacing.xs,
            children: [
              for (final p in presets)
                CharacterChip(
                  label: p.name.isNotEmpty ? p.name : p.id,
                  selected: false,
                  onTap: () => widget.onApply(p),
                ),
            ],
          ),
        const SizedBox(height: InkSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _saveCurrent(context, projectId),
            icon: const Icon(Icons.bookmark_add_outlined, size: 16),
            label: Text(context.l10n.inspectorPresetsSaveCurrent),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCurrent(BuildContext context, String projectId) async {
    final current = widget.readCurrent();
    if (current.prompt.trim().isEmpty) return;
    final name = await _promptPresetName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref
          .read(promptPresetsControllerProvider(projectId).notifier)
          .create(
            name: name.trim(),
            prompt: current.prompt.trim(),
            negative: current.negative.trim(),
          );
    } on InkError catch (_) {
      // 落库失败不崩 UI，但必须让用户知道没存上（此前静默吞错 = 假成功）。
      // 参数 context 跨 async gap 不可用，取 State 自身 context（mounted 已守卫）。
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(this.context)?.showSnackBar(
        SnackBar(content: Text(this.context.l10n.inspectorPresetsSaveFailed)),
      );
    }
  }

  Future<String?> _promptPresetName(BuildContext context) =>
      showDialog<String>(
        context: context,
        builder: (ctx) => InspectorNameDialog(
          title: ctx.l10n.inspectorPresetsDialogTitle,
          hint: ctx.l10n.inspectorPresetsNameHint,
          confirmLabel: ctx.l10n.inspectorCharactersSave,
          cancelLabel: ctx.l10n.commonCancel,
        ),
      );
}

/// 最终 prompt 预览框：实时拼接 base 前缀 + 泳道风格 + 关联文本 + 用户 prompt。
class _PromptPreview extends ConsumerWidget {
  const _PromptPreview({
    required this.node,
    required this.canvasId,
    required this.currentPrompt,
    required this.ignoreLane,
  });

  final CanvasNode node;
  final String canvasId;
  final String currentPrompt;
  final bool ignoreLane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;

    // 泳道风格
    final lanes =
        ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ??
        const <StyleLane>[];
    final lane = node.laneId == null
        ? null
        : lanes
              .where((l) => l.id == node.laneId)
              .cast<StyleLane?>()
              .firstWhere((_) => true, orElse: () => null);

    // 良性降级（GAP-3 审计 B 类）：base 前后缀读失败降级为空——与提交链路
    // generation_controller._assembleFullPrompt 的一致性降级同步（预览=实发）。
    final baseStyle =
        ref.watch(canvasBaseStyleProvider(canvasId)).valueOrNull ??
        (prefix: '', suffix: '');

    // 关联文本节点（data 边 → 源 text 节点，按边排列顺序）
    final edges =
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    final nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasNode>[];
    final nodesById = {for (final n in nodes) n.id: n};
    final dataEdges = edges
        .where((e) => e.targetNodeId == node.id && e.edgeType == EdgeType.data)
        .toList();
    final texts = <String>[];
    for (final e in dataEdges) {
      final src = nodesById[e.sourceNodeId];
      if (src == null || src.type != CanvasNodeType.text) continue;
      final t = src.textContent?.trim();
      final l = src.label.trim();
      final content = (t != null && t.isNotEmpty)
          ? t
          : (l.isNotEmpty ? l : null);
      if (content != null) texts.add(content);
    }

    final preview = assemblePrompt(
      baseStylePrefix: baseStyle.prefix,
      laneStylePrompt: lane?.stylePrompt ?? '',
      associatedTexts: texts,
      userPrompt: currentPrompt,
      baseStyleSuffix: baseStyle.suffix,
      ignoreLaneStyle: ignoreLane,
    );

    return Text(
      preview.isEmpty ? '—' : preview,
      style: typo.meta.copyWith(color: colors.fg2),
    );
  }
}
