// ConfigNodeInspector：单选 config 节点时展示的参数面板。
//
// S3b：Generate 按钮真接 GenerationController。流程：
//   1. patchTypeConfig({prompt, provider_id, resolution, aspect_ratio}) 持久化
//   2. controller.submitFromConfigNode(nodeId) 等终态
//   3. 成功 → SnackBar + invalidate 当前画布的 nodesController 拉新 result 节点
//      失败 → SnackBar 展示错误码；预创建的 result 已由 Controller 清理
//
// 按钮 disabled 原因分层（就近原则）：prompt 空 / 无 API Key / 正在运行 / OK。

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
import '../models/canvas_node.dart';
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

  @override
  void initState() {
    super.initState();
    final caps = ref.read(providerCapabilitiesListProvider);
    if (caps.isNotEmpty) {
      _providerId = caps.first.providerId;
      _resolution = caps.first.supportedResolutions.isNotEmpty
          ? caps.first.supportedResolutions.first
          : null;
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
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
            onChanged: (_) => setState(() {}),
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
                    setState(() {
                      _providerId = v;
                      _resolution = next.supportedResolutions.isNotEmpty
                          ? next.supportedResolutions.first
                          : null;
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
            onChanged: _running ? null : (v) => setState(() => _resolution = v),
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
