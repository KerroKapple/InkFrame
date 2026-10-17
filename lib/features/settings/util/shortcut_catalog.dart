// 设置「快捷键」页的只读清单：从**真正注册的**绑定反推。
//
// 为什么不写死一张展示表：手抄的清单会和绑定分叉——有人改了键位、列表照旧，
// 用户照着列表按一个早就不存在的键。这里的输入就是生产代码里那几处真相源
// （画布快捷键注册表 canvas_shortcut_registry.dart 的 kCanvasKeyRegistry、palette_activators.dart 的
// kCommandPaletteActivators、本文件的 kOverlayDismissActivator——设置浮层
// 的 Esc 也从这里取），谁加绑定谁自动上屏：动作名、分组都跟着注册表那一条走。
// 画布的「按住空格临时平移」不在注册表里（要按下与松开两个事件，
// 由 CanvasShortcuts 的 onKeyEvent 处理），按键取自它自己用的那个常量
// CanvasToolKeys.holdToPan——与 kOverlayDismissActivator 同一种收法，行排在「平移工具」之后。
//
// 新增按键没在 [_keyLabels] 认领 ⇒ 该动作在某平台出不了键位，shortcut_catalog_test 打红。
//
// 键位符号不进 ARB（与 core/constants/shortcut_labels.dart 同约定）：⌘ / Ctrl
// 是平台符号，翻译它只会制造错误。动作名走 ARB，由呈现层调 [ShortcutRow.label] 取。
//
// 回车按平台换字（[_platformKeyLabels]）：macOS 画 ↵、其余平台写 Enter——与提示词条「生成」按钮尾标
// （submitShortcutLabel：⌘↵ / Ctrl+Enter）同一个拍板，同一个动作在两处不写成两样。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../canvas/widgets/canvas_shortcuts.dart';
import '../../canvas/widgets/shortcuts/canvas_key_binding.dart';
import '../../canvas/widgets/shortcuts/canvas_shortcut_registry.dart';
import '../../command_palette/palette_activators.dart';

/// 浮层（设置）的关闭键——SettingsScreen 的 CallbackShortcuts 与本清单同源。
const SingleActivator kOverlayDismissActivator =
    SingleActivator(LogicalKeyboardKey.escape);

/// 清单里不来自画布注册表的三行的 id。
const String _commandPaletteId = 'commandPalette';
const String _overlayDismissId = 'overlayDismiss';
const String _holdPanId = 'canvasHoldPan';

/// 「按住空格平移」紧跟在这一行之后。
const String _panToolId = 'canvasPanTool';

/// 一行：一个动作（id + 分组 + 文案）+ 它在当前平台上的全部键位（去重、保持注册序）。
@immutable
class ShortcutRow {
  const ShortcutRow({
    required this.id,
    required this.group,
    required this.label,
    required this.keys,
  });

  /// 画布行 = 注册表里的绑定 id；另有 commandPalette / overlayDismiss / canvasHoldPan 三行。
  final String id;
  final ShortcutGroup group;

  /// 动作名（走 ARB）。
  final String Function(AppLocalizations l) label;
  final List<String> keys;
}

/// 清单（纯函数，[isMac] 由呈现层按 defaultTargetPlatform 传入，便于两平台都测）。
///
/// 行序：先 ⌘K、浮层 Esc 两行（group app），再按注册表顺序逐 id 合并（listed == false 的跳过），
/// 「按住空格平移」插在「平移工具」那一行之后（注册表里没有平移工具就排在最后）。
/// 本平台一个键位都出不了字的行不上屏。[registry] 缺省 = kCanvasKeyRegistry（测试可传合成的）。
List<ShortcutRow> buildShortcutRows({
  required bool isMac,
  List<CanvasKeyBinding>? registry,
}) {
  final List<String> order = <String>[];
  final Map<String, ShortcutGroup> groups = <String, ShortcutGroup>{};
  final Map<String, String Function(AppLocalizations l)> labels =
      <String, String Function(AppLocalizations l)>{};
  final Map<String, List<String>> keys = <String, List<String>>{};

  void add(
    String id,
    ShortcutGroup group,
    String Function(AppLocalizations l) label,
    Iterable<ShortcutActivator> activators,
  ) {
    if (!groups.containsKey(id)) {
      order.add(id);
      groups[id] = group;
      labels[id] = label;
    }
    final List<String> list = keys.putIfAbsent(id, () => <String>[]);
    for (final ShortcutActivator a in activators) {
      final String? text = formatShortcutActivator(a, isMac: isMac);
      if (text != null && !list.contains(text)) list.add(text);
    }
  }

  void addHoldPan() => add(
        _holdPanId,
        ShortcutGroup.tools,
        (AppLocalizations l) => l.settingsShortcutCanvasHoldPan,
        const <ShortcutActivator>[CanvasToolKeys.holdToPan],
      );

  add(
    _commandPaletteId,
    ShortcutGroup.app,
    (AppLocalizations l) => l.settingsShortcutCommandPalette,
    kCommandPaletteActivators,
  );
  add(
    _overlayDismissId,
    ShortcutGroup.app,
    (AppLocalizations l) => l.settingsShortcutOverlayDismiss,
    const <ShortcutActivator>[kOverlayDismissActivator],
  );
  bool holdPanAdded = false;
  for (final CanvasKeyBinding b in registry ?? kCanvasKeyRegistry) {
    if (!b.listed) continue;
    add(b.id, b.group, b.label, b.activators);
    if (b.id == _panToolId && !holdPanAdded) {
      addHoldPan();
      holdPanAdded = true;
    }
  }
  if (!holdPanAdded) addHoldPan();

  return <ShortcutRow>[
    for (final String id in order)
      if (keys[id]!.isNotEmpty)
        ShortcutRow(
          id: id,
          group: groups[id]!,
          label: labels[id]!,
          keys: keys[id]!,
        ),
  ];
}

/// 注册表里 [id] 那一条绑定在本平台第一个出得了字的激活器；没有这条绑定 / 一个都出不了字 ⇒ null。
///
/// 菜单行尾、按钮 tooltip 要按 id 取键位时用它（与设置页清单同源）。
ShortcutActivator? canvasBindingActivator(String id, {required bool isMac}) {
  for (final CanvasKeyBinding b in kCanvasKeyRegistry) {
    if (b.id != id) continue;
    for (final ShortcutActivator a in b.activators) {
      if (formatShortcutActivator(a, isMac: isMac) != null) return a;
    }
  }
  return null;
}

/// 注册表里 [id] 那一条绑定在本平台的展示串（取 [canvasBindingActivator] 那一个）；出不了字 ⇒ null。
String? canvasBindingLabel(String id, {required bool isMac}) {
  final ShortcutActivator? a = canvasBindingActivator(id, isMac: isMac);
  return a == null ? null : formatShortcutActivator(a, isMac: isMac);
}

/// [kCanvasShortcuts] 里第一条满足 [matches] 的绑定在本平台的展示串；一条都出不了字 ⇒ null。
///
/// 菜单行尾的键位提示用它（空白处右键菜单的「全选」「适应视图」，节点右键菜单的「生成」「复制一份」
/// 「删除」）：与本清单同源，改了绑定提示跟着变，不会出现菜单上写着一个早就不存在的键。
String? canvasShortcutLabel(
  bool Function(Intent intent) matches, {
  required bool isMac,
}) {
  for (final MapEntry<ShortcutActivator, Intent> e in kCanvasShortcuts.entries) {
    if (!matches(e.value)) continue;
    final String? label = formatShortcutActivator(e.key, isMac: isMac);
    if (label != null) return label;
  }
  return null;
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
  final int keyId = activator.trigger.keyId;
  final ({String mac, String other})? platformLabel = _platformKeyLabels[keyId];
  final String? label = platformLabel == null
      ? _keyLabels[keyId]
      : (isMac ? platformLabel.mac : platformLabel.other);
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
  LogicalKeyboardKey.space.keyId: 'Space',
  // 画布工具单键（CanvasToolKeys）。
  LogicalKeyboardKey.keyV.keyId: 'V',
  LogicalKeyboardKey.keyH.keyId: 'H',
  LogicalKeyboardKey.keyI.keyId: 'I',
  LogicalKeyboardKey.keyG.keyId: 'G',
  LogicalKeyboardKey.keyT.keyId: 'T',
  LogicalKeyboardKey.keyF.keyId: 'F',
  LogicalKeyboardKey.keyL.keyId: 'L',
  // 左栏开合（CanvasToolKeys.toggleLeftRail*）：⌘\ / Ctrl+\。
  LogicalKeyboardKey.backslash.keyId: r'\',
  // 新建…（CanvasToolKeys.createMenu）。
  LogicalKeyboardKey.tab.keyId: 'Tab',
  // 复制一份（CanvasToolKeys.duplicate*）：⌘D / Ctrl+D。
  LogicalKeyboardKey.keyD.keyId: 'D',
  // 适应全部 / 适应选中（CanvasToolKeys.fitAll / fitSelection）：⇧1 / Shift+1、⇧2 / Shift+2。
  LogicalKeyboardKey.digit1.keyId: '1',
  LogicalKeyboardKey.digit2.keyId: '2',
  // 第二批动作的键位（app_actions/planned_keys.dart 的 PlannedKeys）：撤销 / 重做 Z、Y，剪切 / 复制 X、C，
  // 导入媒体 U，便签 N，通知 F6（粘贴 V、包成泳道 G、查找 F 上面已有）。注册表里还没有这些键，快捷键页行集不变；
  // 认领它们是为了动作表的 keyLabel 在菜单栏 / 撤销卡上出得了字。
  LogicalKeyboardKey.keyZ.keyId: 'Z',
  LogicalKeyboardKey.keyY.keyId: 'Y',
  LogicalKeyboardKey.keyX.keyId: 'X',
  LogicalKeyboardKey.keyC.keyId: 'C',
  LogicalKeyboardKey.keyU.keyId: 'U',
  LogicalKeyboardKey.keyN.keyId: 'N',
  LogicalKeyboardKey.f6.keyId: 'F6',
};

/// 按平台换字的按键（同样按 keyId 索引，理由同上）。回车：macOS 画 ↵、其余平台写 Enter——生成选中
/// （CanvasToolKeys.generate*）出来是 ⌘↵ / Ctrl+Enter，与提示词条「生成」按钮尾标（submitShortcutLabel）
/// 一字不差。
final Map<int, ({String mac, String other})> _platformKeyLabels =
    <int, ({String mac, String other})>{
  LogicalKeyboardKey.enter.keyId: (mac: '↵', other: 'Enter'),
};
