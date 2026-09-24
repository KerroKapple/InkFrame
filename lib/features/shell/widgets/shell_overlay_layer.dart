// 浮层层：盖在标签宿主之上的那一层（Stack 的上层子）。
//
// 【浮层不保活】——overlay == null 时这一层根本不在树里，关掉即销毁。于是
// find.byType(SettingsScreen, skipOffstage: false) → findsNothing 是真断言，
// StoragePathSection 的 pending frame / ffmpeg 探测 / api-key 探测不会在后台常驻。
//
// 浮层刻意在 chrome【之下】、内容区【之内】：设置因此继承外壳的 DragToMoveArea
// 与三个窗口按钮（D6，Windows 无边框 bug 的修法）。标签条在浮层打开时仍可见、
// 仍可点——点任一标签 = goTab = 关浮层 + 切标签。
//
// ModalBarrier 是「底下的标签体不会被点穿」这条保证的来源（以前是 IndexedStack
// 只命中 index 子）：它铺满整层、吃掉全部指针，颜色是稿的 rgba(10,10,10,.55) 遮罩。
// 点遮罩不关浮层——设置里可能有没提交的输入，关闭只走 Esc / ✕ / 完成 / 点标签。
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../settings/settings_screen.dart';
import '../../showcase/widgets/built_in_showcase_screen.dart';
import '../models/shell_state.dart';

class ShellOverlayLayer extends StatelessWidget {
  const ShellOverlayLayer({super.key, required this.overlay});

  final ShellOverlay overlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ModalBarrier(dismissible: false, color: context.inkColors.scrim),
        switch (overlay) {
          ShellOverlay.settings => const SettingsScreen(),
          ShellOverlay.showcase => const BuiltInShowcaseScreen(),
        },
      ],
    );
  }
}
