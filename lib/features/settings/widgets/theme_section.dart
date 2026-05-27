// ThemeSection — Settings 内主题分节。
//
// 三态变体（dark / light / highContrast）+ textScale 滑块；接
// themeModeControllerProvider。高对比度走 setHighContrast，前两种走
// setPreference 并清除高对比度，互斥呈现。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/theme.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/tokens.dart';

class ThemeSection extends ConsumerWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(themeModeControllerProvider);
    final controller = ref.read(themeModeControllerProvider.notifier);
    final colors = context.inkColors;
    final typo = context.inkTypography;

    void selectVariant(InkThemeVariant v) {
      switch (v) {
        case InkThemeVariant.dark:
          controller
            ..setHighContrast(false)
            ..setPreference(ThemePreference.dark);
        case InkThemeVariant.light:
          controller
            ..setHighContrast(false)
            ..setPreference(ThemePreference.light);
        case InkThemeVariant.highContrast:
          controller.setHighContrast(true);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsThemeSection,
          style: typo.title.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.sm),
        Wrap(
          spacing: InkSpacing.sm,
          children: <Widget>[
            _ChoiceButton(
              label: context.l10n.settingsThemeDark,
              selected: state.variant == InkThemeVariant.dark,
              onPressed: () => selectVariant(InkThemeVariant.dark),
            ),
            _ChoiceButton(
              label: context.l10n.settingsThemeLight,
              selected: state.variant == InkThemeVariant.light,
              onPressed: () => selectVariant(InkThemeVariant.light),
            ),
            _ChoiceButton(
              label: context.l10n.settingsThemeHighContrast,
              selected: state.variant == InkThemeVariant.highContrast,
              onPressed: () => selectVariant(InkThemeVariant.highContrast),
            ),
          ],
        ),
        const SizedBox(height: InkSpacing.lg),
        Text(
          context.l10n.settingsThemeTextScale,
          style: typo.body.copyWith(color: colors.fg2),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: Slider(
                value: state.textScale,
                min: 0.85,
                max: 1.40,
                divisions: 11,
                label: state.textScale.toStringAsFixed(2),
                onChanged: controller.setTextScale,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                state.textScale.toStringAsFixed(2),
                style: typo.body.copyWith(color: colors.fg2),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkButton(
      label: label,
      onPressed: onPressed,
      variant:
          selected ? InkButtonVariant.primary : InkButtonVariant.secondary,
    );
  }
}
