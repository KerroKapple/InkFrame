// 快捷键展示文案：按平台返回修饰键符号（macOS=⌘，其余=Ctrl）。
// 仅做展示，不参与按键绑定；快捷键符号不进 ARB。
import 'package:flutter/foundation.dart';

/// 命令面板（Cmd/Ctrl + K）chip 的展示文案。
String commandPaletteShortcutLabel() =>
    defaultTargetPlatform == TargetPlatform.macOS ? '⌘ K' : 'Ctrl K';
