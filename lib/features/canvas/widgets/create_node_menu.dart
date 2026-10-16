// 新建菜单 + 右键菜单（画布重设计稿 › 画布交互「拖线到空白处 → 建节点」「右键菜单」）。
//
// 一个宿主、三种菜单：
//   - 新建菜单，四个入口：从卡片出端口拖到空白处松手（带「从哪张卡拖出来」的连线上下文）、双击舞台空白、
//     画布持焦时按 Tab、空白处右键菜单里的「新建…」。菜单项判据在 util/create_menu_model.dart，建节点 /
//     连线 / 回滚在 util/canvas_tool_actions.dart（addNodeFromMenu）。新节点落在菜单锚点上；Tab 开的菜单例外——
//     它的锚点只是视口中心，不带上下文的项与工具条 / I / G / T 同一条路，落在「视口中心 + 散布」。
//   - 空白处右键菜单。
//   - 节点右键菜单（PR-8b）：卡片上右键单击（canvas_view 的卡片插槽在抬起时报上来，按住右键拖动不算）。右键一张没被选中的卡，画布先把
//     选中换成它；右键一张已在多选里的卡，保持多选。可用 / 置灰的判据在 util/node_menu_model.dart，动作在
//     util/canvas_tool_actions.dart（与 Ctrl+↵ / Ctrl+D 共用），「在序列中定位」走
//     sequence/util/view_in_sequence.dart（与标签栏「在序列中查看」共用），删除走 canvas_node_delete.dart。
// 本文件只管状态、浮层与键盘：
//
//   - canvasMenuRequestProvider：开着哪个菜单、锚在视口哪一点、带不带源节点 / 右键的是哪张卡。入口都只写它
//     （CanvasShortcuts 的 Tab、canvas_view 的双击 / 右键 / 拖线松手）；宿主 CanvasMenuHost 看着它开关。
//   - canvasWireDragProvider：从出端口拖线的实时状态（源节点 + 指针的舞台坐标）。卡片插槽写，
//     实时虚线层与卡片高亮读，Esc 取消。
//   - CanvasMenuHost：包在画布区外层（canvas_view 的 _CanvasBody），菜单经 OverlayPortal 浮到 Overlay 上，
//     锚点跟着画布区走（CompositedTransformFollower，与铃铛下拉同一做法）。点外面关（TapRegion）；
//     焦点整个离开菜单也关（开对话框 / 切标签 / 命令面板盖上来）；选了一项 / Esc 关菜单时焦点当场还给画布，
//     单键快捷键接着能用——选的项要开对话框也先还，对话框推上来再自己要走（理由见 _CanvasMenuHostState._dismiss）。
//   - CanvasMenuPanel：菜单本体。新建菜单顶上是搜索框（一打开就持焦，直接打字过滤）；右键菜单没有。
//     ↑ / ↓ 移动高亮（鼠标悬停也移），↵ 执行，Esc 关。项可以置灰（不隐藏；↑ / ↓ 跳过它）、标危险色（删除）、
//     打勾（子菜单里「当前所在」那一项），也可以带子菜单（行尾 ›）：悬停 / 点击 / → / ↵ 打开，← / Esc 收回。
//     子菜单经第二个 OverlayPortal 贴在那一行旁边（右边放不下翻到左边、下面放不下往上长），与主菜单同一个
//     点击区组——点在子菜单里不算「点外面」。
//
// 空白处右键菜单这一版只放「新建…」「导入脚本…」、分隔线、「全选」「适应视图」：「粘贴」「导入媒体」没有
// 后端（画布没有剪贴板，也没有媒体导入的写入路径），按「无后端不画」不放（BOARD 有记）。节点右键菜单同理
// 不放「剪切」「复制」（没有剪贴板）与「当下一镜的首帧」（下一镜已有首帧时是替换还是新建，没有拍板），BOARD 有记。
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/components/ink_primitives.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../sequence/models/sequence_lens.dart';
import '../../sequence/providers/sequence_lens_provider.dart';
import '../../sequence/util/shot_index.dart';
import '../../sequence/util/view_in_sequence.dart';
import '../../settings/util/shortcut_catalog.dart';
import '../../shell/models/shell_state.dart';
import '../../shell/providers/active_project.dart';
import '../../storyboard/widgets/script_import_dialog.dart';
import '../models/canvas_node.dart';
import '../models/style_lane.dart';
import '../providers/canvas_lanes_controller.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_selection_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/inspector_submit_controller.dart';
import '../util/canvas_node_delete.dart';
import '../util/canvas_tool_actions.dart';
import '../util/create_menu_model.dart';
import '../util/drop_placement.dart';
import '../util/lane_tint.dart';
import '../util/node_menu_model.dart';
import 'canvas_shortcuts.dart';

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

/// 空白处右键菜单的项。
enum BlankMenuAction {
  /// 新建…（Tab）：原地换成新建菜单。
  create,

  /// 导入脚本…：开脚本导入框，第一镜落在右键那一点。
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

  /// 子菜单的框（节点右键菜单「加入泳道 ›」）。
  static const Key submenu = ValueKey<String>('canvasMenu.submenu');

  /// 新建菜单的搜索框。
  static const Key search = ValueKey<String>('canvasMenu.search');
}

// ===== 宿主 =====

/// 新建菜单 / 右键菜单的宿主：包在画布区外层，按 [canvasMenuRequestProvider] 开关浮层、执行选中的项。
class CanvasMenuHost extends ConsumerStatefulWidget {
  const CanvasMenuHost({super.key, required this.canvasId, required this.child});

  final String canvasId;

  /// 画布区（舞台 + 舞台上的浮层）。菜单的锚点坐标系就是它。
  final Widget child;

  @override
  ConsumerState<CanvasMenuHost> createState() => _CanvasMenuHostState();
}

class _CanvasMenuHostState extends ConsumerState<CanvasMenuHost> {
  final OverlayPortalController _portal =
      OverlayPortalController(debugLabel: 'canvasMenu');
  final LayerLink _link = LayerLink();
  ProviderSubscription<CanvasMenuRequest?>? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(CanvasMenuHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasId == widget.canvasId) return;
    // 换画布：请求按画布分族，改听新画布的（它从「没开菜单」开始），旧画布的菜单随之收掉。
    _sub?.close();
    _listen();
  }

  void _listen() {
    _sub = ref.listenManual<CanvasMenuRequest?>(
      canvasMenuRequestProvider(widget.canvasId),
      (CanvasMenuRequest? previous, CanvasMenuRequest? next) => _sync(next),
      fireImmediately: true,
    );
  }

  /// 请求 → 浮层。还没挂上时 show() 只是记一笔，OverlayPortal 挂上那一刻生效（与铃铛下拉同）。
  /// 每开一次都 show 一次：后开的菜单压在其它浮层（任务弹层 / 铃铛下拉）之上。
  void _sync(CanvasMenuRequest? request) {
    if (request == null) {
      if (_portal.isShowing) _portal.hide();
    } else {
      _portal.show();
    }
  }

  /// 关 [request] 那一个菜单（已经换成别的菜单就不动），焦点按 [focus] 交接（见 [_MenuFocusHandoff]）。
  void _dismiss(CanvasMenuRequest request, {required _MenuFocusHandoff focus}) {
    if (!identical(ref.read(canvasMenuRequestProvider(widget.canvasId)), request)) {
      return;
    }
    // 先交焦点、再关菜单：菜单的焦点节点卸载时手里要是还拿着主焦点，Flutter 会把焦点还给作用域里上一个
    // 持焦的节点（FocusAttachment.detach → previouslyFocusedChild），也就是画布。卸载发生在帧尾，晚于这一下
    // 接着推上来的对话框的焦点请求——画布赢，按键穿过对话框打到画布上（Backspace 删掉框后面选中的卡）。
    // 当场还给画布，卸载时菜单已经不持焦，对话框随后的焦点请求就是最后一个，不管它自己 autofocus 没有。
    if (focus == _MenuFocusHandoff.toCanvas) CanvasShortcuts.reclaimFocus(context);
    ref.read(canvasMenuRequestProvider(widget.canvasId).notifier).close(request);
    if (focus == _MenuFocusHandoff.toCanvasIfOrphaned) CanvasShortcuts.reclaimFocusIfOrphaned(context);
  }

  CanvasNode? _nodeById(String? id) {
    if (id == null) return null;
    final List<CanvasNode> nodes =
        ref.read(canvasNodesControllerProvider(widget.canvasId)).valueOrNull ??
            const <CanvasNode>[];
    for (final CanvasNode n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  void _pickCreate(CanvasMenuRequest request, CreateMenuAction action) {
    _dismiss(request, focus: _MenuFocusHandoff.toCanvas);
    final String canvasId = widget.canvasId;
    if (action == CreateMenuAction.lane) {
      addLaneViaDialog(context, ref, canvasId: canvasId);
      return;
    }
    final CanvasNode? source = _nodeById(request.sourceNodeId);
    final List<CanvasNode> nodes =
        ref.read(canvasNodesControllerProvider(canvasId)).valueOrNull ?? const <CanvasNode>[];
    final CanvasNodeType? type = createdNodeType(action, source: source, nodes: nodes);
    if (type == null) return;
    // Tab 开在视口中心的菜单、不带上下文的项：与工具条 / I / G / T 同一条路——视口中心 + 散布、判泳道、只单选。
    if (request.viewportCentered && request.sourceNodeId == null) {
      addNodeAtViewportCenter(context, ref, canvasId: canvasId, type: type);
      return;
    }
    addNodeFromMenu(
      context,
      ref,
      canvasId: canvasId,
      type: type,
      placement: menuNodePlacement(
        ref,
        canvasId: canvasId,
        viewportPoint: request.anchor,
      ),
      // 「下一镜」的叙事边从叙事锚点连出（产物卡 ⇒ 它的来源配置节点），其余从拖出来的那张卡。
      sourceNodeId: createdEdgeSourceId(action, source: source, nodes: nodes),
      edge: createdEdge(action),
    );
  }

  void _pickBlank(CanvasMenuRequest request, BlankMenuAction action) {
    final String canvasId = widget.canvasId;
    switch (action) {
      case BlankMenuAction.create:
        // 原地换成新建菜单：同一个锚点，不带上下文。
        ref.read(canvasMenuRequestProvider(canvasId).notifier).openCreate(request.anchor);
      case BlankMenuAction.importScript:
        _dismiss(request, focus: _MenuFocusHandoff.toCanvas);
        // 整条链从右键那一点起铺。导入的镜头不进泳道，按不在道里的卡算世界坐标。
        showScriptImportDialog(
          context,
          canvasId: canvasId,
          origin: viewportToWorld(
            request.anchor,
            ref.read(canvasTransformControllerProvider(canvasId)).value,
          ),
        );
      case BlankMenuAction.selectAll:
        _dismiss(request, focus: _MenuFocusHandoff.toCanvas);
        selectAllNodes(ref, canvasId: canvasId);
      case BlankMenuAction.fitView:
        _dismiss(request, focus: _MenuFocusHandoff.toCanvas);
        fitAllNodes(ref, canvasId: canvasId);
    }
  }

  /// 节点右键菜单的一项。作用范围按 node_menu_model 的口径：生成 / 存为角色只对右键的那一张（菜单只在
  /// 目标恰好一张时让它们可点），复制一份 / 加入泳道 / 在序列中定位 / 删除对整个目标集（多选整批）。
  void _pickNode(CanvasMenuRequest request, NodeMenuPick pick) {
    final String? nodeId = request.nodeId;
    // 「加入泳道 ›」那一行只开子菜单，不会交回来；防御一手。
    if (nodeId == null || pick.action == NodeMenuAction.laneSubmenu) return;
    _dismiss(request, focus: _MenuFocusHandoff.toCanvas);
    final String canvasId = widget.canvasId;
    final Set<String> targets = nodeMenuTargets(
      ref.read(canvasSelectionControllerProvider(canvasId)),
      nodeId,
    );
    switch (pick.action) {
      case NodeMenuAction.generate:
        generateNode(ref, nodeId: nodeId);
      case NodeMenuAction.duplicate:
        duplicateNodes(context, ref, canvasId: canvasId, nodeIds: targets);
      case NodeMenuAction.saveAsCharacter:
        _saveAsCharacter(canvasId, nodeId);
      case NodeMenuAction.laneSubmenu:
        break;
      case NodeMenuAction.moveToLane:
        moveNodesToLane(
          context,
          ref,
          canvasId: canvasId,
          nodeIds: targets,
          laneId: pick.laneId,
        );
      case NodeMenuAction.removeFromLane:
        moveNodesToLane(
          context,
          ref,
          canvasId: canvasId,
          nodeIds: targets,
          laneId: null,
        );
      case NodeMenuAction.locateInSequence:
        viewInSequence(ref, canvasId: canvasId, nodeIds: targets);
      case NodeMenuAction.delete:
        deleteNodesWithUndo(context, ref, canvasId: canvasId, nodeIds: targets);
    }
  }

  /// 存为角色要项目上下文（角色是项目级的）与带图的产物节点；菜单在缺任何一样时已经置灰，这里再兜一手。
  void _saveAsCharacter(String canvasId, String nodeId) {
    final ProjectRef? project = ref.read(activeProjectProvider);
    final CanvasNode? node = _nodeById(nodeId);
    if (project == null || node == null) return;
    saveNodeAsCharacter(
      context,
      ref,
      projectId: project.id,
      canvasId: canvasId,
      node: node,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CanvasMenuRequest? request =
        ref.watch(canvasMenuRequestProvider(widget.canvasId));
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (BuildContext context) {
          final CanvasMenuRequest? r = request;
          if (r == null) return const SizedBox.shrink();
          return _CanvasMenuLayer(
            // 每个请求一份菜单状态：换了菜单（右键菜单 →「新建…」）搜索词与高亮从头来。
            key: ObjectKey(r),
            canvasId: widget.canvasId,
            link: _link,
            request: r,
            onDismiss: () => _dismiss(r, focus: _MenuFocusHandoff.toCanvas),
            onTapOutside: () => _dismiss(r, focus: _MenuFocusHandoff.toCanvasIfOrphaned),
            onFocusLost: () => _dismiss(r, focus: _MenuFocusHandoff.keep),
            onPickCreate: (CreateMenuAction a) => _pickCreate(r, a),
            onPickBlank: (BlankMenuAction a) => _pickBlank(r, a),
            onPickNode: (NodeMenuPick p) => _pickNode(r, p),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// 关菜单时焦点怎么交接（[_CanvasMenuHostState._dismiss]）。
enum _MenuFocusHandoff {
  /// 选了一项 / Esc：菜单此刻一定拿着焦点，也没有别的控件在抢——当场还给画布，单键快捷键接着能用。
  /// 选的项要开对话框（泳道 / 导入脚本… / 存为角色）也一样：对话框推上来时会自己要焦点。
  toCanvas,

  /// 点到菜单外面：同一次按下里，被点到的文本框可能正在拿焦点——帧后焦点还落空才还给画布。
  toCanvasIfOrphaned,

  /// 焦点已经自己离开了菜单（开了对话框 / 切了标签 / 命令面板盖上来）：不动。
  keep,
}

/// 浮层根：铺满 Overlay 的 Align（本身不吃点击）+ 跟着画布区走的一块（与画布区同大），菜单在这一块里
/// 按锚点摆放。
class _CanvasMenuLayer extends ConsumerWidget {
  const _CanvasMenuLayer({
    super.key,
    required this.canvasId,
    required this.link,
    required this.request,
    required this.onDismiss,
    required this.onTapOutside,
    required this.onFocusLost,
    required this.onPickCreate,
    required this.onPickBlank,
    required this.onPickNode,
  });

  final String canvasId;
  final LayerLink link;
  final CanvasMenuRequest request;
  /// 菜单里按 Esc 关。
  final VoidCallback onDismiss;

  /// 点到菜单外面关。
  final VoidCallback onTapOutside;
  final VoidCallback onFocusLost;
  final ValueChanged<CreateMenuAction> onPickCreate;
  final ValueChanged<BlankMenuAction> onPickBlank;
  final ValueChanged<NodeMenuPick> onPickNode;

  /// 焦点整个离开菜单（开了对话框 / 切了标签 / 命令面板盖上来）：菜单跟着收，不留在别的界面上空。
  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) onFocusLost();
  }

  List<List<CanvasMenuEntry<CreateMenuAction>>> _createGroups(
    WidgetRef ref,
    AppLocalizations l,
  ) {
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final String? sourceId = request.sourceNodeId;
    CanvasNode? source;
    if (sourceId != null) {
      for (final CanvasNode n in nodes) {
        if (n.id == sourceId) source = n;
      }
    }
    // 拖出来的那张卡已经不在了（菜单开着时被删）：一项都不出，也不退回不带上下文的那一组。
    final List<List<CreateMenuAction>> groups = sourceId != null && source == null
        ? const <List<CreateMenuAction>>[]
        : createMenuGroups(source: source, nodes: nodes);
    return <List<CanvasMenuEntry<CreateMenuAction>>>[
      for (final List<CreateMenuAction> g in groups)
        <CanvasMenuEntry<CreateMenuAction>>[
          for (final CreateMenuAction a in g) _createEntry(l, a),
        ],
    ];
  }

  List<List<CanvasMenuEntry<BlankMenuAction>>> _blankGroups(AppLocalizations l) {
    final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;
    return <List<CanvasMenuEntry<BlankMenuAction>>>[
      <CanvasMenuEntry<BlankMenuAction>>[
        CanvasMenuEntry<BlankMenuAction>(
          value: BlankMenuAction.create,
          label: l.canvasBlankMenuNew,
          glyph: InkGlyph.nodeLibrary,
          keyHint: CanvasToolKeys.createMenu.keyLabel,
        ),
        // 与工具条「更多 → 导入脚本…」同一句：开的是同一个导入框。
        CanvasMenuEntry<BlankMenuAction>(
          value: BlankMenuAction.importScript,
          label: l.canvasAddImportScript,
          glyph: InkGlyph.script,
        ),
      ],
      <CanvasMenuEntry<BlankMenuAction>>[
        // 键位从快捷键表里取（与设置「快捷键」页同源），按平台出 ⌘A / Ctrl+A。
        CanvasMenuEntry<BlankMenuAction>(
          value: BlankMenuAction.selectAll,
          label: l.canvasBlankMenuSelectAll,
          keyHint: canvasShortcutLabel(
            (Intent intent) => intent is SelectAllNodesIntent,
            isMac: isMac,
          ),
        ),
        // 适应视图 = 适应全部（PR-8b 起有了 Shift+1 的绑定，键位同样从表里取）。
        CanvasMenuEntry<BlankMenuAction>(
          value: BlankMenuAction.fitView,
          label: l.canvasBlankMenuFitView,
          glyph: InkGlyph.fit,
          keyHint: canvasShortcutLabel(
            (Intent intent) => intent is CanvasFitAllIntent,
            isMac: isMac,
          ),
        ),
      ],
    ];
  }

  /// 节点右键菜单（稿：生成 · 复制一份 | 存为角色 · 加入泳道 › · 在序列中定位 | 删除）。不可用的项置灰、
  /// 不隐藏，判据全在 util/node_menu_model.dart。键位提示从快捷键表取，与设置「快捷键」页同源。
  List<List<CanvasMenuEntry<NodeMenuPick>>> _nodeGroups(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l,
  ) {
    final List<CanvasNode> nodes =
        ref.watch(canvasNodesControllerProvider(canvasId)).valueOrNull ??
            const <CanvasNode>[];
    final String? nodeId = request.nodeId;
    CanvasNode? node;
    for (final CanvasNode n in nodes) {
      if (n.id == nodeId) node = n;
    }
    // 右键的那张卡已经不在了（菜单开着时被删）：一项都不出。
    if (nodeId == null || node == null) {
      return const <List<CanvasMenuEntry<NodeMenuPick>>>[];
    }
    final Set<String> targetIds = nodeMenuTargets(
      ref.watch(canvasSelectionControllerProvider(canvasId)),
      nodeId,
    );
    final List<CanvasNode> targets = <CanvasNode>[
      for (final CanvasNode n in nodes)
        if (targetIds.contains(n.id)) n,
    ];
    final List<StyleLane> lanes =
        ref.watch(canvasLanesControllerProvider(canvasId)).valueOrNull ??
            const <StyleLane>[];
    final SequenceLens lens = ref.watch(sequenceLensProvider(canvasId));
    final bool hasProject = ref.watch(activeProjectProvider) != null;
    final CanvasNode? generateTarget = generationTarget(targets);
    // 在忙（提交中 / 生成中）时「生成」置灰，与提示词条「生成」按钮同一个判据。只在真能生成时才订阅提交状态。
    final bool busy = generateTarget != null &&
        _isSubmitBusy(
          ref.watch(inspectorSubmitControllerProvider(generateTarget.id)),
        );
    final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;
    return <List<CanvasMenuEntry<NodeMenuPick>>>[
      <CanvasMenuEntry<NodeMenuPick>>[
        CanvasMenuEntry<NodeMenuPick>(
          value: const NodeMenuPick(NodeMenuAction.generate),
          label: l.canvasNodeMenuGenerate,
          glyph: InkGlyph.run,
          keyHint: canvasShortcutLabel(
            (Intent intent) => intent is CanvasGenerateIntent,
            isMac: isMac,
          ),
          enabled: generateTarget != null && !busy,
        ),
        CanvasMenuEntry<NodeMenuPick>(
          value: const NodeMenuPick(NodeMenuAction.duplicate),
          label: l.canvasNodeMenuDuplicate,
          keyHint: canvasShortcutLabel(
            (Intent intent) => intent is CanvasDuplicateIntent,
            isMac: isMac,
          ),
          enabled: duplicateSources(targets).isNotEmpty,
        ),
      ],
      <CanvasMenuEntry<NodeMenuPick>>[
        CanvasMenuEntry<NodeMenuPick>(
          value: const NodeMenuPick(NodeMenuAction.saveAsCharacter),
          label: l.canvasNodeMenuSaveAsCharacter,
          glyph: InkGlyph.characters,
          enabled: hasProject && characterSource(targets) != null,
        ),
        // 画布上没有泳道 ⇒ 置灰、不带子菜单。
        CanvasMenuEntry<NodeMenuPick>(
          value: const NodeMenuPick(NodeMenuAction.laneSubmenu),
          label: l.canvasNodeMenuAddToLane,
          glyph: InkGlyph.lane,
          enabled: lanes.isNotEmpty,
          submenu: lanes.isEmpty
              ? null
              : _laneGroups(context.inkColors, l, lanes, targets),
        ),
        CanvasMenuEntry<NodeMenuPick>(
          value: const NodeMenuPick(NodeMenuAction.locateInSequence),
          label: l.canvasNodeMenuLocateInSequence,
          glyph: InkGlyph.sequence,
          enabled:
              shotIndexForSelection(lens, selection: targetIds, nodes: nodes) >= 0,
        ),
      ],
      <CanvasMenuEntry<NodeMenuPick>>[
        CanvasMenuEntry<NodeMenuPick>(
          value: const NodeMenuPick(NodeMenuAction.delete),
          label: l.canvasNodeMenuDelete,
          keyHint: canvasShortcutLabel(
            (Intent intent) => intent is DeleteSelectionIntent,
            isMac: isMac,
          ),
          danger: true,
        ),
      ],
    ];
  }

  /// 「加入泳道 ›」的子菜单：本画布的泳道（色点 + 名称，目标全在里面的那一条打勾、不可点）| 移出泳道。
  List<List<CanvasMenuEntry<NodeMenuPick>>> _laneGroups(
    InkColors c,
    AppLocalizations l,
    List<StyleLane> lanes,
    List<CanvasNode> targets,
  ) =>
      <List<CanvasMenuEntry<NodeMenuPick>>>[
        <CanvasMenuEntry<NodeMenuPick>>[
          for (final LaneMenuOption option
              in laneMenuOptions(lanes: lanes, targets: targets))
            CanvasMenuEntry<NodeMenuPick>(
              value: NodeMenuPick.moveToLane(option.lane.id),
              label: option.lane.label.isEmpty ? l.laneUntitled : option.lane.label,
              // 色点与泳道标题栏同一个口径：手动 tint → 风格词推断 → fg6。
              swatch: effectiveLaneTint(
                    tintColor: option.lane.tintColor,
                    stylePrompt: option.lane.stylePrompt,
                  ) ??
                  c.fg6,
              enabled: !option.current,
              checked: option.current,
            ),
        ],
        <CanvasMenuEntry<NodeMenuPick>>[
          CanvasMenuEntry<NodeMenuPick>(
            value: const NodeMenuPick(NodeMenuAction.removeFromLane),
            label: l.canvasNodeMenuRemoveFromLane,
            enabled: canRemoveFromLane(lanes: lanes, targets: targets),
          ),
        ],
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = context.l10n;
    final Size viewport = ref.watch(canvasViewportSizeProvider(canvasId));
    final Widget panel = switch (request.kind) {
      CanvasMenuKind.create => CanvasMenuPanel<CreateMenuAction>(
          key: CanvasMenuKeys.createMenu,
          width: CanvasMenuPanel.createWidth,
          groups: _createGroups(ref, l),
          onSelected: onPickCreate,
          onDismiss: onDismiss,
          emptyText: l.canvasCreateMenuNoMatch,
          searchHint: l.canvasCreateMenuSearchHint,
          onFocusChange: _onFocusChange,
        ),
      CanvasMenuKind.blank => CanvasMenuPanel<BlankMenuAction>(
          key: CanvasMenuKeys.blankMenu,
          width: CanvasMenuPanel.blankWidth,
          groups: _blankGroups(l),
          onSelected: onPickBlank,
          onDismiss: onDismiss,
          emptyText: l.canvasCreateMenuNoMatch,
          onFocusChange: _onFocusChange,
        ),
      // 节点右键菜单与空白处右键菜单同款：宽 196、不带搜索框。
      CanvasMenuKind.node => CanvasMenuPanel<NodeMenuPick>(
          key: CanvasMenuKeys.nodeMenu,
          width: CanvasMenuPanel.blankWidth,
          groups: _nodeGroups(context, ref, l),
          onSelected: onPickNode,
          onDismiss: onDismiss,
          emptyText: l.canvasCreateMenuNoMatch,
          onFocusChange: _onFocusChange,
        ),
    };
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        child: SizedBox.fromSize(
          size: viewport,
          child: CustomSingleChildLayout(
            delegate: _MenuAnchorLayout(request.anchor),
            // 点外面关（与铃铛下拉同一做法）。里面再包一层 TextFieldTapRegion：桌面上点到文本框以外，
            // 文本框会自己失焦——点菜单行时搜索框一失焦，菜单就被当成「焦点离开」收掉，行的点击落空。
            // 整块菜单算进文本框的点击区，点行时搜索框不失焦。点击区组与子菜单共用（tapRegionGroup）：
            // 点在子菜单里不算点外面。
            child: TapRegion(
              groupId: CanvasMenuPanel.tapRegionGroup,
              onTapOutside: (_) => onTapOutside(),
              child: TextFieldTapRegion(child: panel),
            ),
          ),
        ),
      ),
    );
  }
}

/// 提交状态在忙：提交中 / 生成中（与提示词条「生成」按钮的 busy 同一个判据）。
bool _isSubmitBusy(InspectorSubmitState state) =>
    state is InspectorSubmitSubmitting || state is InspectorSubmitRunning;

/// 菜单的左上角对准锚点；右边 / 下边放不下就往回收，不出画布区（视口还没量出来时不收）。
class _MenuAnchorLayout extends SingleChildLayoutDelegate {
  _MenuAnchorLayout(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    if (size.isEmpty) return anchor;
    final double maxX = math.max(0.0, size.width - childSize.width);
    final double maxY = math.max(0.0, size.height - childSize.height);
    return Offset(anchor.dx.clamp(0.0, maxX), anchor.dy.clamp(0.0, maxY));
  }

  @override
  bool shouldRelayout(_MenuAnchorLayout oldDelegate) => oldDelegate.anchor != anchor;
}

/// 新建菜单一项的呈现：文案 + 图标 + 键位提示。键位取工具条用的同一组常量（CanvasToolKeys），
/// 与工具条 tooltip、快捷键表同源。
CanvasMenuEntry<CreateMenuAction> _createEntry(
  AppLocalizations l,
  CreateMenuAction action,
) =>
    switch (action) {
      CreateMenuAction.asFirstFrame => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuAsFirstFrame,
          glyph: InkGlyph.videoConfig,
        ),
      CreateMenuAction.asLastFrame => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuAsLastFrame,
          glyph: InkGlyph.videoConfig,
        ),
      CreateMenuAction.asReference => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuAsReference,
          glyph: InkGlyph.imageConfig,
        ),
      CreateMenuAction.nextShot => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuNextShot,
          glyph: InkGlyph.link,
        ),
      CreateMenuAction.imageConfig => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuImageConfig,
          glyph: InkGlyph.imageConfig,
          keyHint: CanvasToolKeys.imageNode.keyLabel,
        ),
      CreateMenuAction.videoConfig => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuVideoConfig,
          glyph: InkGlyph.videoConfig,
          keyHint: CanvasToolKeys.videoNode.keyLabel,
        ),
      CreateMenuAction.text => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuText,
          glyph: InkGlyph.text,
          keyHint: CanvasToolKeys.textNode.keyLabel,
        ),
      CreateMenuAction.shot => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuShot,
          glyph: InkGlyph.shot,
        ),
      CreateMenuAction.lane => CanvasMenuEntry<CreateMenuAction>(
          value: action,
          label: l.canvasCreateMenuLane,
          glyph: InkGlyph.lane,
          keyHint: CanvasToolKeys.lane.keyLabel,
        ),
    };

// ===== 菜单本体 =====

/// 菜单的一行（呈现参数）。
@immutable
class CanvasMenuEntry<T> {
  const CanvasMenuEntry({
    required this.value,
    required this.label,
    this.glyph,
    this.swatch,
    this.keyHint,
    this.enabled = true,
    this.danger = false,
    this.checked = false,
    this.submenu,
  });

  /// 选中这一行时交回给调用方的值。
  final T value;

  /// 文案；搜索按它过滤。
  final String label;

  /// 左侧 16 号图标（fg4）；null = 留出同宽的空位，文字照样对齐。
  final InkGlyph? glyph;

  /// 左侧色点（子菜单里的泳道行）：8px 方点居中画在图标那一格里；给了就不画 [glyph]。
  final Color? swatch;

  /// 右侧键位提示（等宽 10 号 fg5）；null = 不画。
  final String? keyHint;

  /// false = 置灰（不隐藏）：整行降 0.5、点不动、不可聚焦，↑ / ↓ 跳过它。
  final bool enabled;

  /// 危险操作（删除）：文字用 danger 色。
  final bool danger;

  /// 行尾打勾（子菜单里「当前所在」那一项）。打勾的行不降色——它是「现在就在这儿」，不是「不能用」；
  /// 点不点得动仍看 [enabled]。
  final bool checked;

  /// 非空 = 这一行带子菜单（行尾画 ›）：悬停 / 点击 / → / ↵ 打开，← / Esc 收回；这一行本身不交回。
  final List<List<CanvasMenuEntry<T>>>? submenu;
}

/// 主菜单与子菜单共用的点击区组的类型（只为拿一个独一份的 const 实例当 groupId）。
class _CanvasMenuTapGroup {
  const _CanvasMenuTapGroup();
}

/// 菜单本体（稿：宽 236 / 196、内边距 4、surface4 底 + overlayBorder 边、圆角 6、浮层阴影；
/// 行 28 高、圆角 3、左右 10、图标与文字间距 8；分组之间 1px borderStrong 分隔线、上下各 4）。
///
/// 新建菜单（[searchHint] 非空）顶上是搜索框，一打开就持焦，直接打字就按文字过滤（不区分大小写的包含
/// 匹配），一项都没匹配上时出一行 [emptyText]。右键菜单没有搜索框，焦点落在菜单本身。两种都是
/// ↑ / ↓ 移动高亮（跳过置灰的项；鼠标悬停也移，高亮行 surface5 底）、↵ 执行高亮那一行、Esc 关；点某一行 =
/// 执行它。带子菜单的行：悬停 / 点击 / → / ↵ 打开子菜单（键盘打开时高亮落在子菜单第一项），子菜单开着时
/// ↑ / ↓ / ↵ 归子菜单，← / Esc 收回子菜单；悬停到主菜单别的行也收回。焦点始终在主菜单上。
class CanvasMenuPanel<T> extends StatefulWidget {
  const CanvasMenuPanel({
    super.key,
    required this.width,
    required this.groups,
    required this.onSelected,
    required this.onDismiss,
    required this.emptyText,
    this.searchHint,
    this.onFocusChange,
  });

  /// 新建菜单宽（稿 box-sizing: border-box，含边与内边距）。
  static const double createWidth = 236;

  /// 空白处右键菜单 / 节点右键菜单（及其子菜单）宽。
  static const double blankWidth = 196;

  /// 行高。
  static const double rowHeight = 28;

  /// 搜索框高：稿 content-box，28 + 上下 1px 边（与左栏筛选框同一个算法）。
  static const double searchHeight = 30;

  /// 组间分隔线占的高：1px 线 + 上下各 xs。
  static const double separatorExtent = 1 + InkSpacing.xs * 2;

  /// 菜单框外沿到第一行的距离：1px 边 + xs 内边距。子菜单按它对齐到父行。
  static const double frameInset = 1 + InkSpacing.xs;

  /// 泳道色点边长（与泳道标题栏的色点同一个尺寸）。
  static const double swatchSize = 8;

  /// 主菜单与它的子菜单共用的点击区组：宿主的 TapRegion 与子菜单的 TapRegion 都用它——点在子菜单里
  /// 不算「点外面」。
  static const Object tapRegionGroup = _CanvasMenuTapGroup();

  final double width;

  /// 分组；组与组之间画分隔线。
  final List<List<CanvasMenuEntry<T>>> groups;
  final ValueChanged<T> onSelected;
  final VoidCallback onDismiss;

  /// 一项都没匹配上时那一行的文案。
  final String emptyText;

  /// 搜索框占位文案；null = 没有搜索框。
  final String? searchHint;

  /// 焦点进 / 出整个菜单（搜索框、菜单本身、Tab 进去的某一行都算在里面）。
  final ValueChanged<bool>? onFocusChange;

  @override
  State<CanvasMenuPanel<T>> createState() => _CanvasMenuPanelState<T>();
}

/// 把分组展平成一列（高亮下标按它数）。
List<CanvasMenuEntry<T>> _flattenMenu<T>(List<List<CanvasMenuEntry<T>>> groups) =>
    <CanvasMenuEntry<T>>[
      for (final List<CanvasMenuEntry<T>> group in groups) ...group,
    ];

/// 从 [from] 起往 [delta] 方向找下一个能点的项，首尾相接；[from] < 0 = 从头（往下）或从尾（往上）找。
/// 一个能点的都没有 ⇒ -1。
int _stepEnabled<T>(List<CanvasMenuEntry<T>> entries, int from, int delta) {
  final int n = entries.length;
  if (n == 0) return -1;
  int i = from < 0 ? (delta > 0 ? -1 : n) : from;
  for (int k = 0; k < n; k++) {
    i = (i + delta) % n;
    if (entries[i].enabled) return i;
  }
  return -1;
}

/// 一个没有搜索框的菜单框（给定分组）的总高：上下边 + 内边距、行、组间分隔线。
double _menuFrameHeight<T>(List<List<CanvasMenuEntry<T>>> groups) {
  int rows = 0;
  for (final List<CanvasMenuEntry<T>> group in groups) {
    rows += group.length;
  }
  final int separators = groups.isEmpty ? 0 : groups.length - 1;
  return CanvasMenuPanel.frameInset * 2 +
      rows * CanvasMenuPanel.rowHeight +
      separators * CanvasMenuPanel.separatorExtent;
}

class _CanvasMenuPanelState<T> extends State<CanvasMenuPanel<T>> {
  final FocusNode _panelFocus =
      FocusNode(debugLabel: 'canvasMenu', skipTraversal: true);
  final FocusNode _searchFocus = FocusNode(debugLabel: 'canvasMenu.search');
  final OverlayPortalController _submenuPortal =
      OverlayPortalController(debugLabel: 'canvasMenu.submenu');
  final LayerLink _submenuLink = LayerLink();
  String _query = '';
  int _highlight = 0;

  /// 开着子菜单的那一行（[_visibleEntries] 里的下标）；null = 没开。
  int? _submenuOf;

  /// 子菜单里的高亮（子菜单展平后的下标）；-1 = 还没有（悬停打开时不预选）。
  int _subHighlight = -1;

  bool get _searchable => widget.searchHint != null;

  @override
  void initState() {
    super.initState();
    // 挂上之后再要焦点（与铃铛下拉同一做法）：新建菜单直接能打字，右键菜单的 ↑ / ↓ 直接能用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_searchable ? _searchFocus : _panelFocus).requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _panelFocus.dispose();
    super.dispose();
  }

  List<List<CanvasMenuEntry<T>>> get _visibleGroups =>
      filterMenuGroups<CanvasMenuEntry<T>>(
        widget.groups,
        _query,
        (CanvasMenuEntry<T> entry) => entry.label,
      );

  List<CanvasMenuEntry<T>> get _visibleEntries => _flattenMenu<T>(_visibleGroups);

  /// 此刻真正高亮的那一项：记下的下标还能点就是它，否则退到第一个能点的项；一个都没有 ⇒ -1。
  int _effectiveHighlight(List<CanvasMenuEntry<T>> entries) {
    if (_highlight >= 0 &&
        _highlight < entries.length &&
        entries[_highlight].enabled) {
      return _highlight;
    }
    return _stepEnabled<T>(entries, -1, 1);
  }

  /// 开着的子菜单的项（展平）；没开 / 那一行已经没有子菜单了 ⇒ null。
  List<CanvasMenuEntry<T>>? get _submenuEntries {
    final int? parent = _submenuOf;
    if (parent == null) return null;
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    if (parent >= entries.length) return null;
    final List<List<CanvasMenuEntry<T>>>? groups = entries[parent].submenu;
    return groups == null ? null : _flattenMenu<T>(groups);
  }

  void _onQueryChanged(String query) {
    _closeSubmenu();
    setState(() {
      _query = query;
      _highlight = 0;
    });
  }

  /// 鼠标进入 / 在主菜单某一行里移动：高亮挪过去（置灰的行不高亮）；带子菜单的行顺手打开子菜单，
  /// 主菜单别的行收起开着的子菜单。主菜单不会因为子菜单开合挪位置，所以悬停开合不会来回抖。
  void _onRowHover(int index) {
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    if (index >= entries.length) return;
    if (_submenuOf != null && _submenuOf != index) _closeSubmenu();
    final CanvasMenuEntry<T> entry = entries[index];
    if (!entry.enabled) return;
    if (entry.submenu != null) {
      if (_submenuOf != index) _openSubmenu(index, viaKeyboard: false);
      return;
    }
    if (index != _highlight) setState(() => _highlight = index);
  }

  /// ↑ / ↓：跳过置灰的项，首尾相接。
  void _moveHighlight(int delta) {
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    final int next = _stepEnabled<T>(entries, _effectiveHighlight(entries), delta);
    if (next >= 0 && next != _highlight) setState(() => _highlight = next);
  }

  void _activateHighlighted() {
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    _activate(_effectiveHighlight(entries), viaKeyboard: true);
  }

  /// 执行第 [index] 项：带子菜单的打开子菜单，否则交回给调用方。置灰的项什么都不做。
  void _activate(int index, {required bool viaKeyboard}) {
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    if (index < 0 || index >= entries.length || !entries[index].enabled) return;
    if (entries[index].submenu != null) {
      _openSubmenu(index, viaKeyboard: viaKeyboard);
      return;
    }
    widget.onSelected(entries[index].value);
  }

  /// 打开第 [index] 行的子菜单。键盘打开时高亮落在子菜单第一个能点的项；鼠标打开时不预选。
  void _openSubmenu(int index, {required bool viaKeyboard}) {
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    if (index < 0 || index >= entries.length) return;
    final List<List<CanvasMenuEntry<T>>>? groups = entries[index].submenu;
    if (groups == null || !entries[index].enabled) return;
    setState(() {
      _highlight = index;
      _submenuOf = index;
      _subHighlight =
          viaKeyboard ? _stepEnabled<T>(_flattenMenu<T>(groups), -1, 1) : -1;
    });
    _submenuPortal.show();
  }

  void _closeSubmenu() {
    if (_submenuPortal.isShowing) _submenuPortal.hide();
    if (_submenuOf == null) return;
    setState(() {
      _submenuOf = null;
      _subHighlight = -1;
    });
  }

  void _onSubRowHover(int index) {
    final List<CanvasMenuEntry<T>>? entries = _submenuEntries;
    if (entries == null || index >= entries.length || !entries[index].enabled) {
      return;
    }
    if (index != _subHighlight) setState(() => _subHighlight = index);
  }

  void _moveSubHighlight(int delta) {
    final List<CanvasMenuEntry<T>>? entries = _submenuEntries;
    if (entries == null) return;
    final int next = _stepEnabled<T>(entries, _subHighlight, delta);
    if (next >= 0 && next != _subHighlight) setState(() => _subHighlight = next);
  }

  void _activateSub(int index) {
    final List<CanvasMenuEntry<T>>? entries = _submenuEntries;
    if (entries == null ||
        index < 0 ||
        index >= entries.length ||
        !entries[index].enabled) {
      return;
    }
    widget.onSelected(entries[index].value);
  }

  /// 菜单的键盘：挂在包着整块菜单的 Focus 上——搜索框持焦时按键先过它自己、再冒泡到这里，
  /// 比 app 层的文本编辑快捷键（↑ / ↓ 挪光标）离焦点更近，所以 ↑ / ↓ / ↵ / Esc 在这里先截住。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    final bool pressed = event is KeyDownEvent || event is KeyRepeatEvent;
    if (_submenuOf != null) {
      // 子菜单开着：↑ / ↓ / ↵ 归子菜单，← / Esc 只收回子菜单（回到父行），→ 吞掉。
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
        if (pressed) _moveSubHighlight(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        if (event is KeyDownEvent) _activateSub(_subHighlight);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) _closeSubmenu();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      // → 打开高亮那一行的子菜单；高亮的那一行不带子菜单时照常往下走（有搜索框时是挪光标）。
      final List<CanvasMenuEntry<T>> entries = _visibleEntries;
      final int index = _effectiveHighlight(entries);
      if (index >= 0 && entries[index].submenu != null) {
        if (event is KeyDownEvent) _openSubmenu(index, viaKeyboard: true);
        return KeyEventResult.handled;
      }
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      if (pressed) _moveHighlight(key == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) _activateHighlighted();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) widget.onDismiss();
      return KeyEventResult.handled;
    }
    // 没有搜索框（右键菜单）时，菜单开着别的键不往画布漏——不然按一下 I 会在菜单底下建个节点。
    // 有搜索框时放行：字母要进搜索框，画布的单键快捷键在打字时本来就让位。松开事件一律放行
    // （按住空格临时平移之类要靠松开收尾）。
    if (_searchable || event is KeyUpEvent) return KeyEventResult.ignored;
    return KeyEventResult.skipRemainingHandlers;
  }

  /// 第 [index] 项的上沿到菜单框外沿的距离（与 build 里搜索框 / 行 / 分隔线的排法同一个算法）。
  double _rowOffset(int index) {
    double y = CanvasMenuPanel.frameInset +
        (_searchable ? CanvasMenuPanel.searchHeight + InkSpacing.xs : 0);
    int seen = 0;
    final List<List<CanvasMenuEntry<T>>> groups = _visibleGroups;
    for (int g = 0; g < groups.length; g++) {
      if (g > 0) y += CanvasMenuPanel.separatorExtent;
      for (int k = 0; k < groups[g].length; k++) {
        if (seen == index) return y;
        y += CanvasMenuPanel.rowHeight;
        seen++;
      }
    }
    return y;
  }

  /// 子菜单往哪边长：右边放不下就翻到左边，下面放不下就往上长（底边贴着父行的底边）。按主菜单此刻在屏幕上
  /// 的位置判（主菜单上一帧已经布局好，读它的渲染盒）；还拿不到位置时按默认的右下。窗口尺寸从
  /// [overlayContext]（正在 build 的子菜单浮层）取。
  ({bool left, bool up}) _submenuFlip(
    BuildContext overlayContext,
    int parent,
    List<List<CanvasMenuEntry<T>>> groups,
  ) {
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) {
      return (left: false, up: false);
    }
    final Offset origin = box.localToGlobal(Offset.zero);
    final Size screen = MediaQuery.sizeOf(overlayContext);
    final double subTop =
        origin.dy + _rowOffset(parent) - CanvasMenuPanel.frameInset;
    return (
      left: origin.dx + box.size.width + widget.width > screen.width,
      up: subTop + _menuFrameHeight<T>(groups) > screen.height,
    );
  }

  /// 子菜单（第二个 OverlayPortal 的浮层）：贴着父行摆（CompositedTransformFollower 跟着父行走），
  /// 与主菜单同一个点击区组。
  Widget _buildSubmenu(BuildContext overlayContext) {
    final int? parent = _submenuOf;
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    if (parent == null || parent >= entries.length) return const SizedBox.shrink();
    final List<List<CanvasMenuEntry<T>>>? groups = entries[parent].submenu;
    if (groups == null) return const SizedBox.shrink();
    final ({bool left, bool up}) flip = _submenuFlip(overlayContext, parent, groups);
    final List<Widget> rows = <Widget>[];
    int index = 0;
    for (int g = 0; g < groups.length; g++) {
      if (g > 0) rows.add(const _MenuSeparator());
      for (final CanvasMenuEntry<T> entry in groups[g]) {
        final int i = index++;
        rows.add(
          _MenuRow<T>(
            key: ValueKey<T>(entry.value),
            entry: entry,
            highlighted: i == _subHighlight,
            onPointerOver: () => _onSubRowHover(i),
            onTap: () => _activateSub(i),
          ),
        );
      }
    }
    const double inset = CanvasMenuPanel.frameInset;
    final Alignment targetAnchor = flip.left
        ? (flip.up ? Alignment.bottomLeft : Alignment.topLeft)
        : (flip.up ? Alignment.bottomRight : Alignment.topRight);
    final Alignment followerAnchor = flip.left
        ? (flip.up ? Alignment.bottomRight : Alignment.topRight)
        : (flip.up ? Alignment.bottomLeft : Alignment.topLeft);
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _submenuLink,
        showWhenUnlinked: false,
        targetAnchor: targetAnchor,
        followerAnchor: followerAnchor,
        // 父行在菜单框里缩进了 frameInset：子菜单框的外沿贴着主菜单框的外沿，第一行（往上长时是最后一行）
        // 与父行对齐。
        offset: Offset(flip.left ? -inset : inset, flip.up ? inset : -inset),
        child: TapRegion(
          groupId: CanvasMenuPanel.tapRegionGroup,
          child: TextFieldTapRegion(
            child: _MenuFrame(
              key: CanvasMenuKeys.submenu,
              width: widget.width,
              children: rows,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<List<CanvasMenuEntry<T>>> groups = _visibleGroups;
    final List<CanvasMenuEntry<T>> entries = _flattenMenu<T>(groups);
    final int highlight = _effectiveHighlight(entries);
    final List<Widget> rows = <Widget>[];
    int index = 0;
    for (int g = 0; g < groups.length; g++) {
      if (g > 0) rows.add(const _MenuSeparator());
      for (final CanvasMenuEntry<T> entry in groups[g]) {
        final int i = index++;
        Widget row = _MenuRow<T>(
          key: ValueKey<T>(entry.value),
          entry: entry,
          highlighted: i == highlight,
          onPointerOver: () => _onRowHover(i),
          onTap: () => _activate(i, viaKeyboard: false),
        );
        // 开着子菜单的那一行：子菜单的 CompositedTransformFollower 跟着它走。
        if (i == _submenuOf) {
          row = CompositedTransformTarget(link: _submenuLink, child: row);
        }
        rows.add(row);
      }
    }
    if (entries.isEmpty) rows.add(_MenuEmptyRow(text: widget.emptyText));
    final String? hint = widget.searchHint;
    // 子菜单的 OverlayPortal 放在 Focus 与 Material 里面：子菜单的行在焦点树上仍是菜单的后代（Tab 进去
    // 不算焦点离开菜单），也照样有 Material 祖先。
    return Focus(
      focusNode: _panelFocus,
      onKeyEvent: _onKey,
      onFocusChange: widget.onFocusChange,
      child: Material(
        type: MaterialType.transparency,
        child: OverlayPortal(
          controller: _submenuPortal,
          overlayChildBuilder: _buildSubmenu,
          child: _MenuFrame(
            width: widget.width,
            children: <Widget>[
              if (hint != null)
                _MenuSearchField(
                  focusNode: _searchFocus,
                  hint: hint,
                  onChanged: _onQueryChanged,
                ),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }
}

/// 菜单框：宽 [width]、内边距 xs、surface4 底 + overlayBorder 边、圆角 6、浮层阴影。主菜单与子菜单共用。
class _MenuFrame extends StatelessWidget {
  const _MenuFrame({super.key, required this.width, required this.children});

  final double width;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    return Container(
      width: width,
      padding: const EdgeInsets.all(InkSpacing.xs),
      decoration: BoxDecoration(
        color: c.surface4,
        border: Border.all(color: c.overlayBorder),
        borderRadius: BorderRadius.circular(InkRadius.bentoBtn),
        boxShadow: InkShadow.overlay,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// 搜索框（稿：28 高 content-box、surface2 底 + outline 边、圆角 3；左侧 13 号 search 图标，
/// 占位文字 11 号 fg6）。
class _MenuSearchField extends StatelessWidget {
  const _MenuSearchField({
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    return Container(
      height: CanvasMenuPanel.searchHeight,
      margin: const EdgeInsets.only(bottom: InkSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: InkSpacing.sm),
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(InkRadius.s3),
      ),
      child: Row(
        children: <Widget>[
          InkIcon(InkGlyph.search, size: InkIconSize.xs, color: c.fg6),
          const SizedBox(width: InkSpacing.s6),
          Expanded(
            child: TextField(
              key: CanvasMenuKeys.search,
              focusNode: focusNode,
              onChanged: onChanged,
              style: t.meta.copyWith(color: c.fg2),
              cursorColor: c.accent,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: t.meta.copyWith(color: c.fg6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一行：左侧 16 号图标（fg4）或色点 | 8 | 文字（fg2；危险项 danger）| 键位提示（等宽 10 号 fg5）|
/// 打勾 | 子菜单的 ›。点击壳走 InkActivatable；置灰的行给 null（不可点、不可聚焦）。
class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.entry,
    required this.highlighted,
    required this.onPointerOver,
    required this.onTap,
  });

  final CanvasMenuEntry<T> entry;
  final bool highlighted;

  /// 鼠标进入 / 在行内移动：把高亮挪到这一行（稿：悬停也移动高亮）。
  final VoidCallback onPointerOver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final InkTypography t = context.inkTypography;
    final InkGlyph? glyph = entry.glyph;
    final Color? swatch = entry.swatch;
    final String? keyHint = entry.keyHint;
    final bool enabled = entry.enabled;
    final Widget leading = swatch != null
        ? SizedBox(
            width: InkIconSize.sm,
            child: Center(
              child: InkSquareDot(size: CanvasMenuPanel.swatchSize, color: swatch),
            ),
          )
        : glyph != null
            ? InkIcon(glyph, size: InkIconSize.sm, color: c.fg4)
            : const SizedBox(width: InkIconSize.sm);
    return MouseRegion(
      onEnter: (_) => onPointerOver(),
      onHover: (_) => onPointerOver(),
      child: InkActivatable(
        onTap: enabled ? onTap : null,
        semanticLabel: entry.label,
        selected: highlighted,
        focusRingRadius: BorderRadius.circular(InkRadius.s3),
        builder: (BuildContext context, bool hovered, bool focused) => Container(
          height: CanvasMenuPanel.rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
          decoration: BoxDecoration(
            color: highlighted ? c.surface5 : null,
            borderRadius: BorderRadius.circular(InkRadius.s3),
          ),
          // 置灰（不隐藏）：整行降 0.5。打勾的行（当前所在）照常亮着，只是点不动。
          child: Opacity(
            opacity: enabled || entry.checked ? 1 : 0.5,
            child: Row(
              children: <Widget>[
                leading,
                const SizedBox(width: InkSpacing.sm),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: entry.danger ? c.danger : c.fg2),
                  ),
                ),
                if (keyHint != null) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  Text(keyHint, style: t.monoSmall.copyWith(color: c.fg5)),
                ],
                if (entry.checked) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  InkIcon(InkGlyph.success, size: InkIconSize.s14, color: c.accent),
                ],
                if (entry.submenu != null) ...<Widget>[
                  const SizedBox(width: InkSpacing.sm),
                  Text('›', style: t.body.copyWith(color: c.fg5)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 分组之间的分隔线：1px borderStrong，上下各 4。
class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: InkSpacing.xs),
        color: context.inkColors.borderStrong,
      );
}

/// 一项都没匹配上：一行 fg5 说明。
class _MenuEmptyRow extends StatelessWidget {
  const _MenuEmptyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: CanvasMenuPanel.rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: InkSpacing.s10),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.inkTypography.body.copyWith(color: context.inkColors.fg5),
        ),
      );
}
