// 设置「快捷键」页的只读清单：从**真正注册的** Shortcuts 表反推。
//
// 为什么不写死一张展示表：手抄的清单会和绑定分叉——有人改了键位、列表照旧，
// 用户照着列表按一个早就不存在的键。这里的输入就是生产代码里那几张表
// （canvas_shortcuts.dart 的 kCanvasShortcuts、palette_activators.dart 的
// kCommandPaletteActivators、本文件的 kOverlayDismissActivator——设置浮层
// 的 Esc 也从这里取），谁加绑定谁自动上屏。
//
// 新增 Intent 没在 [shortcutActionOf] 认领 ⇒ shortcut_catalog_test 打红；
// 新增按键没在 [_keyLabels] 认领 ⇒ 该动作在某平台出不了键位，同一个测试打红。
//
// 键位符号不进 ARB（与 core/constants/shortcut_labels.dart 同约定）：⌘ / Ctrl
// 是平台符号，翻译它只会制造错误。动作名走 ARB，由呈现层按 [ShortcutAction] 取。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../canvas/widgets/canvas_shortcuts.dart';
import '../../command_palette/palette_activators.dart';

/// 浮层（设置）的关闭键——SettingsScreen 的 CallbackShortcuts 与本清单同源。
const SingleActivator kOverlayDismissActivator =
    SingleActivator(LogicalKeyboardKey.escape);

/// 清单上的动作。声明序 == 列表显示序：全局两条在前，画布六条在后。
enum ShortcutAction {
  commandPalette,
  overlayDismiss,
  canvasDelete,
  canvasEscape,
  canvasSelectAll,
  canvasZoomIn,
  canvasZoomOut,
  canvasZoomReset,
}

/// 画布表里的 Intent → 动作标识；未认领返回 null（测试打红，不静默丢行）。
ShortcutAction? shortcutActionOf(Intent intent) => switch (intent) {
      DeleteSelectionIntent() => ShortcutAction.canvasDelete,
      CanvasEscapeIntent() => ShortcutAction.canvasEscape,
      SelectAllNodesIntent() => ShortcutAction.canvasSelectAll,
      CanvasZoomInIntent() => ShortcutAction.canvasZoomIn,
      CanvasZoomOutIntent() => ShortcutAction.canvasZoomOut,
      CanvasZoomResetIntent() => ShortcutAction.canvasZoomReset,
      _ => null,
    };

/// 一行：一个动作 + 它在当前平台上的全部键位（去重、保持注册序）。
@immutable
class ShortcutRow {
  const ShortcutRow({required this.action, required this.keys});

  final ShortcutAction action;
  final List<String> keys;
}

/// 清单（纯函数，[isMac] 由呈现层按 defaultTargetPlatform 传入，便于两平台都测）。
List<ShortcutRow> buildShortcutRows({required bool isMac}) {
  final Map<ShortcutAction, List<String>> keys =
      <ShortcutAction, List<String>>{};

  void add(ShortcutAction? action, ShortcutActivator activator) {
    if (action == null) return;
    final String? label = formatShortcutActivator(activator, isMac: isMac);
    if (label == null) return;
    final List<String> list =
        keys.putIfAbsent(action, () => <String>[]);
    if (!list.contains(label)) list.add(label);
  }

  for (final SingleActivator a in kCommandPaletteActivators) {
    add(ShortcutAction.commandPalette, a);
  }
  add(ShortcutAction.overlayDismiss, kOverlayDismissActivator);
  kCanvasShortcuts.forEach(
    (ShortcutActivator a, Intent i) => add(shortcutActionOf(i), a),
  );

  return <ShortcutRow>[
    for (final ShortcutAction action in ShortcutAction.values)
      if (keys[action] != null)
        ShortcutRow(action: action, keys: keys[action]!),
  ];
}

/// 激活器 → 本平台展示串；null = 本平台不展示这一条。
///
/// 不展示的三种：另一平台的修饰键变体（Windows 不显示 ⌘）、小键盘 / 同义重复键
/// （⌘+ 与 ⌘= 同一个动作，清单只留主键盘那个）、以及没认领 label 的按键。
String? formatShortcutActivator(
  ShortcutActivator activator, {
  required bool isMac,
}) {
  if (activator is! SingleActivator) return null;
  if (_duplicateTriggerIds.contains(activator.trigger.keyId)) return null;
  if (activator.meta && !isMac) return null;
  if (activator.control && isMac) return null;
  final String? label = _keyLabels[activator.trigger.keyId];
  if (label == null) return null;
  final StringBuffer out = StringBuffer();
  if (activator.meta) out.write('⌘');
  if (activator.control) out.write('Ctrl+');
  if (activator.shift) out.write(isMac ? '⇧' : 'Shift+');
  if (activator.alt) out.write(isMac ? '⌥' : 'Alt+');
  out.write(label);
  return out.toString();
}

// 下面两张表按 keyId 索引而非 LogicalKeyboardKey 本身：该类自定义了 ==，
// Dart 不许把它当 const 集合的键（"does not have a primitive equality"）。

/// 小键盘与同义键：绑定里为了手感全注册了，清单里只留主键盘那一个。
final Set<int> _duplicateTriggerIds = <int>{
  LogicalKeyboardKey.add.keyId,
  LogicalKeyboardKey.numpadAdd.keyId,
  LogicalKeyboardKey.numpadSubtract.keyId,
  LogicalKeyboardKey.numpad0.keyId,
};

/// 按键展示名。刻意不用 LogicalKeyboardKey.keyLabel 兜底：那会把没想过的键
/// （F7 / Home …）静默画上屏，而清单的可信度正来自「每一行都被人看过」。
final Map<int, String> _keyLabels = <int, String>{
  LogicalKeyboardKey.delete.keyId: 'Delete',
  LogicalKeyboardKey.backspace.keyId: 'Backspace',
  LogicalKeyboardKey.escape.keyId: 'Esc',
  LogicalKeyboardKey.keyA.keyId: 'A',
  LogicalKeyboardKey.keyK.keyId: 'K',
  LogicalKeyboardKey.equal.keyId: '=',
  LogicalKeyboardKey.minus.keyId: '-',
  LogicalKeyboardKey.digit0.keyId: '0',
};
