// 舞台外的菜单弹层：按一个全局坐标开 InkMenuPanel（左栏大纲 / 序列的右键菜单、工具条「更多」下拉、菜单栏下拉
// 后续都走它——GapsCanvas 稿：「更多」改用画布菜单组件，键位、置灰、↑↓ ↵ Esc 与右键同一套，不再用 Material
// showMenu）。画布舞台上的菜单不走它，走 CanvasMenuHost（锚点跟着画布区走、开关看 canvasMenuRequestProvider）。
//
// 开关由调用方的 [CanvasMenuPopover.anchor] 决定：null ⇒ 收起；给一个全局点 ⇒ 在常挂的 OverlayPortal 浮层里画出来，
// 左上角对准它，右边 / 下边放不下往回收（CanvasMenuAnchorLayout，与宿主同一个）。点外面 / 面板失焦 / Esc ⇒
// onDismiss；选一项 ⇒ onSelected（关不关由调用方定）。与宿主共用 InkMenuPanel.tapRegionGroup：点在子菜单里
// 不算点外面。设计缺口：菜单栏下拉的宽度、相对标签的锚点稿上没给尺寸，这里先只支持「左上角对准一个点」。
import 'package:flutter/material.dart';

import '../../../../theme/components/ink_menu_panel.dart';
import 'canvas_menu_host.dart';

/// 按全局坐标开的菜单弹层，包在触发它的那块界面外层（[child]）。
class CanvasMenuPopover<T> extends StatefulWidget {
  const CanvasMenuPopover({
    super.key,
    required this.anchor,
    required this.groups,
    required this.onSelected,
    required this.onDismiss,
    required this.emptyText,
    this.width = InkMenuPanel.blankWidth,
    this.panelKey,
    required this.child,
  });

  /// 菜单左上角的全局坐标；null = 收起。
  final Offset? anchor;

  /// 分组；组与组之间画分隔线。
  final List<List<InkMenuEntry<T>>> groups;

  /// 选了一项（子菜单里的也算）。弹层不自己收，由调用方决定（通常把 [anchor] 置回 null）。
  final ValueChanged<T> onSelected;

  /// 点外面 / 面板失焦 / Esc。
  final VoidCallback onDismiss;

  /// 一项都没有时那一行的文案。
  final String emptyText;

  /// 菜单宽，缺省与右键菜单同宽。
  final double width;

  /// 挂在面板上的 Key（测试锚点）。
  final Key? panelKey;

  /// 触发菜单的那块界面；弹层不占它的位置。
  final Widget child;

  @override
  State<CanvasMenuPopover<T>> createState() => _CanvasMenuPopoverState<T>();
}

class _CanvasMenuPopoverState<T> extends State<CanvasMenuPopover<T>> {
  final OverlayPortalController _portal =
      OverlayPortalController(debugLabel: 'canvasMenuPopover');

  @override
  void initState() {
    super.initState();
    // 浮层一直挂着，开关只看 anchor：null 时 _buildMenu 画一个空盒子。OverlayPortal 跟着父层重建，
    // 浮层里的菜单自然拿到新的 anchor。还没挂上时 show() 只是记一笔，OverlayPortal 挂上那一刻生效。
    // 不在 didUpdateWidget 里 show / hide：那时还在 build 阶段，OverlayPortal 已挂上时两者都会断言失败。
    _portal.show();
  }

  @override
  void didUpdateWidget(CanvasMenuPopover<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Offset? anchor = widget.anchor;
    if (anchor == null || anchor == oldWidget.anchor) return;
    // 每开一次（含换个点再开）帧后再 show 一次：后开的菜单压在其它浮层之上。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.anchor != null) _portal.show();
    });
  }

  /// 焦点整个离开菜单（点到别的输入框 / 开了对话框 / 切了标签）：当成关菜单。
  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) widget.onDismiss();
  }

  /// 全局点 → Overlay 局部坐标（Overlay 不一定铺满窗口）。Overlay 还没量出来时按原值。
  Offset _toOverlay(Offset global) {
    final RenderObject? box = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return global;
    return box.globalToLocal(global);
  }

  Widget _buildMenu(BuildContext overlayContext) {
    final Offset? anchor = widget.anchor;
    if (anchor == null) return const SizedBox.shrink();
    return CustomSingleChildLayout(
      delegate: CanvasMenuAnchorLayout(_toOverlay(anchor)),
      // 与宿主同一做法：TapRegion 管「点外面」，里面一层 TextFieldTapRegion 让点行时带搜索框的面板不失焦。
      child: TapRegion(
        groupId: InkMenuPanel.tapRegionGroup,
        onTapOutside: (_) => widget.onDismiss(),
        child: TextFieldTapRegion(
          // 每个锚点一份菜单状态：换个点再开，高亮与子菜单从头来。
          child: KeyedSubtree(
            key: ValueKey<Offset>(anchor),
            child: InkMenuPanel<T>(
              key: widget.panelKey,
              width: widget.width,
              groups: widget.groups,
              onSelected: widget.onSelected,
              onDismiss: widget.onDismiss,
              emptyText: widget.emptyText,
              onFocusChange: _onFocusChange,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildMenu,
        child: widget.child,
      );
}
