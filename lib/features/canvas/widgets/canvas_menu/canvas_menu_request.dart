// 画布菜单 widget 侧的常量：空白处右键菜单的项与测试锚点。菜单的状态（canvasMenuRequestProvider /
// canvasWireDragProvider 与它们的值对象）在 providers/canvas_menu_state.dart，这里原样转出——菜单各文件与
// barrel create_node_menu.dart 照旧从本文件拿。
import 'package:flutter/widgets.dart';

import '../../../../theme/components/ink_menu_panel.dart';

export '../../providers/canvas_menu_state.dart';

/// 空白处右键菜单的项。
enum BlankMenuAction {
  /// 新建…（Tab）：原地换成新建菜单。
  create,

  /// 导入剧本…：开剧本导入框，第一镜落在右键那一点。
  importScript,

  /// 全选（与 Ctrl+A / ⌘A 同一个动作）。
  selectAll,

  /// 适应视图 = 适应全部（与缩放条「适应」、Shift+1 同一个动作）。
  fitView,
}

/// 测试锚点。
class CanvasMenuKeys {
  CanvasMenuKeys._();

  /// 新建菜单的面板。
  static const Key createMenu = ValueKey<String>('canvasMenu.create');

  /// 空白处右键菜单的面板。
  static const Key blankMenu = ValueKey<String>('canvasMenu.blank');

  /// 节点右键菜单的面板。
  static const Key nodeMenu = ValueKey<String>('canvasMenu.node');

  /// 子菜单的框（节点右键菜单「加入泳道 ›」）。框是面板自己画的，值在 theme 层。
  static const Key submenu = InkMenuPanelKeys.submenu;

  /// 新建菜单的搜索框。同上，值在 theme 层。
  static const Key search = InkMenuPanelKeys.search;
}
