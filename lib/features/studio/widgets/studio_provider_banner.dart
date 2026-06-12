// StudioProviderBanner：未配置任何 provider API key 时的软提示横幅。
//
// 取代已移除的首屏 Lock 硬门——用户可自由进入 Studio/画布探索，仅在尚未配置
// key 时给一条非阻塞提示，点击跳 Settings 配置。配置后（anyProviderKeyConfigured
// 为 true）自动隐藏。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/current_screen.dart';
import '../../../core/di/secure_storage.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/primitives/ink_ghost_button.dart';
import '../../../theme/tokens.dart';

class StudioProviderBanner extends ConsumerWidget {
  const StudioProviderBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(anyProviderKeyConfiguredProvider);
    // 未就绪 / 出错 / 已配置 → 不显示；仅在确定未配置时提示。
    final showBanner = configured.maybeWhen(
      data: (has) => !has,
      orElse: () => false,
    );
    if (!showBanner) return const SizedBox.shrink();

    final colors = context.inkColors;
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      label: l.studioNoKeyBannerText,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          InkSpacing.lg, InkSpacing.md, InkSpacing.lg, 0),
        padding: const EdgeInsets.symmetric(
          horizontal: InkSpacing.md, vertical: InkSpacing.s10),
        decoration: BoxDecoration(
          color: colors.surface2,
          border: Border.all(color: colors.warning, width: 1),
          borderRadius: BorderRadius.circular(InkRadius.md),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.studioNoKeyBannerText,
                style: context.inkTypography.body.copyWith(color: colors.fg1),
              ),
            ),
            const SizedBox(width: InkSpacing.md),
            InkGhostButton(
              label: l.studioNoKeyBannerAction,
              onPressed: () => ref.read(currentScreenProvider.notifier).state =
                  AppScreen.settings,
            ),
          ],
        ),
      ),
    );
  }
}
