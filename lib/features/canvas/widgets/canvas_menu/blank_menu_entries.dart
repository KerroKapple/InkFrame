// 空白处右键菜单的四项（menu_registry.dart 的表里 scope = blank 的那几条）：新建… · 导入脚本… | 全选 · 适应视图。
//
// 这一版不放「粘贴」「导入媒体」：没有后端（画布没有剪贴板，也没有媒体导入的写入路径），按「无后端不画」
// 不放（BOARD 有记）。组号按 menu_registry.dart 头注的约定：10 新建 · 导入 / 50 选择 · 视图。
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../../l10n/l10n_x.dart';
import '../../../../theme/components/ink_menu_panel.dart';
import '../../../../theme/icons/ink_glyph.dart';
import '../../../settings/util/shortcut_catalog.dart';
import '../../../storyboard/widgets/script_import_dialog.dart';
import '../../providers/canvas_transform_controller.dart';
import '../../util/canvas_tool_actions.dart';
import '../../util/drop_placement.dart';
import '../canvas_shortcuts.dart';
import 'canvas_menu_request.dart';
import 'menu_registry.dart';

// id 用 BlankMenuAction 的名字拼（这一行交回来的值也是它）。
final String _createId = 'blank.${BlankMenuAction.create.name}';
final String _importScriptId = 'blank.${BlankMenuAction.importScript.name}';
final String _selectAllId = 'blank.${BlankMenuAction.selectAll.name}';
final String _fitViewId = 'blank.${BlankMenuAction.fitView.name}';

/// 空白处右键菜单的项。
final List<CanvasMenuItemDef> blankMenuItems = <CanvasMenuItemDef>[
  CanvasMenuItemDef(
    id: _createId,
    scope: CanvasMenuScope.blank,
    group: 10,
    order: 10,
    build: _buildCreate,
    run: _runCreate,
  ),
  CanvasMenuItemDef(
    id: _importScriptId,
    scope: CanvasMenuScope.blank,
    group: 10,
    order: 20,
    build: _buildImportScript,
    run: _runImportScript,
  ),
  CanvasMenuItemDef(
    id: _selectAllId,
    scope: CanvasMenuScope.blank,
    group: 50,
    order: 10,
    build: _buildSelectAll,
    run: _runSelectAll,
  ),
  CanvasMenuItemDef(
    id: _fitViewId,
    scope: CanvasMenuScope.blank,
    group: 50,
    order: 20,
    build: _buildFitView,
    run: _runFitView,
  ),
];

bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

InkMenuEntry<String> _buildCreate(CanvasMenuContext c) => InkMenuEntry<String>(
      value: _createId,
      label: c.context.l10n.canvasBlankMenuNew,
      glyph: InkGlyph.nodeLibrary,
      keyHint: CanvasToolKeys.createMenu.keyLabel,
    );

/// 新建…：原地换成新建菜单——同一个锚点，不带上下文。不调 dismiss：关了再开会把焦点先还给画布、
/// 新菜单的请求也会被当成另一个菜单。
void _runCreate(CanvasMenuContext c) => c.ref
    .read(canvasMenuRequestProvider(c.canvasId).notifier)
    .openCreate(c.request.anchor);

/// 与工具条「更多 → 导入脚本…」同一句：开的是同一个导入框。
InkMenuEntry<String> _buildImportScript(CanvasMenuContext c) => InkMenuEntry<String>(
      value: _importScriptId,
      label: c.context.l10n.canvasAddImportScript,
      glyph: InkGlyph.script,
    );

void _runImportScript(CanvasMenuContext c) {
  c.dismiss?.call();
  // 整条链从右键那一点起铺。导入的镜头不进泳道，按不在道里的卡算世界坐标。
  showScriptImportDialog(
    c.context,
    canvasId: c.canvasId,
    origin: viewportToWorld(
      c.request.anchor,
      c.ref.read(canvasTransformControllerProvider(c.canvasId)).value,
    ),
  );
}

/// 全选（与 Ctrl+A / ⌘A 同一个动作）。键位从快捷键表里取（与设置「快捷键」页同源），按平台出 ⌘A / Ctrl+A。
InkMenuEntry<String> _buildSelectAll(CanvasMenuContext c) => InkMenuEntry<String>(
      value: _selectAllId,
      label: c.context.l10n.canvasBlankMenuSelectAll,
      keyHint: canvasShortcutLabel(
        (Intent intent) => intent is SelectAllNodesIntent,
        isMac: _isMac,
      ),
    );

void _runSelectAll(CanvasMenuContext c) {
  c.dismiss?.call();
  selectAllNodes(c.ref, canvasId: c.canvasId);
}

/// 适应视图 = 适应全部（与缩放条「适应」、Shift+1 同一个动作），键位同样从表里取。
InkMenuEntry<String> _buildFitView(CanvasMenuContext c) => InkMenuEntry<String>(
      value: _fitViewId,
      label: c.context.l10n.canvasBlankMenuFitView,
      glyph: InkGlyph.fit,
      keyHint: canvasShortcutLabel(
        (Intent intent) => intent is CanvasFitAllIntent,
        isMac: _isMac,
      ),
    );

void _runFitView(CanvasMenuContext c) {
  c.dismiss?.call();
  fitAllNodes(c.ref, canvasId: c.canvasId);
}
