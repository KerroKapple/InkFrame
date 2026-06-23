// 基底风格编辑弹窗：前缀/后缀多行输入 + 快速预设。
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_input.dart';
import '../../../theme/tokens.dart';
import '../util/base_style_presets.dart';

/// 返回用户编辑后的 prefix/suffix 记录；取消则返回 null。
Future<({String prefix, String suffix})?> showBaseStyleEditorDialog(
  BuildContext context, {
  required String prefix,
  required String suffix,
}) {
  return showDialog<({String prefix, String suffix})>(
    context: context,
    builder: (_) => _BaseStyleEditorDialog(prefix: prefix, suffix: suffix),
  );
}

class _BaseStyleEditorDialog extends StatefulWidget {
  const _BaseStyleEditorDialog({
    required this.prefix,
    required this.suffix,
  });

  final String prefix;
  final String suffix;

  @override
  State<_BaseStyleEditorDialog> createState() => _BaseStyleEditorDialogState();
}

class _BaseStyleEditorDialogState extends State<_BaseStyleEditorDialog> {
  late final TextEditingController _prefixCtrl;
  late final TextEditingController _suffixCtrl;

  @override
  void initState() {
    super.initState();
    _prefixCtrl = TextEditingController(text: widget.prefix);
    _suffixCtrl = TextEditingController(text: widget.suffix);
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _suffixCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.inkColors;
    final typography = context.inkTypography;

    return Dialog(
      backgroundColor: colors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InkRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(InkSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Text(
                l10n.baseStyleEditTitle,
                style: typography.title.copyWith(color: colors.fg1),
              ),
              const SizedBox(height: InkSpacing.lg),

              // 前缀输入
              Text(
                l10n.baseStylePrefixLabel,
                style: typography.label.copyWith(color: colors.fg2),
              ),
              const SizedBox(height: InkSpacing.xs),
              InkInput(
                controller: _prefixCtrl,
                hintText: l10n.baseStylePrefixHint,
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: InkSpacing.md),

              // 快速预设
              Text(
                l10n.baseStylePresetsLabel,
                style: typography.label.copyWith(color: colors.fg2),
              ),
              const SizedBox(height: InkSpacing.xs),
              Wrap(
                spacing: InkSpacing.sm,
                runSpacing: InkSpacing.xs,
                children: kBaseStylePresets.map((preset) {
                  return ActionChip(
                    label: Text(_presetLabel(context, preset.id)),
                    onPressed: () {
                      _prefixCtrl.text = preset.prompt;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: InkSpacing.md),

              // 后缀输入
              Text(
                l10n.baseStyleSuffixLabel,
                style: typography.label.copyWith(color: colors.fg2),
              ),
              const SizedBox(height: InkSpacing.xs),
              InkInput(
                controller: _suffixCtrl,
                hintText: l10n.baseStyleSuffixHint,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: InkSpacing.xl),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(l10n.laneDialogCancel),
                  ),
                  const SizedBox(width: InkSpacing.sm),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop((
                      prefix: _prefixCtrl.text.trim(),
                      suffix: _suffixCtrl.text.trim(),
                    )),
                    child: Text(l10n.laneDialogSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 将 preset id 映射到 l10n 标签。
String _presetLabel(BuildContext context, String id) {
  final l10n = AppLocalizations.of(context);
  return switch (id) {
    'cinematic' => l10n.baseStylePresetCinematic,
    'anime' => l10n.baseStylePresetAnime,
    'ghibli' => l10n.baseStylePresetGhibli,
    'cyberpunk' => l10n.baseStylePresetCyberpunk,
    'inkwash' => l10n.baseStylePresetInkwash,
    'photographic' => l10n.baseStylePresetPhoto,
    'anim3d' => l10n.baseStylePreset3d,
    _ => id,
  };
}
