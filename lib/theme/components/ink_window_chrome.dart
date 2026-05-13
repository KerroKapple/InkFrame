// 无边框窗口的自定义标题栏：左/中/右三槽 + 右侧最小化/最大化/关闭按钮。
// 高度固定 56，整条 chrome 提供 DragToMoveArea。
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkWindowChrome extends StatelessWidget {
  const InkWindowChrome({
    super.key,
    this.leading,
    this.center,
    this.trailing,
  });

  final Widget? leading;
  final Widget? center;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    return SizedBox(
      height: 56,
      child: DragToMoveArea(
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceCanvas,
            border: Border(
              bottom: BorderSide(color: colors.borderSubtle, width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.lg),
          child: Row(
            children: <Widget>[
              ?leading,
              Expanded(
                child: Center(child: center ?? const SizedBox.shrink()),
              ),
              ?trailing,
              const SizedBox(width: InkSpacing.md),
              const _WindowButtons(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _WinIconButton(
          icon: Icons.remove,
          onPressed: () => windowManager.minimize(),
        ),
        _WinIconButton(
          icon: Icons.crop_square,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WinIconButton(
          icon: Icons.close,
          onPressed: () => windowManager.close(),
          danger: true,
        ),
      ],
    );
  }
}

class _WinIconButton extends StatefulWidget {
  const _WinIconButton({
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  State<_WinIconButton> createState() => _WinIconButtonState();
}

class _WinIconButtonState extends State<_WinIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    final Color bg = _hover
        ? (widget.danger ? colors.danger : colors.surface3)
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: InkMotion.fast,
          width: 40,
          height: 32,
          color: bg,
          child: Center(
            child: Icon(widget.icon, size: 14, color: colors.fg2),
          ),
        ),
      ),
    );
  }
}
