// 画布快捷键注册表：CanvasShortcuts 的 Shortcuts / Actions 与设置「快捷键」页的清单都从这里取。
//
// 加键 = 在下面追加一行（一个切片一行），不改 CanvasShortcuts、不改设置页。行序 = 快捷键页的行序。
// 约束（canvas_shortcut_registry_test 钉住）：id 全局唯一；新键 includeRepeats: false；
// 同一 Intent 类型的绑定共用同一个门槛。
import 'canvas_key_binding.dart';
import 'core_canvas_keys.dart';
import 'undo_keys.dart';

/// 画布的全部快捷键绑定。
final List<CanvasKeyBinding> kCanvasKeyRegistry = <CanvasKeyBinding>[
  ...coreCanvasKeys,
  ...undoKeys,
];
