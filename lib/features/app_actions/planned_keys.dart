// 第二批动作的键位（KeyMap ›「组合键」）：撤销 / 重做已接上（canvas/widgets/shortcuts/undo_keys.dart 与动作表都引用这里），其余还没接上，键位先定在这里。
//
// 这是它们的唯一出处：动作表（app_action_catalog.dart）的占位行、后续切片注册真绑定、菜单栏 / 快捷键页显示
// 键位，一律引用这里的常量，不再手写第二份——改键位只改一处。
//
// 每个动作每个平台只有一个主键（菜单、快捷键页、撤销卡显示同一串）。重做是唯一两平台不同键的：Windows
// Ctrl+Y、macOS ⇧⌘Z（critic 第二节第 12 条；KeyMap「重做每平台只注册一个」）。
// 全部 includeRepeats: false——按住不放不该连撤销一串、连粘贴一摞。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 第二批动作的键位常量。字段名写死，后续切片按名字引用。
abstract final class PlannedKeys {
  /// 撤销：⌘Z / Ctrl+Z。
  static const SingleActivator undoMac =
      SingleActivator(LogicalKeyboardKey.keyZ, meta: true, includeRepeats: false);
  static const SingleActivator undoOther =
      SingleActivator(LogicalKeyboardKey.keyZ, control: true, includeRepeats: false);

  /// 重做：macOS ⇧⌘Z，Windows Ctrl+Y（两平台不同键，各只一个）。
  static const SingleActivator redoMac = SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
    shift: true,
    includeRepeats: false,
  );
  static const SingleActivator redoOther =
      SingleActivator(LogicalKeyboardKey.keyY, control: true, includeRepeats: false);

  /// 剪切：⌘X / Ctrl+X。
  static const SingleActivator cutMac =
      SingleActivator(LogicalKeyboardKey.keyX, meta: true, includeRepeats: false);
  static const SingleActivator cutOther =
      SingleActivator(LogicalKeyboardKey.keyX, control: true, includeRepeats: false);

  /// 复制：⌘C / Ctrl+C。
  static const SingleActivator copyMac =
      SingleActivator(LogicalKeyboardKey.keyC, meta: true, includeRepeats: false);
  static const SingleActivator copyOther =
      SingleActivator(LogicalKeyboardKey.keyC, control: true, includeRepeats: false);

  /// 粘贴：⌘V / Ctrl+V。
  static const SingleActivator pasteMac =
      SingleActivator(LogicalKeyboardKey.keyV, meta: true, includeRepeats: false);
  static const SingleActivator pasteOther =
      SingleActivator(LogicalKeyboardKey.keyV, control: true, includeRepeats: false);

  /// 查找：⌘F / Ctrl+F。
  static const SingleActivator findMac =
      SingleActivator(LogicalKeyboardKey.keyF, meta: true, includeRepeats: false);
  static const SingleActivator findOther =
      SingleActivator(LogicalKeyboardKey.keyF, control: true, includeRepeats: false);

  /// 导入媒体：⌘U / Ctrl+U。
  static const SingleActivator importMediaMac =
      SingleActivator(LogicalKeyboardKey.keyU, meta: true, includeRepeats: false);
  static const SingleActivator importMediaOther =
      SingleActivator(LogicalKeyboardKey.keyU, control: true, includeRepeats: false);

  /// 包成泳道：⌘G / Ctrl+G。
  static const SingleActivator wrapInLaneMac =
      SingleActivator(LogicalKeyboardKey.keyG, meta: true, includeRepeats: false);
  static const SingleActivator wrapInLaneOther =
      SingleActivator(LogicalKeyboardKey.keyG, control: true, includeRepeats: false);

  /// 便签：N，不带修饰键，两平台同一个。
  static const SingleActivator newNote =
      SingleActivator(LogicalKeyboardKey.keyN, includeRepeats: false);

  /// 焦点移到通知：F6，两平台同一个。
  static const SingleActivator focusNotifications =
      SingleActivator(LogicalKeyboardKey.f6, includeRepeats: false);
}
