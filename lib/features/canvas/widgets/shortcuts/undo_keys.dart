// 撤销 / 重做的快捷键（注册表 kCanvasKeyRegistry 的一段）：Windows Ctrl Z · Ctrl Y，macOS ⌘Z · ⇧⌘Z。
//
// 激活器不另抄：直接引用 app_actions/planned_keys.dart 的 PlannedKeys（键位常量的唯一出处，动作表的撤销 / 重做行
// 用的是同一组对象）。与其他画布键一样 ⌘ / Ctrl 双注册：
//   - 撤销 = ⌘Z、Ctrl+Z；重做 = ⇧⌘Z（macOS 主键）、Ctrl+Y（Windows 主键）。
//   - 不注册 Ctrl+Shift+Z / ⌘Y：重做每平台只认一个主键（KeyMap）。双注册的代价是 macOS 上 Ctrl+Y 也会重做（不展示）。
//   - 快捷键页、菜单行尾、胶囊按平台各取出得了字的那一个：macOS 列 ⌘Z / ⇧⌘Z，Windows 列 Ctrl+Z / Ctrl+Y。
// 全部 includeRepeats: false（按住不放不连撤）；对文本编辑让位（notEditingText）——文本框有焦点时 Ctrl Z 归框自己的撤销，
// 画布栈不动。执行体在 util/canvas_history_actions.dart（与空白处右键菜单、⌘K 同一条路）。
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../app_actions/planned_keys.dart';
import '../../util/canvas_history_actions.dart';
import 'canvas_key_binding.dart';

/// 撤销画布撤销栈的栈顶一步。
class CanvasUndoIntent extends Intent {
  const CanvasUndoIntent();
}

/// 重做画布撤销栈 redo 栈顶那一步。
class CanvasRedoIntent extends Intent {
  const CanvasRedoIntent();
}

/// 撤销 / 重做两条绑定。
final List<CanvasKeyBinding> undoKeys = <CanvasKeyBinding>[
  CanvasKeyBinding(
    id: kCanvasUndoBindingId,
    activators: const <ShortcutActivator>[
      PlannedKeys.undoMac,
      PlannedKeys.undoOther,
    ],
    intent: const CanvasUndoIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.edit,
    label: (AppLocalizations l) => l.settingsShortcutCanvasUndo,
    onInvoke: (CanvasKeyContext c, Intent _) => unawaited(
      runCanvasUndo(
        _readerOf(c),
        canvasId: c.canvasId,
        l: c.context.l10n,
        isMac: _isMac,
      ),
    ),
  ),
  CanvasKeyBinding(
    id: kCanvasRedoBindingId,
    activators: const <ShortcutActivator>[
      PlannedKeys.redoMac,
      PlannedKeys.redoOther,
    ],
    intent: const CanvasRedoIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.edit,
    label: (AppLocalizations l) => l.settingsShortcutCanvasRedo,
    onInvoke: (CanvasKeyContext c, Intent _) => unawaited(
      runCanvasRedo(
        _readerOf(c),
        canvasId: c.canvasId,
        l: c.context.l10n,
        isMac: _isMac,
      ),
    ),
  ),
];

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

/// 胶囊上的反向按钮最多 4 s 后才被点：取容器的 read，不攥 CanvasShortcuts 的 WidgetRef（见 canvas_history_actions 头注）。
ProviderReader _readerOf(CanvasKeyContext c) =>
    ProviderScope.containerOf(c.context, listen: false).read;
