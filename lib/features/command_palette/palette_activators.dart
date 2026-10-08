// 命令面板的键位：⌘K / Ctrl+K 的唯一真相源。
//
// 单独一个叶子文件，是为了让设置「快捷键」页能读到真正注册的键位而不必 import
// command_palette_shortcuts.dart（那条链牵进对话框 → 动作表 → shell/studio，
// 与 settings 互相 import 会绕成环；先例 batch_slot_parts.dart / onboarding_anchors.dart）。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// ⌘ 与 Ctrl 变体同时注册，跨平台一致（桌面 macOS/Windows）。
const List<SingleActivator> kCommandPaletteActivators = <SingleActivator>[
  SingleActivator(LogicalKeyboardKey.keyK, meta: true),
  SingleActivator(LogicalKeyboardKey.keyK, control: true),
];
