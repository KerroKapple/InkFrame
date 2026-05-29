// SettingsTopChrome：设置页顶栏 —— 复用 InkWindowChrome（含窗口三键）。
// leading=返回 Studio + Ink/Frame 小 logo，center=设置标题。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/current_screen.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/primitives/ink_back_button.dart';
import '../../../theme/tokens.dart';

class SettingsTopChrome extends ConsumerWidget implements PreferredSizeWidget {
  const SettingsTopChrome({super.key});

  static const Key backButtonKey = Key('settings.chrome.back');

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWindowChrome(
      leading: _LeadingRow(
        onBack: () => ref.read(currentScreenProvider.notifier).state =
            AppScreen.studio,
      ),
      center: _Title(title: context.l10n.settingsTitle),
    );
  }
}

class _LeadingRow extends StatelessWidget {
  const _LeadingRow({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final base = typo.headline.copyWith(fontSize: 16, color: colors.fg1);
    return Padding(
      padding: const EdgeInsets.only(right: InkSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkBackButton(
            key: SettingsTopChrome.backButtonKey,
            onBack: onBack,
          ),
          const SizedBox(width: InkSpacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('Ink', style: base),
              Text('/', style: base.copyWith(color: colors.accent)),
              Text('Frame', style: base),
            ],
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    return Text(title, style: typo.body.copyWith(color: colors.fg1));
  }
}
