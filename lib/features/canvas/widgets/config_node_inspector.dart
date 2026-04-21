// ConfigNodeInspector：单选 config 节点时展示的参数面板。
//
// S2a 范围：shell 骨架 + Prompt 输入 + Provider/Resolution 下拉 + Generate 按钮。
// 按钮先 disabled（原因视 prompt 空 / 无 API Key / S3 未接 wire 依次择一）。
// Prompt 目前只在 Inspector 局部 state 存活——持久化到 node.type_config
// 留给 S3 GenerationController 落地。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/secure_storage_keys.dart';
import '../../../core/di/providers.dart';
import '../../../core/di/secure_storage.dart';
import '../../../core/models/provider_capabilities.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../models/canvas_node.dart';

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
            onChanged: (v) {
              if (v == null) return;
              final next = caps.firstWhere((c) => c.providerId == v);
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
            onChanged: (v) => setState(() => _resolution = v),
          ),
          const SizedBox(height: InkSpacing.lg),
          _GenerateButton(
            prompt: _promptCtrl.text,
            providerId: _providerId,
            hasApiKey: _providerId == null
                ? Future<bool>.value(false)
                : _hasApiKey(_providerId!),
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
  });

  final String prompt;
  final String? providerId;
  final Future<bool> hasApiKey;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: hasApiKey,
      builder: (context, snap) {
        final hasKey = snap.data ?? false;
        final promptEmpty = prompt.trim().isEmpty;
        String? disabledReason;
        if (promptEmpty) {
          disabledReason = context.l10n.inspectorGenerateDisabledEmptyPrompt;
        } else if (providerId == null) {
          disabledReason = context.l10n.inspectorGenerateDisabledNoKey;
        } else if (!hasKey) {
          disabledReason = context.l10n.inspectorGenerateDisabledNoKey;
        } else {
          disabledReason = context.l10n.inspectorGenerateNotWiredYet;
        }

        return Tooltip(
          message: disabledReason,
          child: FilledButton(
            onPressed: null,
            child: Text(context.l10n.inspectorGenerate),
          ),
        );
      },
    );
  }
}
