// CanvasAppearanceSection — Settings 内画布外观分节。
//
// 连线颜色 / 卡片颜色两组色板（候选来自 InkPalette，见 tokens.dart）+
// 「主题默认」档；接 canvasStyleControllerProvider，选择即持久化。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/canvas_style.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/tokens.dart';

class CanvasAppearanceSection extends ConsumerWidget {
  const CanvasAppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(canvasStyleControllerProvider);
    final controller = ref.read(canvasStyleControllerProvider.notifier);
    final colors = context.inkColors;
    final typo = context.inkTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.settingsCanvasSection,
          style: typo.title.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.sm),
        _ColorRow(
          label: context.l10n.settingsCanvasEdgeColor,
          choices: InkPalette.canvasEdgeColorChoices,
          selected: style.edgeColor,
          onSelect: controller.setEdgeColor,
        ),
        const SizedBox(height: InkSpacing.md),
        _ColorRow(
          label: context.l10n.settingsCanvasCardColor,
          choices: InkPalette.canvasCardColorChoices,
          selected: style.cardColor,
          onSelect: controller.setCardColor,
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.label,
    required this.choices,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final List<Color> choices;
  final Color? selected;
  final void Function(Color?) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: typo.body.copyWith(color: colors.fg2)),
        const SizedBox(height: InkSpacing.xs),
        Wrap(
          spacing: InkSpacing.sm,
          runSpacing: InkSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final c in choices)
              _Swatch(
                color: c,
                selected: selected == c,
                onTap: () => onSelect(c),
              ),
            InkButton(
              label: context.l10n.settingsCanvasColorDefault,
              onPressed: () => onSelect(null),
              variant: selected == null
                  ? InkButtonVariant.primary
                  : InkButtonVariant.secondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: InkSpacing.xl,
          height: InkSpacing.xl,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colors.brand : colors.border,
              width: selected ? 2.5 : 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
