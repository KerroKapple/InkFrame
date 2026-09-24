// 无 Key 引导条（Screens 稿第 1 屏）：标签栏下方整宽条，accentWash 底 + 1px 下沿，
// padding 10 20，gap 12：琥珀等宽「!」+ 正文 + 弱化说明 + 撑开 +「前往设置」（accentWashBorder 边）+ ✕。
//
// 「前往设置」打开现有设置层（ShellOverlay.settings）；设置浮层形态做完后行为自动跟上（PR #235）。
// ✕ 只在本次进程内收起（keepAlive 的 bool），下次启动仍提示——这是新用户唯一的引导路径，不弱化。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/secure_storage.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/shell_controller.dart';

/// 本次进程内用户点过 ✕。
final studioKeyBannerDismissedProvider = StateProvider<bool>(
  (ref) => false,
  name: 'studioKeyBannerDismissedProvider',
);

class StudioProviderBanner extends ConsumerWidget {
  const StudioProviderBanner({super.key});

  static const Key actionKey = Key('studio.keyBanner.action');
  static const Key dismissKey = Key('studio.keyBanner.dismiss');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(anyProviderKeyConfiguredProvider);
    final bool showBanner = configured.maybeWhen(data: (bool has) => !has, orElse: () => false);
    if (!showBanner || ref.watch(studioKeyBannerDismissedProvider)) return const SizedBox.shrink();

    final c = context.inkColors;
    final t = context.inkTypography;
    final l = context.l10n;
    return Semantics(
      liveRegion: true,
      label: l.studioNoKeyBannerText,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s20, vertical: InkSpacing.s10),
        decoration: BoxDecoration(
          color: c.accentWash,
          border: Border(bottom: BorderSide(color: c.borderStrong)),
        ),
        child: Row(
          children: <Widget>[
            Text('!', style: t.mono.copyWith(color: c.accent)),
            const SizedBox(width: InkSpacing.s12),
            Flexible(
              child: Text(l.studioNoKeyBannerText, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: c.fg1)),
            ),
            const SizedBox(width: InkSpacing.s12),
            Flexible(
              child: Text(l.studioNoKeyBannerHint, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: c.fg5)),
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: l.studioNoKeyBannerAction,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: actionKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(shellControllerProvider.notifier).openOverlay(ShellOverlay.settings),
                  child: Container(
                    height: 26, // content 24 + border 2
                    padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: c.accentWashBorder),
                      borderRadius: BorderRadius.circular(InkRadius.s3),
                    ),
                    child: Text(l.studioNoKeyBannerAction, style: t.body.copyWith(color: c.fg1)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: InkSpacing.s12),
            Semantics(
              button: true,
              label: l.studioNoKeyBannerDismiss,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  key: dismissKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(studioKeyBannerDismissedProvider.notifier).state = true,
                  child: Text('✕', style: t.body.copyWith(color: c.fg5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
