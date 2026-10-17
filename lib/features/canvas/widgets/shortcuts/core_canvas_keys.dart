// 画布的核心快捷键（注册表 kCanvasKeyRegistry 的第一段）：原 canvas_shortcuts.dart 的 kCanvasShortcuts
// 表 + 一串 _xxx() 回调，改写成一条条 [CanvasKeyBinding]。键位、门槛、回调、文案、分组与改写前一一对应：
//   - 每条 activators 与原表同一组 const 表达式、同一顺序（Delete 在 Backspace 前，meta 在 control 前）。
//     现有测试拿 `const SingleActivator(...)` 当 Map 键查 kCanvasShortcuts，靠的是 const 规范化成同一个实例
//     ——这里写法一变，那些查找就取到 null。
//   - 列表顺序 = 旧 ShortcutAction 枚举声明序 = 设置「快捷键」页的行序。
// 动作本体在 util/canvas_tool_actions.dart（与工具条 / 右键菜单共用）；这里只有快捷键独有的那几段。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../models/canvas_node.dart';
import '../../providers/canvas_capsule.dart';
import '../../providers/canvas_escape_ladder.dart';
import '../../providers/canvas_menu_state.dart';
import '../../providers/canvas_nodes_controller.dart';
import '../../providers/canvas_selection_controller.dart';
import '../../providers/canvas_tool_mode.dart';
import '../../providers/canvas_transform_controller.dart';
import '../../providers/left_rail_state.dart';
import '../../util/canvas_node_delete.dart';
import '../../util/canvas_tool_actions.dart';
import '../../util/canvas_zoom.dart';
import '../../util/node_menu_model.dart';
import 'canvas_intents.dart';
import 'canvas_key_binding.dart';
import 'canvas_tool_keys.dart';

/// 画布的核心快捷键。
final List<CanvasKeyBinding> coreCanvasKeys = <CanvasKeyBinding>[
  CanvasKeyBinding(
    id: 'canvasDelete',
    activators: const <ShortcutActivator>[
      SingleActivator(LogicalKeyboardKey.delete),
      SingleActivator(LogicalKeyboardKey.backspace),
    ],
    intent: const DeleteSelectionIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.edit,
    label: (AppLocalizations l) => l.settingsShortcutCanvasDelete,
    onInvoke: (CanvasKeyContext c, Intent _) => deleteCanvasSelection(c),
  ),
  // Esc 不对文本编辑让位：输入框失焦本身就是阶梯上的一层。无事可剥时不消费，冒泡给祖先。
  // includeRepeats: false——Esc 一次只剥一层，按住不放不能靠自动重复连剥下去（在输入框里按久了会接着
  // 清掉选中；菜单里按久了，关菜单之后接着清掉右键时设好的选中）。
  CanvasKeyBinding(
    id: 'canvasEscape',
    activators: const <ShortcutActivator>[
      SingleActivator(LogicalKeyboardKey.escape, includeRepeats: false),
    ],
    intent: const CanvasEscapeIntent(),
    gate: CanvasKeyGate.always,
    group: ShortcutGroup.edit,
    label: (AppLocalizations l) => l.settingsShortcutCanvasEscape,
    onInvoke: (CanvasKeyContext c, Intent _) => escapeCanvas(c),
    enabledWhen: canEscapeCanvas,
  ),
  CanvasKeyBinding(
    id: 'canvasSelectAll',
    activators: const <ShortcutActivator>[
      SingleActivator(LogicalKeyboardKey.keyA, meta: true),
      SingleActivator(LogicalKeyboardKey.keyA, control: true),
    ],
    intent: const SelectAllNodesIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.edit,
    label: (AppLocalizations l) => l.settingsShortcutCanvasSelectAll,
    // 与空白处右键菜单「全选」同一个动作（canvas_tool_actions.dart）。
    onInvoke: (CanvasKeyContext c, Intent _) =>
        selectAllNodes(c.ref, canvasId: c.canvasId),
  ),
  // PR-8b 四个键同样对文本编辑让位。⌘↵ 尤其要让：提示词条里打字时那一下归提示词条自己。
  CanvasKeyBinding(
    id: 'canvasDuplicate',
    activators: const <ShortcutActivator>[
      CanvasToolKeys.duplicateMeta,
      CanvasToolKeys.duplicateControl,
    ],
    intent: const CanvasDuplicateIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.edit,
    label: (AppLocalizations l) => l.settingsShortcutCanvasDuplicate,
    onInvoke: (CanvasKeyContext c, Intent _) => duplicateCanvasSelection(c),
  ),
  CanvasKeyBinding(
    id: 'canvasGenerate',
    activators: const <ShortcutActivator>[
      CanvasToolKeys.generateMeta,
      CanvasToolKeys.generateControl,
    ],
    intent: const CanvasGenerateIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.generate,
    label: (AppLocalizations l) => l.settingsShortcutCanvasGenerate,
    onInvoke: (CanvasKeyContext c, Intent _) => generateCanvasSelection(c),
  ),
  // 缩放同样对文本编辑让位（与删除/全选一致），免得在数值输入框里打字触发缩放。
  // 放大：= 与 + 同键，另收小键盘 +。
  CanvasKeyBinding(
    id: 'canvasZoomIn',
    activators: const <ShortcutActivator>[
      SingleActivator(LogicalKeyboardKey.equal, meta: true),
      SingleActivator(LogicalKeyboardKey.equal, control: true),
      SingleActivator(LogicalKeyboardKey.add, meta: true),
      SingleActivator(LogicalKeyboardKey.add, control: true),
      SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true),
      SingleActivator(LogicalKeyboardKey.numpadAdd, control: true),
    ],
    intent: const CanvasZoomInIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.view,
    label: (AppLocalizations l) => l.settingsShortcutCanvasZoomIn,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        zoomCanvasBy(c.ref, canvasId: c.canvasId, factor: kCanvasZoomStep),
  ),
  CanvasKeyBinding(
    id: 'canvasZoomOut',
    activators: const <ShortcutActivator>[
      SingleActivator(LogicalKeyboardKey.minus, meta: true),
      SingleActivator(LogicalKeyboardKey.minus, control: true),
      SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true),
      SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true),
    ],
    intent: const CanvasZoomOutIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.view,
    label: (AppLocalizations l) => l.settingsShortcutCanvasZoomOut,
    onInvoke: (CanvasKeyContext c, Intent _) => zoomCanvasBy(
      c.ref,
      canvasId: c.canvasId,
      factor: 1 / kCanvasZoomStep,
    ),
  ),
  CanvasKeyBinding(
    id: 'canvasZoomReset',
    activators: const <ShortcutActivator>[
      SingleActivator(LogicalKeyboardKey.digit0, meta: true),
      SingleActivator(LogicalKeyboardKey.digit0, control: true),
      SingleActivator(LogicalKeyboardKey.numpad0, meta: true),
      SingleActivator(LogicalKeyboardKey.numpad0, control: true),
    ],
    intent: const CanvasZoomResetIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.view,
    label: (AppLocalizations l) => l.settingsShortcutCanvasZoomReset,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        resetCanvasZoom(c.ref, canvasId: c.canvasId),
  ),
  CanvasKeyBinding(
    id: 'canvasFitAll',
    activators: const <ShortcutActivator>[CanvasToolKeys.fitAll],
    intent: const CanvasFitAllIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.view,
    label: (AppLocalizations l) => l.settingsShortcutCanvasFitAll,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        fitAllNodes(c.ref, canvasId: c.canvasId),
  ),
  CanvasKeyBinding(
    id: 'canvasFitSelection',
    activators: const <ShortcutActivator>[CanvasToolKeys.fitSelection],
    intent: const CanvasFitSelectionIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.view,
    label: (AppLocalizations l) => l.settingsShortcutCanvasFitSelection,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        fitSelectedNodes(c.ref, canvasId: c.canvasId),
  ),
  // 工具单键（浮动工具条）。不带修饰键、两个平台同键，同样对文本编辑让位：在提示词条 / 检查器里打字时
  // 字母就是字母。includeRepeats: false——按住 I 不该连建一串节点，按住 H 不该来回切，按住 F 不该叠开对话框。
  CanvasKeyBinding(
    id: 'canvasSelectTool',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.select, includeRepeats: false),
    ],
    intent: const CanvasSelectToolIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasSelectTool,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        activateSelectTool(c.ref, canvasId: c.canvasId),
  ),
  CanvasKeyBinding(
    id: 'canvasPanTool',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.pan, includeRepeats: false),
    ],
    intent: const CanvasTogglePanToolIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasPanTool,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        c.ref.read(canvasToolModeProvider(c.canvasId).notifier).togglePan(),
  ),
  CanvasKeyBinding(
    id: 'canvasAddImageNode',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.imageNode, includeRepeats: false),
    ],
    intent: const CanvasAddNodeIntent(CanvasNodeType.image),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasAddImageNode,
    onInvoke: addCanvasNodeOf,
  ),
  CanvasKeyBinding(
    id: 'canvasAddVideoNode',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.videoNode, includeRepeats: false),
    ],
    intent: const CanvasAddNodeIntent(CanvasNodeType.video),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasAddVideoNode,
    onInvoke: addCanvasNodeOf,
  ),
  CanvasKeyBinding(
    id: 'canvasAddTextNode',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.textNode, includeRepeats: false),
    ],
    intent: const CanvasAddNodeIntent(CanvasNodeType.text),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasAddTextNode,
    onInvoke: addCanvasNodeOf,
  ),
  CanvasKeyBinding(
    id: 'canvasAddLane',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.lane, includeRepeats: false),
    ],
    intent: const CanvasAddLaneIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasAddLane,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        addLaneViaDialog(c.context, c.ref, canvasId: c.canvasId),
  ),
  // 新建…（PR-8a）：只在画布本身持主焦点时接管，别处的 Tab 一律放行给焦点遍历；按住不放不连开。
  CanvasKeyBinding(
    id: 'canvasOpenCreateMenu',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.createMenu, includeRepeats: false),
    ],
    intent: const CanvasOpenCreateMenuIntent(),
    gate: CanvasKeyGate.canvasFocused,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasOpenCreateMenu,
    onInvoke: (CanvasKeyContext c, Intent _) => openCanvasCreateMenu(c),
  ),
  CanvasKeyBinding(
    id: 'canvasToggleLink',
    activators: const <ShortcutActivator>[
      SingleActivator(CanvasToolKeys.link, includeRepeats: false),
    ],
    intent: const CanvasToggleLinkIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.tools,
    label: (AppLocalizations l) => l.settingsShortcutCanvasToggleLink,
    onInvoke: (CanvasKeyContext c, Intent _) =>
        toggleLinkMode(c.ref, canvasId: c.canvasId),
  ),
  // 左栏开合（PR-4）同样对文本编辑让位：在筛选框里打字时 Ctrl+\ 不收左栏。
  CanvasKeyBinding(
    id: 'canvasToggleLeftRail',
    activators: const <ShortcutActivator>[
      CanvasToolKeys.toggleLeftRailMeta,
      CanvasToolKeys.toggleLeftRailControl,
    ],
    intent: const CanvasToggleLeftRailIntent(),
    gate: CanvasKeyGate.notEditingText,
    group: ShortcutGroup.panels,
    label: (AppLocalizations l) => l.settingsShortcutCanvasToggleLeftRail,
    // 左栏只在打开了画布时才画；没有画布时绑定本就不启用，不动它的状态。
    onInvoke: (CanvasKeyContext c, Intent _) =>
        c.ref.read(leftRailProvider.notifier).toggle(),
  ),
];

// ===== 回调本体 =====

/// Delete / Backspace：删除选中节点。
void deleteCanvasSelection(CanvasKeyContext c) {
  final Set<String> selected =
      c.ref.read(canvasSelectionControllerProvider(c.canvasId));
  if (selected.isEmpty) return;
  // fire-and-forget：删除自身带 undo/失败 snackbar，无需等待。
  deleteNodesWithUndo(c.context, c.ref, canvasId: c.canvasId, nodeIds: selected);
}

/// Esc 此刻有没有东西可剥（Esc 绑定的 enabledWhen）：没有 ⇒ 不消费，Esc 冒泡给祖先。
bool canEscapeCanvas(CanvasKeyContext c) =>
    c.ref
        .read(canvasEscapeLadderProvider(c.canvasId))
        .peek(local: c.escapeRungs) !=
    null;

/// Esc：按 Esc 阶梯剥一层（层序见 util/escape_ladder.dart；输入框那一层由 CanvasShortcuts 以 local 传入）。
void escapeCanvas(CanvasKeyContext c) {
  c.ref
      .read(canvasEscapeLadderProvider(c.canvasId))
      .handle(local: c.escapeRungs);
}

/// 围绕视口中心按 [factor] 缩放（⌘± / Ctrl±）。改完在舞台底部出「缩放 N%」胶囊——键盘缩放才出，
/// 滚轮 / 捏合 / 缩放条 +、− 不走这里、不出（缩放条上一直显示着比例）。
void zoomCanvasBy(
  WidgetRef ref, {
  required String canvasId,
  required double factor,
}) {
  final TransformationController controller =
      ref.read(canvasTransformControllerProvider(canvasId));
  final Size size = ref.read(canvasViewportSizeProvider(canvasId));
  controller.value = zoomedTransform(
    current: controller.value,
    factor: factor,
    viewportSize: size,
  );
  showZoomCapsule(ref, canvasId: canvasId);
}

/// 缩放复位（⌘0 / Ctrl+0）：缩放到 100%、视口中心对着的内容不动（KeyMap Q5-B）；不回初始相机——
/// 初始相机常落在空处，回内容有 Shift+1。已是 100% 时相机不动，胶囊照出「缩放 100%」。
void resetCanvasZoom(WidgetRef ref, {required String canvasId}) {
  final TransformationController controller =
      ref.read(canvasTransformControllerProvider(canvasId));
  final Size size = ref.read(canvasViewportSizeProvider(canvasId));
  controller.value = actualSizeTransform(controller.value, size);
  showZoomCapsule(ref, canvasId: canvasId);
}

/// I / G / T：在视口中心建一个 intent 指定类型的节点（与工具条建节点键同一条路径）。
void addCanvasNodeOf(CanvasKeyContext c, Intent intent) {
  if (intent is! CanvasAddNodeIntent) return;
  // fire-and-forget：失败自带错误卡（与工具条建节点同一条路径）。
  addNodeAtViewportCenter(
    c.context,
    c.ref,
    canvasId: c.canvasId,
    type: intent.type,
  );
}

/// Tab：新建菜单开在视口中心（不带连线上下文）。视口还没上报尺寸（首帧前）时不知道中心在哪，不开。
/// 菜单里不带上下文的项与 I / G / T 同一条路（落在视口中心 + 散布），见 CanvasMenuRequest.viewportCentered。
void openCanvasCreateMenu(CanvasKeyContext c) {
  final Size viewport = c.ref.read(canvasViewportSizeProvider(c.canvasId));
  if (viewport.isEmpty) return;
  c.ref
      .read(canvasMenuRequestProvider(c.canvasId).notifier)
      .openCreate(viewport.center(Offset.zero), viewportCentered: true);
}

/// Ctrl+↵ / ⌘↵：恰好选中一张可生成的配置卡（判据 generationTarget）才生成，其余情况不动。
void generateCanvasSelection(CanvasKeyContext c) {
  final Set<String> selected =
      c.ref.read(canvasSelectionControllerProvider(c.canvasId));
  if (selected.isEmpty) return;
  final List<CanvasNode> nodes =
      c.ref.read(canvasNodesControllerProvider(c.canvasId)).valueOrNull ??
          const <CanvasNode>[];
  final CanvasNode? target = generationTarget(<CanvasNode>[
    for (final CanvasNode n in nodes)
      if (selected.contains(n.id)) n,
  ]);
  if (target == null) return;
  generateNode(c.ref, nodeId: target.id);
}

/// Ctrl+D / ⌘D：复制一份（选中的配置卡各一份）。
void duplicateCanvasSelection(CanvasKeyContext c) {
  final Set<String> selected =
      c.ref.read(canvasSelectionControllerProvider(c.canvasId));
  if (selected.isEmpty) return;
  // fire-and-forget：失败自带错误卡（与节点右键菜单「复制一份」同一条路径）。
  duplicateNodes(c.context, c.ref, canvasId: c.canvasId, nodeIds: selected);
}
