// ImageConfigInspector：单选 image config 节点时展示的参数面板。
//
// 提交流程：patch 节点 type_config → GenerationController.submitFromConfigNode
// → 终态写回。状态由 InspectorStatusPanel 四态渲染（idle / submitting /
// running / error）。
//
// JobState 绑定点（agent-generation slice 落地后接线）：
//   features/generation/models/job_state.dart 提供 JobState 后，
//   本地 _view 应被 `ref.watch(jobStateProvider(node.id))` 派生的 view 替换；
//   _submit 拆分为 controller.submit（提交） + jobs 的进度订阅。
//
// 按钮 disabled 原因分层（就近原则）：prompt 空 / 无 API Key / 正在运行。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/repositories.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/models/job_status.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../features/generation/generation_controller.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_edge.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_edges_controller.dart';
import '../providers/canvas_nodes_controller.dart';
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
  InspectorJobView _view = const InspectorJobIdle();
  Timer? _promptDebounce;

  static const _debounceDuration = Duration(milliseconds: 500);

  bool get _busy =>
      _view is InspectorJobSubmitting || _view is InspectorJobRunning;

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
    _promptDebounce?.cancel();
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

  Future<void> _patchTypeConfig(Map<String, Object?> patch) async {
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(widget.node.id, patch);
    } catch (_) {
      // 静默——单次保存失败不打断用户输入流。下次保存会覆盖。
    }
  }

  void _onPromptChanged(String value) {
    setState(() {});
    _promptDebounce?.cancel();
    _promptDebounce = Timer(_debounceDuration, () {
      _patchTypeConfig(<String, Object?>{'prompt': value});
    });
  }

  ProviderCapabilities? _selectedCaps(List<ProviderCapabilities> all) {
    if (_providerId == null) return null;
    return all.firstWhere(
      (c) => c.providerId == _providerId,
      orElse: () => all.first,
    );
  }

  Future<bool> _hasApiKey(String providerId) async {
    final secure = ref.read(secureStorageServiceProvider);
    return secure.exists(SecureStorageKeys.providerApiKey(providerId));
  }

  Future<void> _submit() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty || _providerId == null || _busy) return;
    setState(() => _view = const InspectorJobSubmitting());
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(widget.node.id, <String, Object?>{
        'prompt': prompt,
        'provider_id': _providerId,
        if (_resolution != null) 'resolution': _resolution!.name,
      });
      if (!mounted) return;
      setState(() => _view = const InspectorJobRunning());
      final controller =
          await ref.read(generationControllerProvider.future);
      final outcome = await controller.submitFromConfigNode(widget.node.id);
      if (!mounted) return;
      if (outcome.succeeded) {
        setState(() => _view = const InspectorJobIdle());
        final canvasId = widget.node.canvasId;
        if (canvasId != null) {
          ref.invalidate(canvasNodesControllerProvider(canvasId));
        }
      } else {
        final code = outcome.status.maybeMap(
          failure: (f) => f.error.code.name,
          orElse: () => 'unknown',
        );
        setState(() => _view = InspectorJobError(code: code));
      }
    } on MissingApiKeyError {
      if (mounted) {
        setState(() => _view = const InspectorJobError(code: 'missingApiKey'));
      }
    } on InvalidGenerationConfigError catch (e) {
      if (mounted) {
        setState(() =>
            _view = InspectorJobError(code: 'invalidConfig: ${e.reason}'));
      }
    } on ProviderNotRegisteredError {
      if (mounted) {
        setState(() =>
            _view = const InspectorJobError(code: 'providerNotRegistered'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _view = InspectorJobError(code: e.toString()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = ref.watch(providerCapabilitiesListProvider);
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final selected = _selectedCaps(caps);

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
                  child: Text(c.providerId),
                ),
            ],
            onChanged: _busy
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
                    _patchTypeConfig(<String, Object?>{
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
            onChanged: _busy
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _resolution = v);
                    _patchTypeConfig(<String, Object?>{'resolution': v.name});
                  },
          ),
          const SizedBox(height: InkSpacing.lg),
          _StatusBinding(
            providerId: _providerId,
            promptEmpty: _promptCtrl.text.trim().isEmpty,
            hasApiKeyFuture: _providerId == null
                ? Future<bool>.value(false)
                : _hasApiKey(_providerId!),
            view: _view,
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

/// 包一层 FutureBuilder 解析 API Key 存在性，再委托 InspectorStatusPanel。
/// image / video Inspector 复用，逻辑等价。
class _StatusBinding extends StatelessWidget {
  const _StatusBinding({
    required this.providerId,
    required this.promptEmpty,
    required this.hasApiKeyFuture,
    required this.view,
    required this.generateLabel,
    required this.disabledEmptyPromptText,
    required this.disabledNoKeyText,
    required this.onSubmit,
  });

  final String? providerId;
  final bool promptEmpty;
  final Future<bool> hasApiKeyFuture;
  final InspectorJobView view;
  final String generateLabel;
  final String disabledEmptyPromptText;
  final String disabledNoKeyText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasApiKeyFuture,
      builder: (context, snap) {
        final hasKey = snap.data ?? false;
        String? disabledReason;
        if (promptEmpty) {
          disabledReason = disabledEmptyPromptText;
        } else if (providerId == null || !hasKey) {
          disabledReason = disabledNoKeyText;
        }
        final canSubmit = !promptEmpty && providerId != null && hasKey;
        return InspectorStatusPanel(
          view: view,
          generateLabel: generateLabel,
          canSubmit: canSubmit,
          disabledReason: disabledReason,
          onSubmit: onSubmit,
        );
      },
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
