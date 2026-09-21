// 浮层槽：外层 IndexedStack 的第 2 槽。
//
// 【浮层不保活】——overlay == null 时这一槽是 const SizedBox.shrink()，关掉即
// 销毁。于是 find.byType(SettingsScreen, skipOffstage: false) → findsNothing 是
// 真断言，StoragePathSection 的 pending frame / ffmpeg 探测 / api-key 探测不会
// 在后台常驻。
//
// 浮层刻意在 chrome【之下】、内容区【之内】：设置因此继承外壳的 DragToMoveArea
// 与三个窗口按钮（D6，Windows 无边框 bug 的修法）。标签条在浮层打开时仍可见、
// 仍可点——点任一标签 = goTab = 关浮层 + 切标签。
import 'package:flutter/material.dart';

import '../../settings/settings_screen.dart';
import '../../showcase/widgets/built_in_showcase_screen.dart';
import '../models/shell_state.dart';

class ShellOverlayLayer extends StatelessWidget {
  const ShellOverlayLayer({super.key, required this.overlay});

  final ShellOverlay overlay;

  @override
  Widget build(BuildContext context) => switch (overlay) {
        ShellOverlay.settings => const SettingsScreen(),
        ShellOverlay.showcase => const BuiltInShowcaseScreen(),
      };
}
