// ImageConfigInspector：单选 image config 节点时展示的参数面板。
//
// 纯 UI 层：本地仅持有表单控件状态（prompt 控制器 / 下拉选中值）。
// 持久化（含 prompt 防抖）与提交状态机全部委托
// InspectorSubmitController(nodeId)；hasApiKey 经 inspectorHasApiKeyProvider
// 缓存；四态渲染由 InspectorStatusBinding → InspectorStatusPanel 完成。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
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
import 'inspector_status_panel.dart';

class ImageConfigInspector extends ConsumerStatefulWidget {
  const ImageConfigInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  ConsumerState<ImageConfigInspector> createState() =>
      _ImageConfigInspectorState();
}

class _ImageConfigInspectorState extends ConsumerState<ImageConfigInspector> {
  final TextEditingController _promptCtrl = TextEditingController();
  String? _providerId;
  Resolution? _resolution;

  InspectorSubmitController get _submitCtrl => ref
      .read(inspectorSubmitControllerProvider(widget.node.id).notifier);

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
    final defaultResolution = selectedCaps.isNotEmpty &&
            selectedCaps.first.supportedResolutions.isNotEmpty
        ? selectedCaps.first.supportedResolutions.first
        : null;
    _resolution = savedResolution ?? defaultResolution;

    final savedPrompt = tc['prompt'];
    if (savedPrompt is String) _promptCtrl.text = savedPrompt;
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Resolution? _parseResolution(Object? raw) {
    if (raw is! String) return null;
    for (final r in Resolution.values) {
      if (r.name == raw) return r;
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
    _submitCtrl.submit(<String, Object?>{
      'prompt': prompt,
      'provider_id': _providerId,
      if (_resolution != null) 'resolution': _resolution!.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(providerCapabilitiesListProvider);
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final selected = _selectedCaps(caps);
    final submitState =
        ref.watch(inspectorSubmitControllerProvider(widget.node.id));
    final busy = submitState is InspectorSubmitSubmitting ||
        submitState is InspectorSubmitRunning;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(InkSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(left: BorderSide(color: colors.border)),
      ),
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
                    final next =
                        caps.firstWhere((c) => c.providerId == v);
                    final newResolution =
                        next.supportedResolutions.isNotEmpty
                            ? next.supportedResolutions.first
                            : null;
                    setState(() {
                      _providerId = v;
                      _resolution = newResolution;
                    });
                    _submitCtrl.saveConfig(<String, Object?>{
                      'provider_id': v,
                      if (newResolution != null)
                        'resolution': newResolution.name,
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
                    _submitCtrl.saveConfig(
                      <String, Object?>{'resolution': v.name},
                    );
                  },
          ),
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
            _InputsSection(targetNode: widget.node),
          ],
        ],
      ),
    );
  }
}

class _InputsSection extends ConsumerWidget {
  const _InputsSection({required this.targetNode});
  final CanvasNode targetNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canvasId = targetNode.canvasId!;
    final colors = context.inkColors;
    final typo = context.inkTypography;

    final edgesAsync = ref.watch(canvasEdgesControllerProvider(canvasId));
    final nodesAsync = ref.watch(canvasNodesControllerProvider(canvasId));
    final edges = edgesAsync.valueOrNull ?? const <CanvasEdge>[];
    final nodes = nodesAsync.valueOrNull ?? const <CanvasNode>[];
    final nodesById = {for (final n in nodes) n.id: n};

    final inputs = edges
        .where((e) =>
            e.targetNodeId == targetNode.id && e.edgeType == EdgeType.data)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.inspectorInputsLabel,
          style: typo.caption.copyWith(color: colors.fg3),
        ),
        const SizedBox(height: InkSpacing.xs),
        if (inputs.isEmpty)
          Text(
            context.l10n.inspectorInputsEmpty,
            style: typo.caption.copyWith(color: colors.fg3),
          )
        else
          for (final edge in inputs)
            _InputRow(
              edge: edge,
              source: nodesById[edge.sourceNodeId],
              canvasId: canvasId,
            ),
      ],
    );
  }
}

class _InputRow extends ConsumerWidget {
  const _InputRow({
    required this.edge,
    required this.source,
    required this.canvasId,
  });

  final CanvasEdge edge;
  final CanvasNode? source;
  final String canvasId;

  String _roleLabel(BuildContext context, EdgeRole role) => switch (role) {
        EdgeRole.reference => context.l10n.inspectorRoleReference,
        EdgeRole.firstFrame => context.l10n.inspectorRoleFirstFrame,
        EdgeRole.lastFrame => context.l10n.inspectorRoleLastFrame,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final ctrl = ref.read(canvasEdgesControllerProvider(canvasId).notifier);
    final sourceLabel = source?.label.isNotEmpty == true
        ? source!.label
        : (source?.id ?? edge.sourceNodeId);

    return Padding(
      padding: const EdgeInsets.only(bottom: InkSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sourceLabel,
              style: typo.body.copyWith(color: colors.fg1),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: InkSpacing.xs),
          DropdownButton<EdgeRole>(
            value: edge.role,
            isDense: true,
            items: [
              for (final r in EdgeRole.values)
                DropdownMenuItem(value: r, child: Text(_roleLabel(context, r))),
            ],
            onChanged: (v) {
              if (v == null || v == edge.role) return;
              ctrl.updateRole(edge.id, v).catchError((Object _) {
                // 失败已由 Controller 回滚内存；UI 由 edges 列表自动重渲染
              });
            },
          ),
          IconButton(
            tooltip: context.l10n.inspectorRemoveInput,
            icon: Icon(Icons.link_off, size: 16, color: colors.danger),
            onPressed: () {
              ctrl.removeEdge(edge.id).catchError((Object _) {});
            },
          ),
        ],
      ),
    );
  }
}
