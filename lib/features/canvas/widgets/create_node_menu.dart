// 新建菜单（画布重设计稿 › 画布交互「拖线到空白处 → 建节点」「右键菜单」）。
//
// 一个菜单、四个入口：从卡片出端口拖到空白处松手（带「从哪张卡拖出来」的连线上下文）、双击舞台空白、
// 画布持焦时按 Tab、空白处右键菜单里的「新建…」。菜单项判据在 util/create_menu_model.dart，建节点 /
// 连线 / 回滚在 util/canvas_tool_actions.dart（addNodeFromMenu），本文件只管状态、浮层与键盘：
//
//   - canvasMenuRequestProvider：开着哪个菜单、锚在视口哪一点、带不带源节点。入口都只写它
//     （CanvasShortcuts 的 Tab、canvas_view 的双击 / 右键 / 拖线松手）；宿主 CanvasMenuHost 看着它开关。
//   - canvasWireDragProvider：从出端口拖线的实时状态（源节点 + 指针的舞台坐标）。卡片插槽写，
//     实时虚线层与卡片高亮读，Esc 取消。
//   - CanvasMenuHost：包在画布区外层（canvas_view 的 _CanvasBody），菜单经 OverlayPortal 浮到 Overlay 上，
//     锚点跟着画布区走（CompositedTransformFollower，与铃铛下拉同一做法）。点外面关（TapRegion）；
//     焦点整个离开菜单也关（开对话框 / 切标签 / 命令面板盖上来）；关菜单时焦点还给画布，单键快捷键接着能用。
//   - CanvasMenuPanel：菜单本体。新建菜单顶上是搜索框（一打开就持焦，直接打字过滤）；空白处右键菜单没有。
//     ↑ / ↓ 移动高亮（鼠标悬停也移），↵ 执行，Esc 关。
//
// 空白处右键菜单这一版只放「新建…」「导入脚本…」、分隔线、「全选」「适应视图」：「粘贴」「导入媒体」没有
// 后端（画布没有剪贴板，也没有媒体导入的写入路径），按「无后端不画」不放（BOARD 有记）。
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/l10n_x.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/components/ink_icon.dart';
import '../../../theme/icons/ink_glyph.dart';
import '../../../theme/primitives/ink_activatable.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../../settings/util/shortcut_catalog.dart';
import '../../storyboard/widgets/script_import_dialog.dart';
import '../models/canvas_node.dart';
import '../providers/canvas_nodes_controller.dart';
import '../providers/canvas_transform_controller.dart';
import '../util/canvas_tool_actions.dart';
import '../util/create_menu_model.dart';
import '../util/drop_placement.dart';
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
}

/// 一次开菜单的请求。每次开都是一个新实例，关菜单按实例比（identical）：旧菜单迟到的「点外面」/
/// 「失焦」关不掉刚开的新菜单（右键换个地方再右键、右键菜单里点「新建…」都会碰上）。
@immutable
class CanvasMenuRequest {
  const CanvasMenuRequest({
    required this.kind,
    required this.anchor,
    this.sourceNodeId,
  });

  final CanvasMenuKind kind;

  /// 菜单左上角在画布视口里的位置（视口局部坐标）——新节点的左上角也落在这一点。
  final Offset anchor;

  /// 从哪张卡的出端口拖出来的（带连线上下文）；null = 不带上下文。
  final String? sourceNodeId;
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

  /// 开新建菜单；[sourceNodeId] 非空 = 带连线上下文（从那张卡的出端口拖出来的）。
  void openCreate(Offset anchor, {String? sourceNodeId}) =>
      state = CanvasMenuRequest(
        kind: CanvasMenuKind.create,
        anchor: anchor,
        sourceNodeId: sourceNodeId,
      );

  /// 开空白处右键菜单。
  void openBlank(Offset anchor) =>
      state = CanvasMenuRequest(kind: CanvasMenuKind.blank, anchor: anchor);

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

  /// 适应视图（与缩放条「适应」同一个动作）。
  fitView,
}

/// 测试锚点。
class CanvasMenuKeys {
  CanvasMenuKeys._();

  /// 新建菜单的面板。
  static const Key createMenu = ValueKey<String>('canvasMenu.create');

  /// 空白处右键菜单的面板。
  static const Key blankMenu = ValueKey<String>('canvasMenu.blank');

  /// 新建菜单的搜索框。
  static const Key search = ValueKey<String>('canvasMenu.search');
}

// ===== 宿主 =====

/// 新建菜单 / 空白处右键菜单的宿主：包在画布区外层，按 [canvasMenuRequestProvider] 开关浮层、执行选中的项。
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

  /// 关 [request] 那一个菜单（已经换成别的菜单就不动）。[restoreFocus]：菜单拿着焦点（搜索框 / 菜单本身），
  /// 它一拆焦点就落空、画布快捷键全收不到——帧后焦点要是还落空就还给画布（CanvasShortcuts 那边判）。
  /// 焦点是自己走掉的（开了对话框 / 切了标签）就传 false，不抢。
  void _dismiss(CanvasMenuRequest request, {required bool restoreFocus}) {
    if (!identical(ref.read(canvasMenuRequestProvider(widget.canvasId)), request)) {
      return;
    }
    ref.read(canvasMenuRequestProvider(widget.canvasId).notifier).close(request);
    if (restoreFocus) CanvasShortcuts.reclaimFocusIfOrphaned(context);
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
    _dismiss(request, restoreFocus: true);
    final String canvasId = widget.canvasId;
    if (action == CreateMenuAction.lane) {
      addLaneViaDialog(context, ref, canvasId: canvasId);
      return;
    }
    final CanvasNodeType? type =
        createdNodeType(action, source: _nodeById(request.sourceNodeId));
    if (type == null) return;
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
      sourceNodeId: request.sourceNodeId,
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
        _dismiss(request, restoreFocus: true);
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
        _dismiss(request, restoreFocus: true);
        selectAllNodes(ref, canvasId: canvasId);
      case BlankMenuAction.fitView:
        _dismiss(request, restoreFocus: true);
        fitCanvasView(ref, canvasId: canvasId);
    }
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
            onDismiss: () => _dismiss(r, restoreFocus: true),
            onFocusLost: () => _dismiss(r, restoreFocus: false),
            onPickCreate: (CreateMenuAction a) => _pickCreate(r, a),
            onPickBlank: (BlankMenuAction a) => _pickBlank(r, a),
          );
        },
        child: widget.child,
      ),
    );
  }
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
    required this.onFocusLost,
    required this.onPickCreate,
    required this.onPickBlank,
  });

  final String canvasId;
  final LayerLink link;
  final CanvasMenuRequest request;
  final VoidCallback onDismiss;
  final VoidCallback onFocusLost;
  final ValueChanged<CreateMenuAction> onPickCreate;
  final ValueChanged<BlankMenuAction> onPickBlank;

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
        // 稿上的「Shift 1」这一版没有绑定，不画假键位。
        CanvasMenuEntry<BlankMenuAction>(
          value: BlankMenuAction.fitView,
          label: l.canvasBlankMenuFitView,
          glyph: InkGlyph.fit,
        ),
      ],
    ];
  }

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
            // 整块菜单算进文本框的点击区，点行时搜索框不失焦。
            child: TapRegion(
              onTapOutside: (_) => onDismiss(),
              child: TextFieldTapRegion(child: panel),
            ),
          ),
        ),
      ),
    );
  }
}

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
    this.keyHint,
  });

  /// 选中这一行时交回给调用方的值。
  final T value;

  /// 文案；搜索按它过滤。
  final String label;

  /// 左侧 16 号图标（fg4）；null = 留出同宽的空位，文字照样对齐。
  final InkGlyph? glyph;

  /// 右侧键位提示（等宽 10 号 fg5）；null = 不画。
  final String? keyHint;
}

/// 菜单本体（稿：宽 236 / 196、内边距 4、surface4 底 + overlayBorder 边、圆角 6、浮层阴影；
/// 行 28 高、圆角 3、左右 10、图标与文字间距 8；分组之间 1px borderStrong 分隔线、上下各 4）。
///
/// 新建菜单（[searchHint] 非空）顶上是搜索框，一打开就持焦，直接打字就按文字过滤（不区分大小写的包含
/// 匹配），一项都没匹配上时出一行 [emptyText]。空白处右键菜单没有搜索框，焦点落在菜单本身。两种都是
/// ↑ / ↓ 移动高亮（鼠标悬停也移，高亮行 surface5 底）、↵ 执行高亮那一行、Esc 关；点某一行 = 执行它。
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

  /// 空白处右键菜单宽。
  static const double blankWidth = 196;

  /// 行高。
  static const double rowHeight = 28;

  /// 搜索框高：稿 content-box，28 + 上下 1px 边（与左栏筛选框同一个算法）。
  static const double searchHeight = 30;

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

class _CanvasMenuPanelState<T> extends State<CanvasMenuPanel<T>> {
  final FocusNode _panelFocus =
      FocusNode(debugLabel: 'canvasMenu', skipTraversal: true);
  final FocusNode _searchFocus = FocusNode(debugLabel: 'canvasMenu.search');
  String _query = '';
  int _highlight = 0;

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

  List<CanvasMenuEntry<T>> get _visibleEntries => <CanvasMenuEntry<T>>[
        for (final List<CanvasMenuEntry<T>> group in _visibleGroups) ...group,
      ];

  void _onQueryChanged(String query) => setState(() {
        _query = query;
        _highlight = 0;
      });

  void _setHighlight(int index) {
    if (index != _highlight) setState(() => _highlight = index);
  }

  /// ↑ / ↓：首尾相接。
  void _moveHighlight(int delta) {
    final int count = _visibleEntries.length;
    if (count == 0) return;
    setState(() => _highlight = (_highlight.clamp(0, count - 1) + delta) % count);
  }

  void _activateHighlighted() {
    final List<CanvasMenuEntry<T>> entries = _visibleEntries;
    if (entries.isEmpty) return;
    widget.onSelected(entries[_highlight.clamp(0, entries.length - 1)].value);
  }

  /// 菜单的键盘：挂在包着整块菜单的 Focus 上——搜索框持焦时按键先过它自己、再冒泡到这里，
  /// 比 app 层的文本编辑快捷键（↑ / ↓ 挪光标）离焦点更近，所以 ↑ / ↓ / ↵ / Esc 在这里先截住。
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    final bool pressed = event is KeyDownEvent || event is KeyRepeatEvent;
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
    // 没有搜索框（空白处右键菜单）时，菜单开着别的键不往画布漏——不然按一下 I 会在菜单底下建个节点。
    // 有搜索框时放行：字母要进搜索框，画布的单键快捷键在打字时本来就让位。松开事件一律放行
    // （按住空格临时平移之类要靠松开收尾）。
    if (_searchable || event is KeyUpEvent) return KeyEventResult.ignored;
    return KeyEventResult.skipRemainingHandlers;
  }

  @override
  Widget build(BuildContext context) {
    final InkColors c = context.inkColors;
    final List<List<CanvasMenuEntry<T>>> groups = _visibleGroups;
    final int count = groups.fold<int>(
      0,
      (int n, List<CanvasMenuEntry<T>> group) => n + group.length,
    );
    final int highlight = count == 0 ? -1 : _highlight.clamp(0, count - 1);
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
            highlighted: i == highlight,
            onPointerOver: () => _setHighlight(i),
            onTap: () => widget.onSelected(entry.value),
          ),
        );
      }
    }
    if (count == 0) rows.add(_MenuEmptyRow(text: widget.emptyText));
    final String? hint = widget.searchHint;
    return Focus(
      focusNode: _panelFocus,
      onKeyEvent: _onKey,
      onFocusChange: widget.onFocusChange,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: widget.width,
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

/// 一行：左侧 16 号图标（fg4）| 8 | 文字（fg2）| 键位提示（等宽 10 号 fg5）。点击壳走 InkActivatable。
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
    final String? keyHint = entry.keyHint;
    return MouseRegion(
      onEnter: (_) => onPointerOver(),
      onHover: (_) => onPointerOver(),
      child: InkActivatable(
        onTap: onTap,
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
          child: Row(
            children: <Widget>[
              if (glyph != null)
                InkIcon(glyph, size: InkIconSize.sm, color: c.fg4)
              else
                const SizedBox(width: InkIconSize.sm),
              const SizedBox(width: InkSpacing.sm),
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: c.fg2),
                ),
              ),
              if (keyHint != null) ...<Widget>[
                const SizedBox(width: InkSpacing.sm),
                Text(keyHint, style: t.monoSmall.copyWith(color: c.fg5)),
              ],
            ],
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
