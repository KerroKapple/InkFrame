// 画布快捷键基建 + 第一批（PL-2）。
//
// 键位 → Intent（Shortcuts）→ Action（Actions）→ provider 副作用；business 逻辑
// 全部下沉到 util / controller，本层只做绑定（SOLID：可测的 shortcut→action 缝）。
//
// 焦点链陷阱：Inspector 的 TextField 聚焦时，Backspace/Delete 必须编辑文本、⌘A
// 必须选中框内文本，而非命中画布。CanvasShortcuts 是 Inspector 字段的祖先，若无
// 防护会抢先命中（本地 Shortcuts 优先于上层 DefaultTextEditingShortcuts）。因此
// 删除/全选两个动作在文本编辑态下 isEnabled=false，按键得以冒泡到文本编辑快捷键。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/current_canvas_id.dart';
import '../providers/link_mode_controller.dart';
import '../providers/selected_edge_controller.dart';
import '../util/canvas_node_delete.dart';
import '../util/canvas_zoom.dart';

// ===== Intents =====

/// 删除当前选中节点（Delete / Backspace）。
class DeleteSelectionIntent extends Intent {
  const DeleteSelectionIntent();
}

/// Esc：连线模式激活则退出连线，否则清空节点 + 边选择。
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

/// 主焦点是否落在某个 EditableText 内——用于让文本编辑抢先于画布删除/全选。
/// 用顶层 [primaryFocus] getter（非 FocusManager.instance 静态单例，遵守 DIP 铁律）。
bool isEditingText() {
  final ctx = primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.findAncestorStateOfType<EditableTextState>() != null;
}

/// 文本编辑态下自动让位的 Action：聚焦文本框时 isEnabled/consumesKey=false，
/// 使按键冒泡到 DefaultTextEditingShortcuts（画布删除/全选专用）。
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
final Map<ShortcutActivator, Intent>
_kCanvasShortcuts = <ShortcutActivator, Intent>{
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
};

/// 画布快捷键层：包裹画布主体（含 Inspector）。
///
/// 焦点归属（D1）：不用 autofocus——同一 FocusScope 内，autofocus 会输给更早挂载的
/// 祖先节点（PL-1 的 app 级 ⌘K 层 `CommandPaletteShortcuts.Focus(autofocus:true)`），
/// 导致按键根本进不到画布快捷键。改为持有显式 FocusNode 并在挂载后 post-frame
/// 显式 requestFocus 抢回焦点。⌘K 未在本层映射，画布持焦时仍冒泡到祖先命令面板层。
class CanvasShortcuts extends ConsumerStatefulWidget {
  const CanvasShortcuts({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CanvasShortcuts> createState() => _CanvasShortcutsState();
}

class _CanvasShortcutsState extends ConsumerState<CanvasShortcuts> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'CanvasShortcuts');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _kCanvasShortcuts,
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
        },
        child: Focus(
          focusNode: _focusNode,
          skipTraversal: true,
          child: widget.child,
        ),
      ),
    );
  }

  void _deleteSelection() {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    final selected = ref.read(canvasSelectionControllerProvider);
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
        .read(canvasSelectionControllerProvider.notifier)
        .selectAll(nodes.map((n) => n.id));
  }

  void _escape() {
    if (ref.read(linkModeControllerProvider) != null) {
      ref.read(linkModeControllerProvider.notifier).cancel();
      return;
    }
    ref.read(canvasSelectionControllerProvider.notifier).clear();
    ref.read(selectedEdgeControllerProvider.notifier).clear();
  }

  void _zoom(double factor) {
    final canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    final controller = ref.read(canvasTransformControllerProvider(canvasId));
    final size = ref.read(canvasViewportSizeProvider);
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
}
