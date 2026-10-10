// InkActivatable：可达性的**唯一点击壳**——指针与键盘走同一条回调。
//
// 由来（BOARD 210）：#249 只把 `ink_shell_tab_bar` 的标签 chip 改成了可键盘到达，
// 于是同一个外壳上出现了两套语义——chip 能 Tab + 回车，紧挨着它的 `InkGhostButton`
// 与标签栏右侧那排动作还是裸 `GestureDetector` + `Semantics`。正解不是把那段代码
// 再抄两遍（BOARD 原话：「每处各写一遍 focus 环必然走形」），而是抽到这里，三处
// 一起换。
//
// 性质逐条就是 #249 在 chip 上立下的那几条，一条不少地搬过来：
// 1. `FocusableActionDetector` 包在 `GestureDetector` **外面**——指针命中路径
//    一字不变，只多出「焦点与键盘激活」这一层。
// 2. 激活键显式写成 shortcuts（Enter / NumpadEnter / Space），**不吃 WidgetsApp
//    的默认表**：theme 层是可复用组件，不该假设宿主一定是 MaterialApp；显式写
//    出来也让「哪些键能激活」变成读得到的契约，而不是框架默认值。
// 3. `onInvoke` 调的是**同一个** [onTap]——键盘与指针不可能走岔。
// 4. `enabled = onTap != null` ⇒ 不可点的就不可聚焦，不会出现「聚焦上去按回车
//    什么都不发生」的假可达。所以禁用态请给 `null`，**不要空闭包**
//    （test/quality/no_dead_interactive_test.dart）。
// 5. 焦点环走【前景装饰】：前景装饰不参与布局（`DecoratedBox` 的 foreground 位
//    不量子、`Container.foregroundDecoration` 不进 `_paddingIncludingDecoration`），
//    所以加环不撑宽控件，既有视觉与宽度阈值实测都不动。
//
// 【它不认识任何 feature 模型】只收回调、文案与样式参数——分层闸在
// test/quality/no_reverse_layer_import_test.dart。
//
// hover 走显式的 `MouseRegion`，**不走 `FocusableActionDetector.onShowHoverHighlight`**：
// 后者被 `FocusManager.highlightMode` 门控（触摸模式下压根不报），会把「鼠标在
// 上面」偷换成「该不该画 hover 高亮」两件事。显式 MouseRegion 让光标与 hover 色
// 与改造前逐字相同。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../tokens.dart';

/// Enter / Space → 激活。见本文件头注性质 2：显式写出来，不吃宿主默认表。
const Map<ShortcutActivator, Intent> _kActivate = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

/// 呈现回调：[hovered] / [focused] 是包装件持有的交互态，由各家自己决定长什么样。
typedef InkActivatableBuilder = Widget Function(
  BuildContext context,
  bool hovered,
  bool focused,
);

/// 焦点环的**唯一出处**：一圈 1px accent（与选中态同色但形状不同——选中是 2px
/// 下边框，焦点是一整圈细边）。失焦返回 null，调用方直接把它塞给
/// `foregroundDecoration` 即可。
///
/// 抽成函数而不是让三处各自 `Border.all(color: ...)`：颜色/粗细只有一处可改，
/// 这正是 BOARD 210 说「各写一遍必然走形」要防的事。
BoxDecoration? inkFocusRing(
  InkColors colors, {
  required bool focused,
  BorderRadius? borderRadius,
}) =>
    !focused
        ? null
        : BoxDecoration(
            border: Border.all(color: colors.accent),
            borderRadius: borderRadius,
          );

class InkActivatable extends StatefulWidget {
  const InkActivatable({
    super.key,
    required this.onTap,
    required this.builder,
    this.semanticLabel,
    this.selected,
    this.tooltip,
    this.focusRingRadius,
    this.paintFocusRing = true,
  });

  /// null = 此刻不可点，**并且不可聚焦**（头注性质 4）。不要传空闭包。
  final VoidCallback? onTap;

  final InkActivatableBuilder builder;

  /// 无障碍标签。文案由调用方给（theme 层不碰 ARB）。
  final String? semanticLabel;

  /// `Semantics.selected`。默认 null = 不声明"有没有选中态"这件事，
  /// 普通按钮照旧不带这个标志。
  final bool? selected;

  /// 非 null ⇒ 在 Semantics 与交互层之间插一层 [Tooltip]（chip 的层序）。
  final String? tooltip;

  /// 焦点环圆角，跟随子件的外形（圆角按钮给同一个值，方盒不给）。
  final BorderRadius? focusRingRadius;

  /// false ⇒ 本件不画环，由 [builder] 自己把 [inkFocusRing] 贴到它**已有**的盒上。
  /// 标签 chip 走这条：环要和那 2px 琥珀下边框共用同一个 Container 才对得齐。
  final bool paintFocusRing;

  @override
  State<InkActivatable> createState() => _InkActivatableState();
}

class _InkActivatableState extends State<InkActivatable> {
  /// 由本 State 持有，而不是让 FocusableActionDetector 自己造一个内部节点：
  /// 测试要断言「焦点此刻落在哪个控件」，拿得到节点才测得了。
  final FocusNode _focus = FocusNode();
  bool _hover = false;
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = widget.onTap;
    final bool enabled = onTap != null;

    Widget child = FocusableActionDetector(
      focusNode: _focus,
      enabled: enabled,
      onShowFocusHighlight: (bool v) {
        if (v != _focused) setState(() => _focused = v);
      },
      shortcuts: _kActivate,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          // 与鼠标点击**同一个回调**：键盘与指针不可能走岔。
          onInvoke: (ActivateIntent intent) {
            onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _withRing(context, widget.builder(context, _hover, _focused)),
      ),
    );

    // hover 与光标在 FocusableActionDetector **之外**（见头注）。
    child = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: child,
    );

    final String? tooltip = widget.tooltip;
    if (tooltip != null) child = Tooltip(message: tooltip, child: child);

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: child,
    );
  }

  Widget _withRing(BuildContext context, Widget child) {
    if (!widget.paintFocusRing) return child;
    final BoxDecoration? ring = inkFocusRing(
      context.inkColors,
      focused: _focused,
      borderRadius: widget.focusRingRadius,
    );
    if (ring == null) return child;
    // 前景位的 DecoratedBox 只画不量：子件尺寸一点不变（头注性质 5）。
    return DecoratedBox(
      decoration: ring,
      position: DecorationPosition.foreground,
      child: child,
    );
  }
}
