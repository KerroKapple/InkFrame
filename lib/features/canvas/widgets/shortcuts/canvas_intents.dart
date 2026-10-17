// 画布快捷键的 Intent（键位 → Intent → Action）。原在 canvas_shortcuts.dart，搬来后由它 re-export，
// 原有 import 路径照常可用。每个 Intent 绑哪些键、走哪道门槛、调哪个回调，登记在注册表
// （canvas_shortcut_registry.dart 的 kCanvasKeyRegistry）。
import 'package:flutter/widgets.dart';

import '../../models/canvas_node.dart';

/// 删除当前选中节点（Delete / Backspace）。
class DeleteSelectionIntent extends Intent {
  const DeleteSelectionIntent();
}

/// Esc：按 Esc 阶梯一次剥一层（层序只在 util/escape_ladder.dart 的 EscapeRungId 里定）。无事可剥时不消费。
class CanvasEscapeIntent extends Intent {
  const CanvasEscapeIntent();
}

/// 全选当前画布所有节点（⌘A / Ctrl+A）。
class SelectAllNodesIntent extends Intent {
  const SelectAllNodesIntent();
}

/// 放大（⌘+ / Ctrl+）。
class CanvasZoomInIntent extends Intent {
  const CanvasZoomInIntent();
}

/// 缩小（⌘- / Ctrl-）。
class CanvasZoomOutIntent extends Intent {
  const CanvasZoomOutIntent();
}

/// 缩放复位（⌘0 / Ctrl+0），行为见 resetCanvasZoom。
class CanvasZoomResetIntent extends Intent {
  const CanvasZoomResetIntent();
}

/// V：选择工具（同时退出连线模式，与工具条「选择」同义）。
class CanvasSelectToolIntent extends Intent {
  const CanvasSelectToolIntent();
}

/// H：平移工具开 / 关。
class CanvasTogglePanToolIntent extends Intent {
  const CanvasTogglePanToolIntent();
}

/// I / G / T：在视口中心新建一个 [type] 节点（与工具条建节点键同一条路径）。
class CanvasAddNodeIntent extends Intent {
  const CanvasAddNodeIntent(this.type);

  final CanvasNodeType type;
}

/// F：新建泳道（开泳道编辑框）。
class CanvasAddLaneIntent extends Intent {
  const CanvasAddLaneIntent();
}

/// L：开始 / 退出连线（恰好选中一个节点时以它为源；已在连线模式则退出）。
class CanvasToggleLinkIntent extends Intent {
  const CanvasToggleLinkIntent();
}

/// Ctrl+\ / ⌘\：左栏面板开合（与导航条底部的收起键同一个动作）。
class CanvasToggleLeftRailIntent extends Intent {
  const CanvasToggleLeftRailIntent();
}

/// Tab：在视口中心开「新建」菜单（与双击空白、空白处右键「新建…」同一个菜单）。
class CanvasOpenCreateMenuIntent extends Intent {
  const CanvasOpenCreateMenuIntent();
}

/// Ctrl+↵ / ⌘↵：生成选中的那一张（与节点右键菜单「生成」、提示词条「生成」同一条 submit）。
class CanvasGenerateIntent extends Intent {
  const CanvasGenerateIntent();
}

/// Ctrl+D / ⌘D：复制一份（选中的配置卡各一份，与节点右键菜单「复制一份」同一个动作）。
class CanvasDuplicateIntent extends Intent {
  const CanvasDuplicateIntent();
}

/// Shift+1：适应全部（与缩放条「适应」、空白处右键菜单「适应视图」同一个动作）。
class CanvasFitAllIntent extends Intent {
  const CanvasFitAllIntent();
}

/// Shift+2：适应选中。
class CanvasFitSelectionIntent extends Intent {
  const CanvasFitSelectionIntent();
}
