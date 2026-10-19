// 空白处右键菜单最上面一组（menu_registry.dart 头注约定的组 0「撤销 · 重做」）：
//   撤销 <步名>   Ctrl+Z / ⌘Z
//   重做 <步名>   Ctrl+Y / ⇧⌘Z
// 两行永远出现：栈顶为空或撤销在途 ⇒ 置灰不隐藏。行名带步名（菜单打开那一刻的栈顶）；build 时 watch 撤销栈，
// 菜单开着时栈变了行跟着变。行尾键位按 id 从快捷键注册表取（canvasBindingLabel），与设置「快捷键」页同源。
// 重做行没有图标（图标集 v1 里没有「镜像撤销」）：glyph 留空，InkMenuPanel 照样留出同宽空位、文字对齐。
// 执行体在 util/canvas_history_actions.dart（与 Ctrl Z / ⌘Z、⌘K 同一条路）：先关菜单、焦点回画布，再撤销 / 重做。
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/components/ink_menu_panel.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../../settings/util/shortcut_catalog.dart';
import '../../providers/canvas_history_controller.dart';
import '../../util/canvas_history_actions.dart';
import 'menu_registry.dart';

const String _undoId = 'blank.undo';
const String _redoId = 'blank.redo';

/// 空白处右键菜单的撤销 / 重做两行。
final List<CanvasMenuItemDef> undoBlankMenuItems = <CanvasMenuItemDef>[
  CanvasMenuItemDef(
    id: _undoId,
    scope: CanvasMenuScope.blank,
    group: 0,
    order: 10,
    build: _buildUndo,
    run: _runUndo,
  ),
  CanvasMenuItemDef(
    id: _redoId,
    scope: CanvasMenuScope.blank,
    group: 0,
    order: 20,
    build: _buildRedo,
    run: _runRedo,
  ),
];

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

InkMenuEntry<String> _buildUndo(CanvasMenuContext c) {
  final CanvasHistoryState history =
      c.ref.watch(canvasHistoryControllerProvider(c.canvasId));
  final CanvasHistoryStep? step = history.undo.lastOrNull;
  return InkMenuEntry<String>(
    value: _undoId,
    label: canvasUndoMenuLabel(c.context.l10n, step),
    glyph: InkGlyph.undo,
    keyHint: canvasBindingLabel(kCanvasUndoBindingId, isMac: _isMac),
    enabled: step != null && !history.busy,
  );
}

InkMenuEntry<String> _buildRedo(CanvasMenuContext c) {
  final CanvasHistoryState history =
      c.ref.watch(canvasHistoryControllerProvider(c.canvasId));
  final CanvasHistoryStep? step = history.redo.lastOrNull;
  return InkMenuEntry<String>(
    value: _redoId,
    label: canvasRedoMenuLabel(c.context.l10n, step),
    keyHint: canvasBindingLabel(kCanvasRedoBindingId, isMac: _isMac),
    enabled: step != null && !history.busy,
  );
}

/// 先关菜单、焦点当场回画布（照「全选」），再撤销。c.context 是宿主的 context，菜单此刻已在卸载。
Future<void> _runUndo(CanvasMenuContext c) async {
  c.dismiss?.call();
  await runCanvasUndo(
    ProviderScope.containerOf(c.context, listen: false).read,
    canvasId: c.canvasId,
    l: c.context.l10n,
    isMac: _isMac,
  );
}

Future<void> _runRedo(CanvasMenuContext c) async {
  c.dismiss?.call();
  await runCanvasRedo(
    ProviderScope.containerOf(c.context, listen: false).read,
    canvasId: c.canvasId,
    l: c.context.l10n,
    isMac: _isMac,
  );
}
