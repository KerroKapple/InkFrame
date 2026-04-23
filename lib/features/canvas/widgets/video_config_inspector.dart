// VideoConfigInspector：单选 video config 节点时展示的参数面板。
//
// 控件：prompt / provider 下拉 / duration 下拉 / camera 下拉 / 自动持久化 / Generate。
// 按钮 disabled 原因分层（就近）：prompt 空 / 无 API Key / 正在运行 / OK。
// mode（t2v vs i2v）在 GenerationController 根据 incoming data edges 自动推断。

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
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';

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
  bool _running = false;
  Timer? _promptDebounce;

  static const _debounceDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    final caps = _videoCaps();
    final tc = widget.node.typeConfig;

    final savedProviderId = tc['provider_id'] as String?;
    _providerId =
        savedProviderId ?? (caps.isNotEmpty ? caps.first.providerId : null);
    final selected = _selectedCaps(caps);
    final savedDurMs = tc['duration_ms'];
    _durationSec = savedDurMs is int
        ? savedDurMs ~/ 1000
        : (selected != null && selected.supportedDurations.isNotEmpty
            ? selected.supportedDurations.first
            : null);
    _camera = _parseCamera(tc['camera']) ??
        (selected != null && selected.supportedCameras.isNotEmpty
            ? selected.supportedCameras.first
            : null);
    final savedPrompt = tc['prompt'];
    if (savedPrompt is String) _promptCtrl.text = savedPrompt;
  }

  @override
  void dispose() {
    _promptDebounce?.cancel();
    _promptCtrl.dispose();
    super.dispose();
  }

  List<ProviderCapabilities> _videoCaps() => ref
      .read(providerCapabilitiesListProvider)
      .where((c) =>
          c.modes.contains(GenerationMode.textToVideo) ||
          c.modes.contains(GenerationMode.imageToVideo))
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

  Future<void> _patchTypeConfig(Map<String, Object?> patch) async {
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(widget.node.id, patch);
    } catch (_) {
      // 静默——下次覆盖
    }
  }

  void _onPromptChanged(String value) {
    setState(() {});
    _promptDebounce?.cancel();
    _promptDebounce = Timer(_debounceDuration, () {
      _patchTypeConfig(<String, Object?>{'prompt': value});
    });
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
        if (_durationSec != null) 'duration_ms': _durationSec! * 1000,
        if (_camera != null) 'camera': _camera!.name,
      });
      final controller = await ref.read(generationControllerProvider.future);
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
    final caps = _videoCaps();
    final selected = _selectedCaps(caps);
    final colors = context.inkColors;
    final typo = context.inkTypography;

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
                  child: Text(c.providerId),
                ),
            ],
            onChanged: _running
                ? null
                : (v) {
                    if (v == null) return;
                    final next =
                        caps.firstWhere((c) => c.providerId == v);
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
                    _patchTypeConfig(<String, Object?>{
                      'provider_id': v,
                      if (newDuration != null)
                        'duration_ms': newDuration * 1000,
                      if (newCamera != null) 'camera': newCamera.name,
                    });
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
                  DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: _running
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _durationSec = v);
                    _patchTypeConfig(
                      <String, Object?>{'duration_ms': v * 1000},
                    );
                  },
          ),
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
              if (selected != null)
                for (final c in selected.supportedCameras)
                  DropdownMenuItem(value: c, child: Text(c.name)),
            ],
            onChanged: _running
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _camera = v);
                    _patchTypeConfig(
                      <String, Object?>{'camera': v.name},
                    );
                  },
          ),
          const SizedBox(height: InkSpacing.md),
          Text(
            context.l10n.inspectorVideoModeAuto,
            style: typo.caption.copyWith(color: colors.fg3),
          ),
          const SizedBox(height: InkSpacing.lg),
          _VideoGenerateButton(
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

class _VideoGenerateButton extends StatelessWidget {
  const _VideoGenerateButton({
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
          disabledReason =
              context.l10n.inspectorVideoGenerateDisabledEmptyPrompt;
        } else if (providerId == null || !hasKey) {
          disabledReason = context.l10n.inspectorVideoGenerateDisabledNoKey;
        }

        final enabled =
            !running && !promptEmpty && providerId != null && hasKey;

        final child = running
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.l10n.inspectorVideoGenerate);

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
