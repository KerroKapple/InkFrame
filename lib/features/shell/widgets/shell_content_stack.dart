// 内容区：外层 IndexedStack（浮层槽 vs 标签宿主）+ 内层保活宿主 + 兜底焦点。
//
// 两级 IndexedStack 的三条保证都是【框架保证】而非手写纪律：
// - 浮层打开 ⇒ 五个标签体一律 offstage（_IndexedStackElement.debugVisitOnstageChildren）
// - 设置盖着时底下画布不会被点穿（RenderIndexedStack.hitTestChildren 只命中 index 子）
// - 浮层打开时标签宿主整体失焦（IndexedStack 给隐藏子套 ExcludeFocus）
import 'package:flutter/material.dart';

import '../models/shell_state.dart';
import 'shell_keep_alive_host.dart';
import 'shell_overlay_layer.dart';
import 'tabs/canvas_tab.dart';
import 'tabs/export_tab.dart';
import 'tabs/gallery_tab.dart';
import 'tabs/sequence_tab.dart';
import 'tabs/studio_tab.dart';

/// 刻意只收 tab + overlay 两个字段而不是整个 ShellState：canvasId / project 的
/// 变化不该触发 didUpdateWidget 里的焦点重夺（换画布时焦点本就在画布上，
/// 重夺是多余的抖动）。
class ShellContentStack extends StatefulWidget {
  const ShellContentStack({
    super.key,
    required this.tab,
    required this.overlay,
  });

  final ShellTab tab;
  final ShellOverlay? overlay;

  @override
  State<ShellContentStack> createState() => _ShellContentStackState();
}

class _ShellContentStackState extends State<ShellContentStack> {
  final FocusNode _shellFocus = FocusNode(debugLabel: 'ShellContentStack');

  @override
  void dispose() {
    _shellFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShellContentStack old) {
    super.didUpdateWidget(old);
    if (widget.tab == old.tab && widget.overlay == old.overlay) return;
    // 【无条件】—— 千万别加 if (!_shellFocus.hasFocus) 守卫：
    // 切换那一帧画布的 FocusNode 还没被 unfocus，hasFocus 仍为 true → 守卫跳过请求
    // → 随后焦点掉到 ModalScope 的 FocusScope（它在 CommandPaletteShortcuts 之【上】）
    // → 全 app 的 ⌘K 直接失效。
    //
    // 顺序安全性来自【注册时机】：本回调在祖先重建时先注册（早），
    // CanvasShortcuts 的 _claimFocus 在后代 build 期间注册（晚），
    // post-frame 队列 FIFO ⇒ 晚的赢 ⇒ 切回画布页时画布稳拿焦点。
    // 这条是 load-bearing，改动前先读 shell_focus_test.dart。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shellFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _shellFocus,
      skipTraversal: true,
      child: IndexedStack(
        index: widget.overlay == null ? 0 : 1,
        sizing: StackFit.expand,
        children: <Widget>[
          ShellKeepAliveHost(activeTab: widget.tab, buildTab: _buildTab),
          // 浮层不保活：关掉即销毁。
          widget.overlay == null
              ? const SizedBox.shrink()
              : ShellOverlayLayer(
                  key: ValueKey<String>('shellOverlay-${widget.overlay!.name}'),
                  overlay: widget.overlay!,
                ),
        ],
      ),
    );
  }

  /// 与 ShellState.isTabVisible 同义，只是这里手上只有 tab + overlay 两个字段。
  /// 【必须包含 overlay == null 这一项】——一个谓词同时覆盖"切走标签"与
  /// "开浮层遮挡"两种不可见，V2 的两条用例才会走同一条代码路径而非两套特判。
  bool _isVisible(ShellTab t) => widget.overlay == null && widget.tab == t;

  Widget _buildTab(BuildContext context, ShellTab tab) => switch (tab) {
        ShellTab.studio => const StudioTab(),
        ShellTab.canvas => CanvasTab(isVisible: _isVisible(ShellTab.canvas)),
        ShellTab.sequence => const SequenceTab(),
        ShellTab.gallery => GalleryTab(isVisible: _isVisible(ShellTab.gallery)),
        ShellTab.export => const ExportTab(),
      };
}
