// 画布菜单的状态：从出端口拖线的实时状态（canvasWireDragProvider）与此刻开着哪个菜单
// （canvasMenuRequestProvider）。纯 UI 态，不落库。
//
// 放在 providers/ 而不是菜单的 widget 目录：Esc 阶梯（canvas_escape_ladder.dart）要读写它们，provider 层不
// 反向依赖 widgets/。widget 侧（空白处右键菜单的项、测试锚点）留在 widgets/canvas_menu/canvas_menu_request.dart，
// 那个文件原样转出本文件，barrel create_node_menu.dart 对外导出不变。
//
// 入口都只写 canvasMenuRequestProvider：shortcuts/core_canvas_keys.dart 的 Tab（openCanvasCreateMenu）、
// canvas_view 的双击 / 右键 / 拖线松手（松手由卡片插槽 stage/node_card_slot.dart 报上来）；宿主
// widgets/canvas_menu/canvas_menu_host.dart 的 CanvasMenuHost 看着它开关浮层。拖线由卡片插槽写，实时虚线层与
// 卡片高亮读，Esc 取消。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===== 拖线状态 =====

/// 一次从出端口的拖线：源节点 + 指针此刻的舞台坐标。
@immutable
class WireDrag {
  const WireDrag({required this.sourceNodeId, required this.pointer});

  final String sourceNodeId;

  /// 指针在舞台坐标系里的位置（世界坐标 + kStageOrigin，与 displacedNodes 同一个坐标系）。
  final Offset pointer;
}

/// 从出端口拖线的实时状态，按画布分族。纯 UI 态，不落库。
final canvasWireDragProvider =
    AutoDisposeNotifierProviderFamily<WireDragController, WireDrag?, String>(
  WireDragController.new,
  name: 'canvasWireDragProvider',
);

class WireDragController extends AutoDisposeFamilyNotifier<WireDrag?, String> {
  @override
  WireDrag? build(String canvasId) => null;

  /// 从 [sourceNodeId] 的出端口开始拖线。
  void start(String sourceNodeId, Offset pointer) =>
      state = WireDrag(sourceNodeId: sourceNodeId, pointer: pointer);

  /// 指针移动。不是这条拖线（已被 Esc 取消）就不动。
  void moveTo(String sourceNodeId, Offset pointer) {
    if (state?.sourceNodeId != sourceNodeId) return;
    state = WireDrag(sourceNodeId: sourceNodeId, pointer: pointer);
  }

  /// 松手：收掉拖线并把它交回，由舞台判落点。已被 Esc 取消（或不是这条）⇒ null。
  WireDrag? finish(String sourceNodeId) {
    final WireDrag? drag = state;
    if (drag == null || drag.sourceNodeId != sourceNodeId) return null;
    state = null;
    return drag;
  }

  /// Esc：取消拖线——松手时不连线、不开菜单，不落任何写入。
  void cancel() {
    if (state != null) state = null;
  }
}

// ===== 菜单请求 =====

/// 菜单种类。
enum CanvasMenuKind {
  /// 新建菜单（带搜索框）。
  create,

  /// 空白处右键菜单。
  blank,

  /// 节点右键菜单（PR-8b）。
  node,
}

/// 一次开菜单的请求。每次开都是一个新实例，关菜单按实例比（identical）：旧菜单迟到的「点外面」/
/// 「失焦」关不掉刚开的新菜单（右键换个地方再右键、右键菜单里点「新建…」都会碰上）。
@immutable
class CanvasMenuRequest {
  const CanvasMenuRequest({
    required this.kind,
    required this.anchor,
    this.sourceNodeId,
    this.nodeId,
    this.viewportCentered = false,
  });

  final CanvasMenuKind kind;

  /// 菜单左上角在画布视口里的位置（视口局部坐标）——新节点的左上角也落在这一点。
  final Offset anchor;

  /// 从哪张卡的出端口拖出来的（带连线上下文）；null = 不带上下文。
  final String? sourceNodeId;

  /// 节点右键菜单：右键的是哪张卡（[kind] 为 [CanvasMenuKind.node] 时非空）。
  final String? nodeId;

  /// Tab 开在视口中心的新建菜单：锚点不是用户点出来的位置。不带上下文的项与工具条 / I / G / T 同一条路，
  /// 落在「视口中心 + 散布」（canvas_tool_actions.addNodeAtViewportCenter），不落在锚点上。
  final bool viewportCentered;
}

/// 画布上此刻开着的菜单，按画布分族。纯 UI 态，不落库。
final canvasMenuRequestProvider = AutoDisposeNotifierProviderFamily<
    CanvasMenuController, CanvasMenuRequest?, String>(
  CanvasMenuController.new,
  name: 'canvasMenuRequestProvider',
);

class CanvasMenuController
    extends AutoDisposeFamilyNotifier<CanvasMenuRequest?, String> {
  @override
  CanvasMenuRequest? build(String canvasId) => null;

  /// 开新建菜单；[sourceNodeId] 非空 = 带连线上下文（从那张卡的出端口拖出来的）。[viewportCentered]：Tab 开的、
  /// 锚点就是视口中心（见 [CanvasMenuRequest.viewportCentered]）。
  void openCreate(
    Offset anchor, {
    String? sourceNodeId,
    bool viewportCentered = false,
  }) =>
      state = CanvasMenuRequest(
        kind: CanvasMenuKind.create,
        anchor: anchor,
        sourceNodeId: sourceNodeId,
        viewportCentered: viewportCentered,
      );

  /// 开空白处右键菜单。
  void openBlank(Offset anchor) =>
      state = CanvasMenuRequest(kind: CanvasMenuKind.blank, anchor: anchor);

  /// 开节点右键菜单：[nodeId] 是右键的那张卡（选中由调用方先处理好：没选中的先单选它）。
  void openNode(Offset anchor, String nodeId) => state = CanvasMenuRequest(
        kind: CanvasMenuKind.node,
        anchor: anchor,
        nodeId: nodeId,
      );

  /// 关菜单。给了 [only] 就只关它那一个——已经换成别的菜单了就不动。
  void close([CanvasMenuRequest? only]) {
    final CanvasMenuRequest? current = state;
    if (current == null) return;
    if (only != null && !identical(current, only)) return;
    state = null;
  }
}
