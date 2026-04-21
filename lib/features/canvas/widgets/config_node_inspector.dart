// ConfigNodeInspector：单选 config 节点时展示的参数面板。
//
// S3b：Generate 按钮真接 GenerationController。流程：
//   1. patchTypeConfig({prompt, provider_id, resolution, aspect_ratio}) 持久化
//   2. controller.submitFromConfigNode(nodeId) 等终态
//   3. 成功 → SnackBar + invalidate 当前画布的 nodesController 拉新 result 节点
//      失败 → SnackBar 展示错误码；预创建的 result 已由 Controller 清理
//
// 按钮 disabled 原因分层（就近原则）：prompt 空 / 无 API Key / 正在运行 / OK。

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

class ConfigNodeInspector extends ConsumerStatefulWidget {
  const ConfigNodeInspector({super.key, required this.node});

  final CanvasNode node;

  @override
  ConsumerState<ConfigNodeInspector> createState() =>
      _ConfigNodeInspectorState();
}

class _ConfigNodeInspectorState extends ConsumerState<ConfigNodeInspector> {
  final TextEditingController _promptCtrl = TextEditingController();
  String? _providerId;
  Resolution? _resolution;
  bool _running = false;
  Timer? _promptDebounce;

  static const _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    final caps = ref.read(providerCapabilitiesListProvider);
    final tc = widget.node.typeConfig;

    // 水化已存在配置；缺失字段回退到 caps 首项。
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
    if (prompt.isEmpty || _providerId == null || _running) return;
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(widget.node.id, <String, Object?>{
        'prompt': prompt,
        'provider_id': _providerId,
        if (_resolution != null) 'resolution': _resolution!.name,
      });
      final controller =
          await ref.read(generationControllerProvider.future);
      final outcome = await controller.submitFromConfigNode(widget.node.id);
      if (!mounted) return;
      if (outcome.succeeded) {
        messenger?.showSnackBar(
          SnackBar(content: Text(context.l10n.generationSuccess)),
        );
        final canvasId = widget.node.canvasId;
        if (canvasId != null) {
          ref.invalidate(canvasNodesControllerProvider(canvasId));
        }
      } else {
        final code = outcome.status.maybeMap(
          failure: (f) => f.error.code.name,
          orElse: () => 'unknown',
        );
        messenger?.showSnackBar(
          SnackBar(
            content: Text('${context.l10n.generationFailure}: $code'),
          ),
        );
      }
    } on MissingApiKeyError {
      messenger?.showSnackBar(
        SnackBar(content: Text(context.l10n.generationMissingKey)),
      );
    } on InvalidGenerationConfigError catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.generationInvalidConfig(e.reason)),
        ),
      );
    } on ProviderNotRegisteredError {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.generationProviderNotRegistered),
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('${context.l10n.generationFailure}: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
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
            onChanged: _running
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
            onChanged: _running
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _resolution = v);
                    _patchTypeConfig(<String, Object?>{'resolution': v.name});
                  },
          ),
          const SizedBox(height: InkSpacing.lg),
          _GenerateButton(
            prompt: _promptCtrl.text,
            providerId: _providerId,
            hasApiKey: _providerId == null
                ? Future<bool>.value(false)
                : _hasApiKey(_providerId!),
            running: _running,
            onPressed: _submit,
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

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.prompt,
    required this.providerId,
    required this.hasApiKey,
    required this.running,
    required this.onPressed,
  });

  final String prompt;
  final String? providerId;
  final Future<bool> hasApiKey;
  final bool running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasApiKey,
      builder: (context, snap) {
        final hasKey = snap.data ?? false;
        final promptEmpty = prompt.trim().isEmpty;

        String? disabledReason;
        if (running) {
          disabledReason = null;
        } else if (promptEmpty) {
          disabledReason = context.l10n.inspectorGenerateDisabledEmptyPrompt;
        } else if (providerId == null || !hasKey) {
          disabledReason = context.l10n.inspectorGenerateDisabledNoKey;
        }

        final enabled =
            !running && !promptEmpty && providerId != null && hasKey;

        final child = running
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.l10n.inspectorGenerate);

        final button = FilledButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        );

        if (disabledReason != null) {
          return Tooltip(message: disabledReason, child: button);
        }
        return button;
      },
    );
  }
}
