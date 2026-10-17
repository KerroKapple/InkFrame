// 画布菜单的宿主：新建菜单 / 空白处右键菜单 / 节点右键菜单（含「加入泳道 ›」子菜单）共用一个。
//
// CanvasMenuHost 包在画布区外层（canvas_view 的 _CanvasBody），按 canvasMenuRequestProvider（providers/canvas_menu_state.dart）
// 开关浮层：菜单经 OverlayPortal 浮到 Overlay 上，锚点跟着画布区走（CompositedTransformFollower，与铃铛下拉同一
// 做法）。点外面关（TapRegion）；焦点整个离开菜单也关（开对话框 / 切标签 / 命令面板盖上来）；选了一项 / Esc 关菜单
// 时焦点当场还给画布，单键快捷键接着能用——选的项要开对话框也先还，对话框推上来再自己要走（理由见
// _CanvasMenuHostState._dismiss）。
//
// 菜单本体是 theme 层的 InkMenuPanel；项从哪来：新建菜单 = create_menu_entries.dart，空白处 / 节点右键菜单 =
// menu_registry.dart 的表（选中的那一行按表派发，找不到定义就只关菜单）。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../l10n/l10n_x.dart';
import '../../../../theme/components/ink_menu_panel.dart';
import '../../providers/canvas_transform_controller.dart';
import '../../util/create_menu_model.dart';
import '../canvas_shortcuts.dart';
import 'canvas_menu_request.dart';
import 'create_menu_entries.dart';
import 'menu_registry.dart';
import 'node_menu_entries.dart';

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

  /// 新建菜单的一项：先关菜单（焦点当场还给画布），再建节点 / 开泳道框。
  void _pickCreate(CanvasMenuRequest request, CreateMenuAction action) {
    _dismiss(request, focus: _MenuFocusHandoff.toCanvas);
    runCreateMenuPick(
      context,
      ref,
      canvasId: widget.canvasId,
      request: request,
      action: action,
    );
  }

  /// 空白处右键菜单的一项：按注册表派发。各项自己决定先不先关菜单（「新建…」不关，原地换成新建菜单）；
  /// 找不到定义 ⇒ 只关菜单。
  void _pickBlank(CanvasMenuRequest request, String picked) {
    void dismiss() => _dismiss(request, focus: _MenuFocusHandoff.toCanvas);
    final CanvasMenuItemDef? item = menuItemForPick(CanvasMenuScope.blank, picked);
    if (item == null) {
      dismiss();
      return;
    }
    item.run(
      CanvasMenuContext(
        context: context,
        ref: ref,
        canvasId: widget.canvasId,
        request: request,
        targets: const <String>{},
        picked: picked,
        dismiss: dismiss,
      ),
    );
  }

  /// 节点右键菜单的一项：按注册表派发（node_menu_entries.dart 的 runNodeMenuPick），各项先关菜单再动作。
  void _pickNode(CanvasMenuRequest request, String picked) {
    final String? nodeId = request.nodeId;
    if (nodeId == null) return;
    unawaited(
      runNodeMenuPick(
        context,
        ref,
        canvasId: widget.canvasId,
        nodeId: nodeId,
        picked: picked,
        dismiss: () => _dismiss(request, focus: _MenuFocusHandoff.toCanvas),
      ),
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
            onPickBlank: (String picked) => _pickBlank(r, picked),
            onPickNode: (String picked) => _pickNode(r, picked),
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
  /// 选的项要开对话框（泳道 / 导入剧本… / 存为角色）也一样：对话框推上来时会自己要焦点。
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
  final ValueChanged<String> onPickBlank;
  final ValueChanged<String> onPickNode;

  /// 焦点整个离开菜单（开了对话框 / 切了标签 / 命令面板盖上来）：菜单跟着收，不留在别的界面上空。
  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) onFocusLost();
  }

  /// 节点右键菜单（项在 menu_registry.dart 的表里）。右键的那张卡已经不在了 ⇒ 一项都不出。
  List<List<InkMenuEntry<String>>> _nodeGroups(BuildContext context, WidgetRef ref) {
    final String? nodeId = request.nodeId;
    if (nodeId == null) return const <List<InkMenuEntry<String>>>[];
    return buildNodeMenuGroups(context, ref, canvasId: canvasId, nodeId: nodeId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l = context.l10n;
    final Size viewport = ref.watch(canvasViewportSizeProvider(canvasId));
    final Widget panel = switch (request.kind) {
      CanvasMenuKind.create => InkMenuPanel<CreateMenuAction>(
          key: CanvasMenuKeys.createMenu,
          width: InkMenuPanel.createWidth,
          groups: buildCreateMenuGroups(ref, l, canvasId: canvasId, request: request),
          onSelected: onPickCreate,
          onDismiss: onDismiss,
          emptyText: l.canvasCreateMenuNoMatch,
          searchHint: l.canvasCreateMenuSearchHint,
          onFocusChange: _onFocusChange,
        ),
      CanvasMenuKind.blank => InkMenuPanel<String>(
          key: CanvasMenuKeys.blankMenu,
          width: InkMenuPanel.blankWidth,
          groups: buildMenuGroups(
            CanvasMenuScope.blank,
            CanvasMenuContext(
              context: context,
              ref: ref,
              canvasId: canvasId,
              request: request,
              targets: const <String>{},
            ),
          ),
          onSelected: onPickBlank,
          onDismiss: onDismiss,
          emptyText: l.canvasCreateMenuNoMatch,
          onFocusChange: _onFocusChange,
        ),
      // 节点右键菜单与空白处右键菜单同款：宽 196、不带搜索框。
      CanvasMenuKind.node => InkMenuPanel<String>(
          key: CanvasMenuKeys.nodeMenu,
          width: InkMenuPanel.blankWidth,
          groups: _nodeGroups(context, ref),
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
            delegate: CanvasMenuAnchorLayout(request.anchor),
            // 点外面关（与铃铛下拉同一做法）。里面再包一层 TextFieldTapRegion：桌面上点到文本框以外，
            // 文本框会自己失焦——点菜单行时搜索框一失焦，菜单就被当成「焦点离开」收掉，行的点击落空。
            // 整块菜单算进文本框的点击区，点行时搜索框不失焦。点击区组与子菜单共用（tapRegionGroup）：
            // 点在子菜单里不算点外面。
            child: TapRegion(
              groupId: InkMenuPanel.tapRegionGroup,
              onTapOutside: (_) => onTapOutside(),
              child: TextFieldTapRegion(child: panel),
            ),
          ),
        ),
      ),
    );
  }
}

/// 菜单的左上角对准锚点；右边 / 下边放不下就往回收，不出所在的那一块（画布区 / Overlay；尺寸还没量出来时
/// 不收）。画布宿主与舞台外的 CanvasMenuPopover 共用。
class CanvasMenuAnchorLayout extends SingleChildLayoutDelegate {
  CanvasMenuAnchorLayout(this.anchor);

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
  bool shouldRelayout(CanvasMenuAnchorLayout oldDelegate) => oldDelegate.anchor != anchor;
}
