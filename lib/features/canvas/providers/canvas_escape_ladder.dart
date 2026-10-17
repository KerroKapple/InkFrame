// CanvasEscapeLadder — 画布的 Esc 阶梯：按层序表（util/escape_ladder.dart）一次剥一层。
//
// 构造时登记五档核心层：菜单 / 拖线 / 连线模式 / 平移工具 / 选中。文字输入框那一层不在这里——
// 它要画布自己的 FocusNode（失焦后把焦点交回画布），由 CanvasShortcuts 每次按 Esc 时以 local 传入。
// @ 补全弹层、查找条、框选、工具锁是空位：后续切片在自己 widget 的 initState / dispose 里
// register / unregister，登记了立刻参与判序，判序代码不改。
//
// autoDispose + 按画布分族：订阅锚在 CanvasShortcuts.build（与视口尺寸同一种写法），
// 与画布标签同生共死。纯 UI 态，不落库；Esc 不进撤销栈。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../util/escape_ladder.dart';
import '../widgets/create_node_menu.dart';
import 'canvas_selection_controller.dart';
import 'canvas_tool_mode.dart';
import 'link_mode_controller.dart';
import 'selected_edge_controller.dart';

/// 一张画布的 Esc 阶梯：登记表 + 按层序判、剥。
class CanvasEscapeLadder {
  final Map<EscapeRungId, EscapeRung> _rungs = <EscapeRungId, EscapeRung>{};

  /// 登记 [id] 这一层；同 id 重复登记 = 覆盖（以后者为准）。
  void register(EscapeRungId id, EscapeRung rung) {
    _rungs[id] = rung;
  }

  /// 注销 [id] 这一层；之后不再参与判序。
  void unregister(EscapeRungId id) {
    _rungs.remove(id);
  }

  /// 此刻按 Esc 会剥哪一层（不剥）；无事可剥 ⇒ null。[local] 覆盖同 id 的登记层。
  EscapeRungId? peek({
    Map<EscapeRungId, EscapeRung> local = const <EscapeRungId, EscapeRung>{},
  }) =>
      resolveEscape(_withLocal(local));

  /// 剥掉层序最靠前的生效层；剥了一层 ⇒ true，无事可剥 ⇒ false。[local] 覆盖同 id 的登记层。
  bool handle({
    Map<EscapeRungId, EscapeRung> local = const <EscapeRungId, EscapeRung>{},
  }) {
    final Map<EscapeRungId, EscapeRung> rungs = _withLocal(local);
    final EscapeRungId? id = resolveEscape(rungs);
    if (id == null) return false;
    rungs[id]!.dismiss();
    return true;
  }

  Map<EscapeRungId, EscapeRung> _withLocal(
    Map<EscapeRungId, EscapeRung> local,
  ) =>
      local.isEmpty
          ? _rungs
          : <EscapeRungId, EscapeRung>{..._rungs, ...local};
}

/// 画布 [canvasId] 的 Esc 阶梯（已登记五档核心层）。
final canvasEscapeLadderProvider =
    Provider.autoDispose.family<CanvasEscapeLadder, String>(
  (ref, String canvasId) => CanvasEscapeLadder()
    // 菜单开着、焦点却在画布上：先关菜单。
    ..register(EscapeRungId.menu, (
      isActive: () => ref.read(canvasMenuRequestProvider(canvasId)) != null,
      dismiss: () =>
          ref.read(canvasMenuRequestProvider(canvasId).notifier).close(),
    ))
    // 拖线中：取消拖线（松手时不连线、不开菜单）。
    ..register(EscapeRungId.wireDrag, (
      isActive: () => ref.read(canvasWireDragProvider(canvasId)) != null,
      dismiss: () =>
          ref.read(canvasWireDragProvider(canvasId).notifier).cancel(),
    ))
    // 连线模式：退出连线，不动选中。
    ..register(EscapeRungId.linkMode, (
      isActive: () => ref.read(linkModeControllerProvider(canvasId)) != null,
      dismiss: () =>
          ref.read(linkModeControllerProvider(canvasId).notifier).cancel(),
    ))
    // 平移工具：回到选择，不动选中。
    ..register(EscapeRungId.panTool, (
      isActive: () =>
          ref.read(canvasToolModeProvider(canvasId)) == CanvasToolMode.pan,
      dismiss: () =>
          ref.read(canvasToolModeProvider(canvasId).notifier).select(),
    ))
    // 最后一层：清空节点选中与连线选中（两个都清）。
    ..register(EscapeRungId.selection, (
      isActive: () =>
          ref.read(canvasSelectionControllerProvider(canvasId)).isNotEmpty ||
          ref.read(selectedEdgeControllerProvider(canvasId)) != null,
      dismiss: () {
        ref.read(canvasSelectionControllerProvider(canvasId).notifier).clear();
        ref.read(selectedEdgeControllerProvider(canvasId).notifier).clear();
      },
    )),
  name: 'canvasEscapeLadderProvider',
);
