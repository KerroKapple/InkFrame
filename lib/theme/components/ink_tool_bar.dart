// InkToolBar：surface 级工具条（44）——比窗口 chrome(56) 矮一档，且【不含】
// DragToMoveArea：工具条上的单击一帧落地，不吃 kDoubleTapTimeout(300ms) 的
// 手势仲裁税（chrome 里的按钮必须 pump(400ms) 才点得动，见 §4.2）。
//
// 下沿用 borderStrong：外壳三段（chrome ↔ 标签条 ↔ 内容）的硬边界都用它，
// 组件内部细线继续用 borderSubtle。
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../tokens.dart';

class InkToolBar extends StatelessWidget {
  const InkToolBar({
    super.key,
    this.leading,
    this.title,
    this.actions = const <Widget>[],
  });

  /// 与 ink_window_chrome.dart:28 的 height:56 同例：具名常量，不进无内联样式规则面。
  static const double height = 44;

  final Widget? leading;
  final Widget? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final InkColors colors = context.inkColors;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border(
            bottom: BorderSide(color: colors.borderStrong, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.lg),
          child: Row(
            children: <Widget>[
              ?leading,
              if (leading != null) const SizedBox(width: InkSpacing.sm),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: title ?? const SizedBox.shrink(),
                ),
              ),
              for (final Widget a in actions) ...<Widget>[
                const SizedBox(width: InkSpacing.sm),
                a,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
