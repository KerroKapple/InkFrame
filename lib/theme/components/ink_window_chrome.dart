// 无边框窗口的菜单栏（Workspace v2 稿：30px + 1px 下沿 = 31）：左 / 中 / 右三槽。
// 窗口控制按钮按平台惯例：macOS 用原生红绿灯（leading 让位 78），其余平台自绘右侧三键 46×30。
//
// DragToMoveArea 只包 leading + center（Logo、菜单项与空白区）；trailing（⌘K 入口等）
// 与窗口三键在拖拽区之外——它们是可点控件，不该吃 kDoubleTapTimeout 的 300ms 仲裁。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../l10n/l10n_x.dart';
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

  /// 稿是 content-box：height 30 + border-bottom 1。
  static const double height = 31;

  /// macOS 红绿灯让位（README §4）。
  static const double macTrafficLightInset = 78;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface4,
          border: Border(bottom: BorderSide(color: colors.borderStrong)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: InkSpacing.s12),
                  child: Row(
                    children: <Widget>[
                      if (isMac) const SizedBox(width: macTrafficLightInset),
                      ?leading,
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: center ?? const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ?trailing,
            if (!isMac) const _WindowButtons() else const SizedBox(width: InkSpacing.s12),
          ],
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
          semanticLabel: context.l10n.windowMinimize,
          onPressed: () => windowManager.minimize(),
        ),
        _WinIconButton(
          icon: Icons.crop_square,
          semanticLabel: context.l10n.windowMaximize,
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
          semanticLabel: context.l10n.windowClose,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WinIconButton extends StatefulWidget {
  const _WinIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  State<_WinIconButton> createState() => _WinIconButtonState();
}

class _WinIconButtonState extends State<_WinIconButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: InkMotion.fast,
            width: 46,
            height: 30,
            // 语义色不做容器底色：关闭键悬停同样用 surface5。
            color: _hover ? colors.surface5 : Colors.transparent,
            child: Center(
              child: Icon(widget.icon, size: 14, color: colors.fg3),
            ),
          ),
        ),
      ),
    );
  }
}
