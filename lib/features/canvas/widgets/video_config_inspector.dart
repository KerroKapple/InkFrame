// VideoConfigInspector：单选 video config 节点时展示的参数面板。
//
// 控件：prompt / provider / duration / camera 下拉 + 自动持久化 + 四态状态面板。
// mode（t2v vs i2v）在 GenerationController 根据 incoming data edges 自动推断。
//
// 状态面板复用 InspectorStatusPanel，绑定点与 ImageConfigInspector 一致：
// agent-generation 落 JobState 后改为 `ref.watch(jobStateProvider(node.id))`。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/repositories.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../features/generation/generation_controller.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';
import 'inspector_status_panel.dart';

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
  InspectorJobView _view = const InspectorJobIdle();
  Timer? _promptDebounce;

  static const _debounceDuration = Duration(milliseconds: 500);

  bool get _busy =>
      _view is InspectorJobSubmitting || _view is InspectorJobRunning;

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
    if (prompt.isEmpty || _providerId == null || _busy) return;
    setState(() => _view = const InspectorJobSubmitting());
    try {
      final nodes = await ref.read(nodeRepositoryProvider.future);
      await nodes.patchTypeConfig(widget.node.id, <String, Object?>{
        'prompt': prompt,
        'provider_id': _providerId,
        if (_durationSec != null) 'duration_ms': _durationSec! * 1000,
        if (_camera != null) 'camera': _camera!.name,
      });
      if (!mounted) return;
      setState(() => _view = const InspectorJobRunning());
      final controller = await ref.read(generationControllerProvider.future);
      await controller.submitFromConfigNode(widget.node.id);
      if (!mounted) return;
      // fire-and-forget：提交成功即收起；进度看画布渲染队列面板，
      // 终态结果/失败由 CanvasScreen 的 registry listener 反映（刷新画布 / toast）。
      setState(() => _view = const InspectorJobIdle());
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
            onChanged: _busy
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
                  DropdownMenuItem(
                    value: d,
                    child: Text(context.l10n.inspectorVideoDurationOption(d)),
                  ),
            ],
            onChanged: _busy
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
            onChanged: _busy
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
          _VideoStatusBinding(
            providerId: _providerId,
            promptEmpty: _promptCtrl.text.trim().isEmpty,
            hasApiKeyFuture: _providerId == null
                ? Future<bool>.value(false)
                : _hasApiKey(_providerId!),
            view: _view,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _VideoStatusBinding extends StatelessWidget {
  const _VideoStatusBinding({
    required this.providerId,
    required this.promptEmpty,
    required this.hasApiKeyFuture,
    required this.view,
    required this.onSubmit,
  });

  final String? providerId;
  final bool promptEmpty;
  final Future<bool> hasApiKeyFuture;
  final InspectorJobView view;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasApiKeyFuture,
      builder: (context, snap) {
        final hasKey = snap.data ?? false;
        String? disabledReason;
        if (promptEmpty) {
          disabledReason =
              context.l10n.inspectorVideoGenerateDisabledEmptyPrompt;
        } else if (providerId == null || !hasKey) {
          disabledReason = context.l10n.inspectorVideoGenerateDisabledNoKey;
        }
        final canSubmit = !promptEmpty && providerId != null && hasKey;
        return InspectorStatusPanel(
          view: view,
          generateLabel: context.l10n.inspectorVideoGenerate,
          canSubmit: canSubmit,
          disabledReason: disabledReason,
          onSubmit: onSubmit,
        );
      },
    );
  }
}
