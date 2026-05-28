// LanguageSection — Settings 内语言分节。
//
// 两个选项 en / zh-CN。null 状态保留为"跟随系统"（暗示用，不在 UI 中暴露
// 第三个按钮——任务范围只给 en + zh-CN）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/locale.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_button.dart';
import '../../../theme/tokens.dart';

class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeControllerProvider);
    final controller = ref.read(localeControllerProvider.notifier);
    final colors = context.inkColors;
    final typo = context.inkTypography;

    final activeCode = current?.languageCode ??
        Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.settingsLanguageSection,
          style: typo.title.copyWith(color: colors.fg1),
        ),
        const SizedBox(height: InkSpacing.sm),
        Wrap(
          spacing: InkSpacing.sm,
          children: <Widget>[
            _LangButton(
              label: context.l10n.settingsLanguageEn,
              selected: activeCode == 'en',
              onPressed: () => controller.setLocale(const Locale('en')),
            ),
            _LangButton(
              label: context.l10n.settingsLanguageZh,
              selected: activeCode == 'zh',
              onPressed: () => controller.setLocale(const Locale('zh')),
            ),
          ],
        ),
      ],
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
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
