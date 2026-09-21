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
    //
    // 【T8 实测：上面这段不是纸面推理，已有护栏】守它的是
    // test/features/shell/shell_focus_test.dart 的
    // 「V2：浮层打开时画布不可见，Delete 不删节点且 ⌘K 仍可用」那条 ⌘K 断言。
    // 两次变异都把它打红：(a) 本 requestFocus 改成 no-op；(b) 加 hasFocus 守卫。
    // 焦点探针显示，两种变异下开浮层后 primaryFocus 都变成
    // _ModalScopeState 的 FocusScope，⌘K 面板计数为 0。
    //
    // T7 复评当时"构造不出证伪场景"的原因：⌘K 只在【画布先抢过焦点】的路径上
    // 才会掉链子。若当前标签里没有 CanvasShortcuts 这类主动夺焦者，焦点一直
    // 停在 CommandPaletteShortcuts 自己的 autofocus 兜底节点上，切标签不改变
    // 它，⌘K 自然全程可用——那条路径下本段确实无作用面，但那不是全部路径。
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
