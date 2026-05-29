// InkBackButton：顶栏左上角"回 Studio"入口 —— 箭头 + 文案 chip。
// 悬停 surface3，可键盘聚焦（Enter/Space）。Canvas / Settings 顶栏共用。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n_x.dart';
import '../app_theme.dart';
import '../tokens.dart';

class InkBackButton extends StatefulWidget {
  const InkBackButton({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<InkBackButton> createState() => _InkBackButtonState();
}

class _InkBackButtonState extends State<InkBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.inkColors;
    final typo = context.inkTypography;
    final l = context.l10n;
    return Semantics(
      button: true,
      label: l.workspaceBackToWorkspace,
      child: Tooltip(
        message: l.workspaceBackToWorkspace,
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
                padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
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
                      l.canvasBackToStudio,
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
