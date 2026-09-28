// 内容区：外层 Stack（标签宿主在下、浮层盖在上）+ 内层保活宿主 + 兜底焦点。
//
// 浮层形态（Screens 稿第 3 屏，2026-09-24）：设置是盖在【仍然可见、被遮暗】的原界面
// 之上的对话框，所以外层不能再用 IndexedStack（它会把底下的标签体整个不画）。
// 三条保证换成了这样的来源，仍是框架保证而非手写纪律：
// - 底下的标签体不会被点穿 ⇒ ShellOverlayLayer 里的 ModalBarrier 吃掉全部指针
// - 浮层打开时标签宿主整体失焦 ⇒ 这里显式 ExcludeFocus（IndexedStack 以前替我们做的事）
// - 画布不再抢键盘 ⇒ CanvasTab(isVisible: false) → CanvasShortcuts.isActive = false
// 内层五槽仍是 IndexedStack：切标签时非活动标签照旧离台（offstage）。
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
    // CanvasShortcuts 的 _claimFocus / SettingsScreen 的夺焦在后代 build 期间注册（晚），
    // post-frame 队列 FIFO ⇒ 晚的赢 ⇒ 切回画布页时画布稳拿焦点、开设置时设置稳拿焦点。
    //
    // 【T8 实测：上面这段不是纸面推理，已有护栏】守它的是
    // test/features/shell/shell_focus_test.dart 的
    // 「V2：浮层打开时画布不可见，Delete 不删节点且 ⌘K 仍可用」那条 ⌘K 断言。
    // 两次变异都把它打红：(a) 本 requestFocus 改成 no-op；(b) 加 hasFocus 守卫。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shellFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool covered = widget.overlay != null;
    return Focus(
      focusNode: _shellFocus,
      skipTraversal: true,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // 浮层盖着时标签宿主整体失焦：以前由 IndexedStack 给隐藏子套的 ExcludeFocus
          // 代劳，现在标签体仍在台上（被遮暗可见），得自己套。
          ExcludeFocus(
            excluding: covered,
            child: ShellKeepAliveHost(activeTab: widget.tab, buildTab: _buildTab),
          ),
          // 浮层不保活：关掉即销毁。
          if (covered)
            ShellOverlayLayer(
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
