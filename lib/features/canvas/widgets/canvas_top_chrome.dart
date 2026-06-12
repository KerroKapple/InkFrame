// CanvasTopChrome：Canvas 顶栏 —— 复用 InkWindowChrome，三槽位
// leading=Ink/Frame 小 logo，center=breadcrumb，trailing=⌘K + ▶ + avatar。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/shortcut_labels.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_window_chrome.dart';
import '../../../theme/tokens.dart';
import '../../studio/controllers/studio_state.dart';
import '../providers/current_canvas_id.dart';

class CanvasTopChrome extends ConsumerWidget implements PreferredSizeWidget {
  const CanvasTopChrome({super.key, required this.canvasName});

  final String canvasName;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWindowChrome(
      leading: _LeadingRow(
        onBack: () =>
            ref.read(currentCanvasIdProvider.notifier).state = null,
      ),
      center: _Breadcrumb(canvasName: canvasName),
      trailing: const _Trailing(),
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
    final base = typo.headlineXs.copyWith(color: colors.fg1);
    return Padding(
      padding: const EdgeInsets.only(right: InkSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _BackToStudioButton(onBack: onBack),
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

/// 顶栏左上角"回 Studio"入口：箭头 + 文案 chip，悬停 surface3，可键盘聚焦。
class _BackToStudioButton extends StatefulWidget {
  const _BackToStudioButton({required this.onBack});
  final VoidCallback onBack;

  @override
  State<_BackToStudioButton> createState() => _BackToStudioButtonState();
}

class _BackToStudioButtonState extends State<_BackToStudioButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final label = l.canvasBackToStudio;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onBack();
                return null;
              },
            ),
          },
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBack,
              child: AnimatedContainer(
                duration: InkMotion.fast,
                height: 28,
                padding: const EdgeInsets.symmetric(
                  horizontal: InkSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: _hover ? colors.surface3 : colors.surface2,
                  borderRadius: BorderRadius.circular(InkRadius.sm),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.arrow_back, size: 14, color: colors.fg2),
                    const SizedBox(width: InkSpacing.xs),
                    Text(
                      label,
                      style: typo.caption.copyWith(color: colors.fg2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.canvasName});
  final String canvasName;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    final base = typo.body.copyWith(color: colors.fg2);
    final accent = typo.body.copyWith(color: colors.fg1);
    final chev = typo.body.copyWith(color: colors.fg4);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l.canvasBreadcrumbProject, style: base),
          _chev(chev),
          Text(canvasName, style: base),
          _chev(chev),
          Text(l.canvasBreadcrumbCanvas, style: accent),
        ],
      ),
    );
  }

  Widget _chev(TextStyle s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
        child: Text('›', style: s),
      );
}

class _Trailing extends ConsumerWidget {
  const _Trailing();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final studioName =
        ref.watch(currentStudioProvider) ?? context.l10n.studioDefaultName;
    final trimmed = studioName.trim();
    final avatarInitial =
        trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: BorderRadius.circular(InkRadius.sm),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Text(
            commandPaletteShortcutLabel(),
            style: typo.caption.copyWith(color: colors.fg3),
          ),
        ),
        const SizedBox(width: InkSpacing.md),
        Icon(Icons.play_arrow, size: 18, color: colors.fg2),
        const SizedBox(width: InkSpacing.md),
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface3,
            shape: BoxShape.circle,
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Text(
            avatarInitial,
            style: typo.label.copyWith(color: colors.accent),
          ),
        ),
      ],
    );
  }
}
