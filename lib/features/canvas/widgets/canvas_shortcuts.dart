// 画布快捷键基建 + 第一批（PL-2）+ 工具单键（浮动工具条）。
//
// 键位 → Intent（Shortcuts）→ Action（Actions）→ provider 副作用；business 逻辑
// 全部下沉到 util / controller，本层只做绑定（SOLID：可测的 shortcut→action 缝）。
//
// 焦点链陷阱：Inspector 的 TextField 聚焦时，Backspace/Delete 必须编辑文本、⌘A
// 必须选中框内文本，而非命中画布。CanvasShortcuts 是 Inspector 字段的祖先，若无
// 防护会抢先命中（本地 Shortcuts 优先于上层 DefaultTextEditingShortcuts）。因此
// 删除/全选两个动作在文本编辑态下 isEnabled=false，按键得以冒泡到文本编辑快捷键。
// 工具单键（V / H / I / G / T / F / L）同一个道理：在提示词条或检查器里打字时，
// 「v」就该是一个「v」，不能把工具切走。
//
// 按住空格临时平移不进快捷键表：它要按下与松开两个事件，Shortcuts 只认按下。
// 在本层 Focus 的 onKeyEvent 里处理（_CanvasShortcutsState._onKeyEvent）。
//
// Ctrl+\（macOS ⌘\）开合左栏（PR-4）：同样对文本编辑让位——在筛选框 / 提示词条里打字时
// 不该把左栏收起来。键位常量在 CanvasToolKeys，导航条「收起」键的 tooltip 与它同源。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_tool_mode.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/current_canvas_id.dart';
import '../providers/left_rail_state.dart';
import '../providers/link_mode_controller.dart';
import '../providers/selected_edge_controller.dart';
import '../util/canvas_node_delete.dart';
import '../util/canvas_tool_actions.dart';
import '../util/canvas_zoom.dart';

// ===== Intents =====

/// 删除当前选中节点（Delete / Backspace）。
class DeleteSelectionIntent extends Intent {
  const DeleteSelectionIntent();
}

/// Esc：在平移工具则回到选择；否则连线模式激活则退出连线；否则清空节点 + 边选择。
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

/// 缩放复位（⌘0 / Ctrl0）。
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

/// 画布工具的键位。工具条 tooltip 与下面的 [kCanvasShortcuts] 取同一组常量——改键位
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

  /// 按住临时平移。不进 [kCanvasShortcuts]（要按下与松开两个事件，见
  /// _CanvasShortcutsState._onKeyEvent）；设置页清单单独收它
  /// （features/settings/util/shortcut_catalog.dart）。
  static const SingleActivator holdToPan =
      SingleActivator(LogicalKeyboardKey.space);

  /// 左栏开合：macOS 是 ⌘\，其余平台 Ctrl+\。两个变体都进 [kCanvasShortcuts]（与 ⌘A / Ctrl+A
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
}

/// 主焦点是否落在某个 EditableText 内——用于让文本编辑抢先于画布删除/全选。
/// 用顶层 [primaryFocus] getter（非 FocusManager.instance 静态单例，遵守 DIP 铁律）。
bool isEditingText() {
  final ctx = primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.findAncestorStateOfType<EditableTextState>() != null;
}

/// 文本编辑态下自动让位的 Action：聚焦文本框时 isEnabled/consumesKey=false，
/// 使按键冒泡到 DefaultTextEditingShortcuts（画布删除 / 全选 / 缩放 / 工具单键）。
class _EditingAwareAction<T extends Intent> extends Action<T> {
  _EditingAwareAction(this._onInvoke);
  final void Function(T intent) _onInvoke;

  @override
  bool isEnabled(T intent) => !isEditingText();

  @override
  bool consumesKey(T intent) => !isEditingText();

  @override
  Object? invoke(T intent) {
    _onInvoke(intent);
    return null;
  }
}

// 键位映射：⌘ 与 Ctrl 变体同时注册，跨平台一致（桌面 macOS/Windows）。
//
// 公开（P7）：设置「快捷键」页的只读清单从这张表反推出来，不另抄一份——手抄的
// 清单改了键位不会跟着改，用户照着列表按一个早就改掉的键。见
// features/settings/util/shortcut_catalog.dart。
final Map<ShortcutActivator, Intent>
kCanvasShortcuts = <ShortcutActivator, Intent>{
  const SingleActivator(LogicalKeyboardKey.delete):
      const DeleteSelectionIntent(),
  const SingleActivator(LogicalKeyboardKey.backspace):
      const DeleteSelectionIntent(),
  const SingleActivator(LogicalKeyboardKey.escape): const CanvasEscapeIntent(),
  // 全选
  const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
      const SelectAllNodesIntent(),
  const SingleActivator(LogicalKeyboardKey.keyA, control: true):
      const SelectAllNodesIntent(),
  // 放大（= 与 + 同键，另收小键盘 +）
  const SingleActivator(LogicalKeyboardKey.equal, meta: true):
      const CanvasZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.equal, control: true):
      const CanvasZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.add, meta: true):
      const CanvasZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.add, control: true):
      const CanvasZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadAdd, meta: true):
      const CanvasZoomInIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
      const CanvasZoomInIntent(),
  // 缩小
  const SingleActivator(LogicalKeyboardKey.minus, meta: true):
      const CanvasZoomOutIntent(),
  const SingleActivator(LogicalKeyboardKey.minus, control: true):
      const CanvasZoomOutIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadSubtract, meta: true):
      const CanvasZoomOutIntent(),
  const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
      const CanvasZoomOutIntent(),
  // 复位
  const SingleActivator(LogicalKeyboardKey.digit0, meta: true):
      const CanvasZoomResetIntent(),
  const SingleActivator(LogicalKeyboardKey.digit0, control: true):
      const CanvasZoomResetIntent(),
  const SingleActivator(LogicalKeyboardKey.numpad0, meta: true):
      const CanvasZoomResetIntent(),
  const SingleActivator(LogicalKeyboardKey.numpad0, control: true):
      const CanvasZoomResetIntent(),
  // 工具单键（浮动工具条）。不带修饰键、两个平台同键。includeRepeats: false——
  // 按住 I 不该连建一串节点，按住 H 不该来回切，按住 F 不该叠开对话框。
  const SingleActivator(CanvasToolKeys.select, includeRepeats: false):
      const CanvasSelectToolIntent(),
  const SingleActivator(CanvasToolKeys.pan, includeRepeats: false):
      const CanvasTogglePanToolIntent(),
  const SingleActivator(CanvasToolKeys.imageNode, includeRepeats: false):
      const CanvasAddNodeIntent(CanvasNodeType.image),
  const SingleActivator(CanvasToolKeys.videoNode, includeRepeats: false):
      const CanvasAddNodeIntent(CanvasNodeType.video),
  const SingleActivator(CanvasToolKeys.textNode, includeRepeats: false):
      const CanvasAddNodeIntent(CanvasNodeType.text),
  const SingleActivator(CanvasToolKeys.lane, includeRepeats: false):
      const CanvasAddLaneIntent(),
  const SingleActivator(CanvasToolKeys.link, includeRepeats: false):
      const CanvasToggleLinkIntent(),
  // 左栏开合（PR-4）。
  CanvasToolKeys.toggleLeftRailMeta: const CanvasToggleLeftRailIntent(),
  CanvasToolKeys.toggleLeftRailControl: const CanvasToggleLeftRailIntent(),
};

/// 画布快捷键层：包裹画布主体（含 Inspector）。
///
/// 焦点归属（D1）：不用 autofocus——同一 FocusScope 内，autofocus 会输给更早挂载的
/// 祖先节点（PL-1 的 app 级 ⌘K 层 `CommandPaletteShortcuts.Focus(autofocus:true)`），
/// 导致按键根本进不到画布快捷键。改为持有显式 FocusNode 并在挂载后 post-frame
/// 显式 requestFocus 抢回焦点。⌘K 未在本层映射，画布持焦时仍冒泡到祖先命令面板层。
class CanvasShortcuts extends ConsumerStatefulWidget {
  const CanvasShortcuts({
    super.key,
    required this.isActive,
    required this.child,
  });

  /// 画布页当前是否是外壳里被激活（可见）的那一层。
  /// false 时本层交出焦点并拒绝再被聚焦——不可见的画布绝不吞
  /// Delete / Backspace / Esc / ⌘A / ⌘0，也不吞工具单键与空格。
  final bool isActive;
  final Widget child;

  /// 画布舞台按下指针时调用：把键盘焦点要回最近的 CanvasShortcuts（不在其下则无事）。
  static void reclaimFocus(BuildContext context) =>
      context.findAncestorStateOfType<_CanvasShortcutsState>()?._reclaimFocus();

  @override
  ConsumerState<CanvasShortcuts> createState() => _CanvasShortcutsState();
}

class _CanvasShortcutsState extends ConsumerState<CanvasShortcuts> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'CanvasShortcuts');

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _claimFocus();
  }

  @override
  void didUpdateWidget(CanvasShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // 必须 post-frame：隐藏期间 canRequestFocus 被祖先拉成 false
      // （focus_manager.dart:536），同帧 requestFocus() 是彻底的 no-op 且不排队；
      // 要等这一帧的 Focus.didUpdateWidget 把开关拨回来。
      // ExcludeFocus 文档（focus_scope.dart:924-926）明说重新可见不会自动复焦。
      _claimFocus();
    }
    // 变 false 不必手动 unfocus：focus_manager.dart:583-594 在
    // descendantsAreFocusable 置 false 时自己会 unfocus(previouslyFocusedChild)。
  }

  void _claimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _focusNode.requestFocus();
    });
  }

  /// 在画布舞台上按下鼠标：把键盘焦点要回本层。在提示词条 / 检查器的文本框里打完字
  /// 再点画布，文本框的 onTapOutside 只会把焦点交还给路由作用域——本层不持焦，
  /// Delete / Esc / 工具单键全都收不到，直到切一次标签才恢复。
  void _reclaimFocus() {
    if (widget.isActive && !_focusNode.hasPrimaryFocus) _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 【这两条 watch 不是渲染用的，是生命周期用的】视口尺寸 provider 的全部读点
    // 都在回调里（本层 _zoom、各处新建节点落点），一个 watcher 都没有 ⇒
    // autoDispose 会在 LayoutBuilder 上报完 setSize 的下一拍就回收它并复位
    // Size.zero，⌘± 于是围绕 (0,0) 而不是视口中心（D2）。
    //
    // 锚挂在本层而不是回 keepAlive：本层是缩放的消费方，且与画布标签同生共死
    // ——换画布时旧 canvasId 的 watcher 当场断开 ⇒ 旧 entry 随之回收，
    // 不再"每开过一张画布就永久多留一份视口尺寸"（BOARD 债）。
    //
    // 锚挂在本层而不是舞台层也是刻意的：本层的孩子是上游传进来的同一个 widget
    // 实例，重建到这里即止（Element.updateChild 认 identical 直接跳过），
    // 上报尺寸不会连带重建整张舞台。
    final String? canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId != null) ref.watch(canvasViewportSizeProvider(canvasId));
    return Shortcuts(
      shortcuts: kCanvasShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          DeleteSelectionIntent: _EditingAwareAction<DeleteSelectionIntent>(
            (_) => _deleteSelection(),
          ),
          SelectAllNodesIntent: _EditingAwareAction<SelectAllNodesIntent>(
            (_) => _selectAll(),
          ),
          CanvasEscapeIntent: CallbackAction<CanvasEscapeIntent>(
            onInvoke: (_) => _escape(),
          ),
          // 缩放同样对文本编辑让位（与删除/全选一致），免得在数值输入框里打字触发缩放。
          CanvasZoomInIntent: _EditingAwareAction<CanvasZoomInIntent>(
            (_) => _zoom(kCanvasZoomStep),
          ),
          CanvasZoomOutIntent: _EditingAwareAction<CanvasZoomOutIntent>(
            (_) => _zoom(1 / kCanvasZoomStep),
          ),
          CanvasZoomResetIntent: _EditingAwareAction<CanvasZoomResetIntent>(
            (_) => _zoomReset(),
          ),
          // 工具单键同样对文本编辑让位：在提示词条 / 检查器里打字时字母就是字母。
          CanvasSelectToolIntent: _EditingAwareAction<CanvasSelectToolIntent>(
            (_) => _selectTool(),
          ),
          CanvasTogglePanToolIntent:
              _EditingAwareAction<CanvasTogglePanToolIntent>(
            (_) => _togglePanTool(),
          ),
          CanvasAddNodeIntent: _EditingAwareAction<CanvasAddNodeIntent>(
            (CanvasAddNodeIntent intent) => _addNode(intent.type),
          ),
          CanvasAddLaneIntent: _EditingAwareAction<CanvasAddLaneIntent>(
            (_) => _addLane(),
          ),
          CanvasToggleLinkIntent: _EditingAwareAction<CanvasToggleLinkIntent>(
            (_) => _toggleLink(),
          ),
          // 左栏开合同样对文本编辑让位：在筛选框里打字时 Ctrl+\ 不收左栏。
          CanvasToggleLeftRailIntent:
              _EditingAwareAction<CanvasToggleLeftRailIntent>(
            (_) => _toggleLeftRail(),
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          skipTraversal: true,
          canRequestFocus: widget.isActive,
          descendantsAreFocusable: widget.isActive, // 连 Inspector 的 TextField 一起排除
          onKeyEvent: _onKeyEvent,
          onFocusChange: _onFocusChange,
          child: widget.child,
        ),
      ),
    );
  }

  /// 按住空格临时平移：按下（含按住时的自动重复）开，松开关。
  ///
  /// 【只在画布本身持焦时接管空格】焦点落在某个控件上——检查器里的按钮 / 下拉框、
  /// 工具条键、提示词条或检查器的文本框——空格是那个控件的「激活」或「打一个空格」，
  /// 画布不能抢。本层的 onKeyEvent 比祖先层的快捷键表（含 WidgetsApp 的
  /// 空格 → ActivateIntent）先拿到事件，不加这道判断就会把它们全部截走。
  ///
  /// 【松开不论焦点在哪都收】按下时在画布、松开前焦点挪进了检查器的文本框，松开事件
  /// 照样冒泡经过本层；只要是空格松开就收，免得卡在平移里。焦点整个离开画布的情形
  /// 由 [_onFocusChange] 兜底。
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final String? canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      if (event.logicalKey != CanvasToolKeys.holdToPan.trigger) {
        return KeyEventResult.ignored;
      }
      final bool wasHeld = ref.read(canvasSpacePanProvider(canvasId));
      ref.read(canvasSpacePanProvider(canvasId).notifier).release();
      return wasHeld && node.hasPrimaryFocus
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (!CanvasToolKeys.holdToPan.accepts(event, HardwareKeyboard.instance)) {
      return KeyEventResult.ignored;
    }
    ref.read(canvasSpacePanProvider(canvasId).notifier).hold();
    return KeyEventResult.handled;
  }

  /// 焦点整个离开画布（开对话框 / 切标签 / 浮层盖上）之后，空格的松开事件不会再
  /// 送到本层——当场收掉临时平移，回来时不会还卡在里面。
  void _onFocusChange(bool hasFocus) {
    if (hasFocus || !mounted) return;
    final String? canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    ref.read(canvasSpacePanProvider(canvasId).notifier).release();
  }

  void _deleteSelection() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    final selected = ref.read(canvasSelectionControllerProvider(canvasId));
    if (selected.isEmpty) return;
    // fire-and-forget：删除自身带 undo/失败 snackbar，无需等待。
    deleteNodesWithUndo(context, ref, canvasId: canvasId, nodeIds: selected);
  }

  void _selectAll() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    final nodes = ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull;
    if (nodes == null) return;
    ref
        .read(canvasSelectionControllerProvider(canvasId).notifier)
        .selectAll(nodes.map((n) => n.id));
  }

  /// Esc 一次剥一层：平移工具 → 回选择；连线模式 → 退出连线；否则清空节点 + 边选择。
  void _escape() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    if (ref.read(canvasToolModeProvider(canvasId)) == CanvasToolMode.pan) {
      ref.read(canvasToolModeProvider(canvasId).notifier).select();
      return;
    }
    if (ref.read(linkModeControllerProvider(canvasId)) != null) {
      ref.read(linkModeControllerProvider(canvasId).notifier).cancel();
      return;
    }
    ref.read(canvasSelectionControllerProvider(canvasId).notifier).clear();
    ref.read(selectedEdgeControllerProvider(canvasId).notifier).clear();
  }

  void _zoom(double factor) {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    final controller = ref.read(canvasTransformControllerProvider(canvasId));
    final size = ref.read(canvasViewportSizeProvider(canvasId));
    controller.value = zoomedTransform(
      current: controller.value,
      factor: factor,
      viewportSize: size,
    );
  }

  void _zoomReset() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    ref.read(canvasTransformControllerProvider(canvasId)).value =
        resetTransform();
  }

  // ===== 工具单键：动作本体在 util/canvas_tool_actions.dart，与工具条共用 =====

  void _selectTool() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    activateSelectTool(ref, canvasId: canvasId);
  }

  void _togglePanTool() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    ref.read(canvasToolModeProvider(canvasId).notifier).togglePan();
  }

  void _addNode(CanvasNodeType type) {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    // fire-and-forget：失败自带错误卡（与工具条建节点同一条路径）。
    addNodeAtViewportCenter(context, ref, canvasId: canvasId, type: type);
  }

  void _addLane() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    addLaneViaDialog(context, ref, canvasId: canvasId);
  }

  void _toggleLink() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    toggleLinkMode(ref, canvasId: canvasId);
  }

  /// 左栏只在打开了画布时才画；没有画布时不动它的状态。
  void _toggleLeftRail() {
    if (ref.read(currentCanvasIdProvider) == null) return;
    ref.read(leftRailProvider.notifier).toggle();
  }
}
