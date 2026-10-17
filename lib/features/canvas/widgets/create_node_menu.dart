// 画布菜单的入口（barrel）：新建菜单 + 空白处右键菜单 + 节点右键菜单（画布重设计稿 › 画布交互「拖线到空白处 →
// 建节点」「右键菜单」）。canvas_view / canvas_shortcuts 与测试只 import 这一个文件。
//
//   - 菜单本体 InkMenuPanel / InkMenuEntry 在 theme 层（lib/theme/components/ink_menu_panel.dart），不认识画布。
//   - canvas_menu/canvas_menu_request.dart：canvasMenuRequestProvider（开着哪个菜单）、canvasWireDragProvider（拖线
//     实时状态）、空白处右键菜单的项、测试锚点 CanvasMenuKeys。
//   - canvas_menu/canvas_menu_host.dart：CanvasMenuHost（浮层、点外面 / 失焦关、焦点交接、选中派发）。
//   - canvas_menu/menu_registry.dart：空白处 / 节点右键菜单的项表（blank_menu_entries.dart / node_menu_entries.dart）；
//     新建菜单的项在 create_menu_entries.dart。
//   - canvas_menu/canvas_menu_popover.dart：舞台外按全局坐标开的菜单弹层。
export '../../../theme/components/ink_menu_panel.dart'
    show InkMenuEntry, InkMenuPanel, InkMenuPanelKeys;
export 'canvas_menu/canvas_menu_host.dart' show CanvasMenuHost;
export 'canvas_menu/canvas_menu_popover.dart';
export 'canvas_menu/canvas_menu_request.dart';
