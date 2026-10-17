// 画布工具的键位常量 + 「此刻是不是在打字」的唯一判据。原在 canvas_shortcuts.dart，搬来后由它
// re-export，工具条 / 左栏导航条 / 菜单等原有 import 路径照常可用。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 画布工具的键位。工具条 tooltip 与快捷键注册表（core_canvas_keys.dart）取同一组常量——改键位
/// 只改这里，tooltip 不会还挂着旧键。
class CanvasToolKeys {
  CanvasToolKeys._();
  static const LogicalKeyboardKey select = LogicalKeyboardKey.keyV;
  static const LogicalKeyboardKey pan = LogicalKeyboardKey.keyH;
  static const LogicalKeyboardKey imageNode = LogicalKeyboardKey.keyI;
  static const LogicalKeyboardKey videoNode = LogicalKeyboardKey.keyG;
  static const LogicalKeyboardKey textNode = LogicalKeyboardKey.keyT;
  static const LogicalKeyboardKey lane = LogicalKeyboardKey.keyF;
  static const LogicalKeyboardKey link = LogicalKeyboardKey.keyL;

  /// 新建…（新建菜单）。空白处右键菜单「新建…」行尾的键位提示也取它。
  static const LogicalKeyboardKey createMenu = LogicalKeyboardKey.tab;

  /// 按住临时平移。不进 kCanvasShortcuts（要按下与松开两个事件，见
  /// _CanvasShortcutsState._onKeyEvent）；设置页清单单独收它
  /// （features/settings/util/shortcut_catalog.dart）。
  static const SingleActivator holdToPan =
      SingleActivator(LogicalKeyboardKey.space);

  /// 左栏开合：macOS 是 ⌘\，其余平台 Ctrl+\。两个变体都进 kCanvasShortcuts（与 ⌘A / Ctrl+A
  /// 同一种双注册）；导航条收起键的 tooltip 按平台取其一出字（shortcut_catalog 的
  /// formatShortcutActivator），所以 tooltip 与绑定、与设置页清单是同一个常量。
  /// includeRepeats: false——按住不放不该来回开合。
  static const SingleActivator toggleLeftRailMeta = SingleActivator(
    LogicalKeyboardKey.backslash,
    meta: true,
    includeRepeats: false,
  );
  static const SingleActivator toggleLeftRailControl = SingleActivator(
    LogicalKeyboardKey.backslash,
    control: true,
    includeRepeats: false,
  );

  /// 生成选中的那一张：macOS ⌘↵，其余平台 Ctrl+↵；两个变体都进 kCanvasShortcuts。
  /// includeRepeats: false——按住不放不该连着提交。
  static const SingleActivator generateMeta = SingleActivator(
    LogicalKeyboardKey.enter,
    meta: true,
    includeRepeats: false,
  );
  static const SingleActivator generateControl = SingleActivator(
    LogicalKeyboardKey.enter,
    control: true,
    includeRepeats: false,
  );

  /// 复制一份：⌘D / Ctrl+D。按住不放不该连复制一串。
  static const SingleActivator duplicateMeta = SingleActivator(
    LogicalKeyboardKey.keyD,
    meta: true,
    includeRepeats: false,
  );
  static const SingleActivator duplicateControl = SingleActivator(
    LogicalKeyboardKey.keyD,
    control: true,
    includeRepeats: false,
  );

  /// 适应全部 / 适应选中：Shift+1 / Shift+2，两个平台同键。
  static const SingleActivator fitAll = SingleActivator(
    LogicalKeyboardKey.digit1,
    shift: true,
    includeRepeats: false,
  );
  static const SingleActivator fitSelection = SingleActivator(
    LogicalKeyboardKey.digit2,
    shift: true,
    includeRepeats: false,
  );
}

/// 主焦点是否落在某个 EditableText 内——用于让文本编辑抢先于画布删除/全选。
/// 用顶层 [primaryFocus] getter（非 FocusManager.instance 静态单例，遵守 DIP 铁律）。
bool isEditingText() {
  final ctx = primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.findAncestorStateOfType<EditableTextState>() != null;
}
