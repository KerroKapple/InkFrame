// ImageConfigInspector：单选 image config 节点时展示的参数面板。
//
// 纯 UI 层：本地仅持有表单控件状态（prompt 控制器 / 下拉选中值 / ignore-lane 开关）。
// 持久化（含 prompt 防抖）与提交状态机全部委托
// InspectorSubmitController(nodeId)；hasApiKey 经 inspectorHasApiKeyProvider
// 缓存；四态渲染由 InspectorStatusBinding → InspectorStatusPanel 完成。

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/file_resolver.dart';
import '../../../core/di/providers.dart';
import '../../../core/interfaces/file_resolver_service.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../../generation/services/cost_estimator.dart';
import '../../generation/services/prompt_assembler.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../models/character.dart';
import '../models/prompt_preset.dart';
import '../models/style_lane.dart';
import '../providers/canvas_base_style.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/characters_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../providers/prompt_presets_controller.dart';
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
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _seedCtrl = TextEditingController();
  final TextEditingController _negCtrl = TextEditingController();
  String? _providerId;
  Resolution? _resolution;
  AspectRatio? _aspect;
  int? _batch;
  late bool _ignoreLane;

  InspectorSubmitController get _submitCtrl =>
      ref.read(inspectorSubmitControllerProvider(widget.node.id).notifier);

  /// 应用预设：填入 prompt + negative（节点级），并落盘。prefix/suffix 为画布级，
  /// v1 不在此改动画布 base style（避免跨节点意外），仅带 prompt/negative。
  void _applyPreset(PromptPreset preset) {
    setState(() {
      _promptCtrl.text = preset.prompt;
      _negCtrl.text = preset.negative;
    });
    _submitCtrl.saveConfig(<String, Object?>{
      'prompt': preset.prompt,
      'negative_prompt': preset.negative,
    });
  }

  @override
  void initState() {
    super.initState();
    final caps = ref.read(providerCapabilitiesListProvider);
    final tc = widget.node.typeConfig;

    final savedProviderId = tc['provider_id'] as String?;
    final savedResolution = _parseResolution(tc['resolution']);
    final defaultProviderId = caps.isNotEmpty ? caps.first.providerId : null;
    _providerId = savedProviderId ?? defaultProviderId;
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

    final savedPrompt = tc['prompt'];
    if (savedPrompt is String) _promptCtrl.text = savedPrompt;
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
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

  void _onPromptChanged(String value) {
    setState(() {});
    _submitCtrl.savePromptDebounced(value);
  }

  ProviderCapabilities? _selectedCaps(List<ProviderCapabilities> all) {
    if (_providerId == null) return null;
    return all.firstWhere(
      (c) => c.providerId == _providerId,
      orElse: () => all.first,
    );
  }

  void _submit() {
    final prompt = _promptCtrl.text.trim();
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
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final selected = _selectedCaps(caps);
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
              context.l10n.inspectorPromptLabel,
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
                    },
            ),
            const SizedBox(height: InkSpacing.md),
            Text(
              context.l10n.inspectorResolutionLabel,
              style: typo.caption.copyWith(color: colors.fg3),
            ),
            const SizedBox(height: InkSpacing.xs),
            DropdownButton<Resolution>(
              value: _resolution,
              isExpanded: true,
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
            // 宽高比（provider 声明 supportedRatios 才显示）
            if (selected != null && selected.supportedRatios.isNotEmpty) ...[
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.inspectorAspectRatioLabel,
                style: typo.caption.copyWith(color: colors.fg3),
              ),
              const SizedBox(height: InkSpacing.xs),
              DropdownButton<AspectRatio>(
                value: _aspect,
                isExpanded: true,
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
            ],
            // 负向提示词（provider supportsNegativePrompt 才显示）
            if (selected != null && selected.supportsNegativePrompt) ...[
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.inspectorNegativePromptLabel,
                style: typo.caption.copyWith(color: colors.fg3),
              ),
              const SizedBox(height: InkSpacing.xs),
              InkInput(
                controller: _negCtrl,
                hintText: context.l10n.inspectorNegativePromptHint,
                minLines: 2,
                maxLines: 4,
                onChanged: (v) => _submitCtrl.saveConfig(<String, Object?>{
                  'negative_prompt': v.trim(),
                }),
              ),
            ],
            // 随机种子（provider supportsSeed 才显示；留空 = 随机）
            if (selected != null && selected.supportsSeed) ...[
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.inspectorSeedLabel,
                style: typo.caption.copyWith(color: colors.fg3),
              ),
              const SizedBox(height: InkSpacing.xs),
              InkInput(
                controller: _seedCtrl,
                hintText: context.l10n.inspectorSeedHint,
                onChanged: (v) => _submitCtrl.saveConfig(<String, Object?>{
                  'seed': int.tryParse(v.trim()),
                }),
              ),
            ],
            // 批量数量（provider supportsBatch 且 maxBatchSize>1 才显示）
            if (selected != null &&
                selected.supportsBatch &&
                selected.maxBatchSize > 1) ...[
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.inspectorBatchLabel,
                style: typo.caption.copyWith(color: colors.fg3),
              ),
              const SizedBox(height: InkSpacing.xs),
              DropdownButton<int>(
                value: _batch,
                isExpanded: true,
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
            ],
            if (selected != null) ...[
              const SizedBox(height: InkSpacing.md),
              Text(
                context.l10n.inspectorEstimatedCost(
                  formatCostUsd(
                    estimateCostUsd(
                      selected.costModel,
                      resolution: _resolution,
                      batchSize: _batch ?? 1,
                      promptChars: _promptCtrl.text.length,
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
              generateLabel: context.l10n.inspectorGenerate,
              disabledEmptyPromptText:
                  context.l10n.inspectorGenerateDisabledEmptyPrompt,
              disabledNoKeyText: context.l10n.inspectorGenerateDisabledNoKey,
              onSubmit: _submit,
            ),
            if (widget.node.canvasId != null) ...[
              const SizedBox(height: InkSpacing.lg),
              NodeInputsSection(targetNode: widget.node, selectedCaps: selected),
              const SizedBox(height: InkSpacing.md),
              _PresetsSection(
                targetNode: widget.node,
                onApply: _applyPreset,
                readCurrent: () =>
                    (prompt: _promptCtrl.text, negative: _negCtrl.text),
              ),
              const SizedBox(height: InkSpacing.md),
              _CharactersSection(
                targetNode: widget.node,
                selectedCaps: selected,
              ),
              const SizedBox(height: InkSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.inspectorIgnoreLaneStyle,
                      style: typo.body.copyWith(color: colors.fg1),
                    ),
                  ),
                  Switch(
                    value: _ignoreLane,
                    onChanged: (v) {
                      setState(() => _ignoreLane = v);
                      _submitCtrl.saveConfig(<String, Object?>{
                        'ignore_lane_style': v,
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: InkSpacing.md),
              _PromptPreview(
                node: widget.node,
                canvasId: widget.node.canvasId!,
                currentPrompt: _promptCtrl.text,
                ignoreLane: _ignoreLane,
              ),
            ],
          ],
        ),
      ),
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
    final presets =
        ref.watch(promptPresetsControllerProvider(projectId)).valueOrNull ??
        const <PromptPreset>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.inspectorPresetsLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        if (presets.isEmpty)
          Text(
            context.l10n.inspectorPresetsEmpty,
            style: typo.caption.copyWith(color: colors.fg3),
          )
        else
          Wrap(
            spacing: InkSpacing.xs,
            runSpacing: InkSpacing.xs,
            children: [
              for (final p in presets)
                _CharacterChip(
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
    } on Exception catch (_) {
      // best-effort：落库失败不崩 UI（InkError 均实现 Exception）。
    }
  }

  Future<String?> _promptPresetName(BuildContext context) async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.inspectorPresetsDialogTitle),
          content: InkInput(
            controller: ctrl,
            hintText: ctx.l10n.inspectorPresetsNameHint,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: Text(ctx.l10n.inspectorCharactersSave),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }
}

/// 项目级角色一致性：把可复用角色挂到本 config 节点（写 type_config.character_ids），
/// 并支持把已连的参考图「存为角色」。仅当 provider 支持参考图时真正生效（否则给提示）。
class _CharactersSection extends ConsumerStatefulWidget {
  const _CharactersSection({
    required this.targetNode,
    required this.selectedCaps,
  });

  final CanvasNode targetNode;
  final ProviderCapabilities? selectedCaps;

  @override
  ConsumerState<_CharactersSection> createState() => _CharactersSectionState();
}

class _CharactersSectionState extends ConsumerState<_CharactersSection> {
  late Set<String> _attachedIds;

  @override
  void initState() {
    super.initState();
    _attachedIds = _readAttached(widget.targetNode.typeConfig);
  }

  Set<String> _readAttached(Map<String, Object?> tc) {
    final raw = tc['character_ids'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
    }
    return <String>{};
  }

  InspectorSubmitController get _submitCtrl => ref.read(
    inspectorSubmitControllerProvider(widget.targetNode.id).notifier,
  );

  bool get _supportsRefs {
    final caps = widget.selectedCaps;
    return caps != null &&
        caps.maxRefImages > 0 &&
        caps.modes.contains(GenerationMode.imageToImage);
  }

  void _toggle(String id) {
    setState(() {
      if (!_attachedIds.add(id)) _attachedIds.remove(id);
    });
    _submitCtrl.saveConfig(<String, Object?>{
      'character_ids': _attachedIds.toList(growable: false),
    });
  }

  /// 本 config 节点第一条 reference data 边上、带 image_url 的源节点（"存为角色"来源）。
  CanvasNode? _referenceSource() {
    final canvasId = widget.targetNode.canvasId;
    if (canvasId == null) return null;
    final edges =
        ref.watch(canvasEdgesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasEdge>[];
    final nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
        const <CanvasNode>[];
    final nodesById = {for (final n in nodes) n.id: n};
    for (final e in edges) {
      if (e.targetNodeId != widget.targetNode.id ||
          e.edgeType != EdgeType.data ||
          e.role != EdgeRole.reference) {
        continue;
      }
      final src = nodesById[e.sourceNodeId];
      if (src != null && (src.imageUrl?.isNotEmpty ?? false)) return src;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.targetNode.projectId;
    if (projectId == null) return const SizedBox.shrink();
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final characters =
        ref.watch(charactersControllerProvider(projectId)).valueOrNull ??
        const <Character>[];
    final refSource = _referenceSource();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.inspectorCharactersLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        if (!_supportsRefs)
          Padding(
            padding: const EdgeInsets.only(bottom: InkSpacing.xs),
            child: Text(
              context.l10n.inspectorCharactersUnsupported,
              style: typo.caption.copyWith(color: colors.warning),
            ),
          ),
        if (characters.isEmpty)
          Text(
            context.l10n.inspectorCharactersEmpty,
            style: typo.caption.copyWith(color: colors.fg3),
          )
        else
          Wrap(
            spacing: InkSpacing.xs,
            runSpacing: InkSpacing.xs,
            children: [
              for (final c in characters)
                _CharacterChip(
                  label: c.name.isNotEmpty ? c.name : c.id,
                  selected: _attachedIds.contains(c.id),
                  onTap: () => _toggle(c.id),
                ),
            ],
          ),
        const SizedBox(height: InkSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: refSource == null
                ? null
                : () => _createFromReference(refSource),
            icon: const Icon(Icons.person_add_alt_1, size: 16),
            label: Text(context.l10n.inspectorCharactersSaveFromReference),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _importFromFile,
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(context.l10n.inspectorCharactersImportFile),
          ),
        ),
      ],
    );
  }

  /// 从磁盘选图新建角色（file_selector，桌面）。不依赖已连参考图，补齐首个角色的种子路径。
  Future<void> _importFromFile() async {
    final projectId = widget.targetNode.projectId;
    if (projectId == null) return;
    const group = XTypeGroup(
      label: 'images',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    if (file == null || !mounted) return;
    final name = await _promptName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref
          .read(charactersControllerProvider(projectId).notifier)
          .createFromImage(name: name.trim(), sourceAbsolutePath: file.path);
      if (mounted) _toggle(id);
    } on Exception catch (_) {
      // best-effort：选择/导入失败不崩 UI。
    }
  }

  Future<void> _createFromReference(CanvasNode source) async {
    final canvasId = widget.targetNode.canvasId;
    final projectId = widget.targetNode.projectId;
    final rel = source.imageUrl;
    if (canvasId == null || projectId == null || rel == null || rel.isEmpty) {
      return;
    }
    final String abs;
    try {
      abs = ref
          .read(fileResolverServiceProvider)
          .resolve(projectId: projectId, canvasId: canvasId, relativePath: rel)
          .path;
    } on PathSecurityError catch (_) {
      return;
    }
    final name = await _promptName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      final id = await ref
          .read(charactersControllerProvider(projectId).notifier)
          .createFromImage(name: name.trim(), sourceAbsolutePath: abs);
      if (mounted) _toggle(id);
    } on Exception catch (_) {
      // best-effort：导入/落库失败不崩 UI（下次可重试）。
    }
  }

  Future<String?> _promptName(BuildContext context) async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.inspectorCharactersDialogTitle),
          content: InkInput(
            controller: ctrl,
            hintText: ctx.l10n.inspectorCharactersNameHint,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: Text(ctx.l10n.inspectorCharactersSave),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }
}

class _CharacterChip extends StatelessWidget {
  const _CharacterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InkRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.sm,
          vertical: InkSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface2,
          borderRadius: BorderRadius.circular(InkRadius.sm),
          border: Border.all(color: selected ? colors.accent : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: colors.surfaceCanvas),
              const SizedBox(width: InkSpacing.xs),
            ],
            Text(
              label,
              style: typo.caption.copyWith(
                color: selected ? colors.surfaceCanvas : colors.fg1,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

    // 画布 base 前缀 / 后缀（失败降级为空字符串）
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.inspectorPromptPreviewLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(InkSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(InkRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            preview.isEmpty ? '—' : preview,
            style: typo.caption.copyWith(color: colors.fg2),
          ),
        ),
      ],
    );
  }
}
