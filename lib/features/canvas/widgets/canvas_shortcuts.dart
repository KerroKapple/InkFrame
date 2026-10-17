// 画布快捷键基建 + 第一批（PL-2）+ 工具单键（浮动工具条）。
//
// 键位 → Intent（Shortcuts）→ Action（Actions）→ provider 副作用；business 逻辑
// 全部下沉到 util / controller，本层只做绑定（SOLID：可测的 shortcut→action 缝）。
//
// 焦点链陷阱：Inspector 的 TextField 聚焦时，Backspace/Delete 必须编辑文本、⌘A
// 必须选中框内文本，而非命中画布。CanvasShortcuts 是 Inspector 字段的祖先，若无
// 防护会抢先命中（本地 Shortcuts 优先于上层 DefaultTextEditingShortcuts）。因此
// 删除/全选两个动作在文本编辑态下 isEnabled=false，按键得以冒泡到文本编辑快捷键。
// 工具单键（V / H / I / G / T / F / L）同一个道理：在提示词条或检查器里打字时，
// 「v」就该是一个「v」，不能把工具切走。
//
// 按住空格临时平移不进快捷键表：它要按下与松开两个事件，Shortcuts 只认按下。
// 在本层 Focus 的 onKeyEvent 里处理（_CanvasShortcutsState._onKeyEvent）。
//
// Ctrl+\（macOS ⌘\）开合左栏（PR-4）：同样对文本编辑让位——在筛选框 / 提示词条里打字时
// 不该把左栏收起来。键位常量在 CanvasToolKeys，导航条「收起」键的 tooltip 与它同源。
//
// Tab = 新建…（新建菜单，开在视口中心；shortcuts/core_canvas_keys.dart 的 openCanvasCreateMenu →
// canvasMenuRequestProvider）。Tab 本来是焦点遍历键，所以它的门槛
// 比别的单键更严：不只对文本编辑让位，而是**只在本层自己持主焦点时**才接管（CanvasKeyGate.canvasFocused）。
// 焦点落在本层子树里的任何控件上（工具条键、检查器按钮、缩放条格子、左栏行、菜单里的行），Tab 都原样
// 放行给 WidgetsApp 的焦点遍历；本层之外的控件按 Tab 根本到不了这里。Shift+Tab 不绑。
// Esc 按 Esc 阶梯一次剥一层（层序表 util/escape_ladder.dart，核心层登记在 providers/canvas_escape_ladder.dart）：
// 层序以 EscapeRungId 为准（输入框那一层 = 失焦、焦点回画布、选中不动）。输入框那一层要本层的 FocusNode，
// 由本层以 local 传入（_CanvasShortcutsState._keyContext）。无事可剥时不消费，Esc 冒泡给祖先。
//
// PR-8b 四个键（画布重设计稿 › 画布交互「快捷键」），全走 CanvasKeyGate.notEditingText——打字时让位：
//   - Ctrl+↵ / ⌘↵ 生成选中的那一张（恰好选中一张可生成的配置卡时生效）。提示词条里的 ⌘↵ 由提示词条
//     自己的 CallbackShortcuts 先接住（它离焦点更近，接住就不再冒泡），本层又对文本编辑让位——同一次按键
//     不会提交两次。
//   - Ctrl+D / ⌘D 复制一份（选中的配置卡各一份）。
//   - Shift+1 适应全部、Shift+2 适应选中（两个平台同键）。
// ⌘0 / Ctrl+0 = 缩放到 100%，视口中心对着的内容不动（shortcuts/core_canvas_keys.dart 的 resetCanvasZoom →
// util/canvas_zoom.dart 的 actualSizeTransform），不回初始相机，也不是适应——两件事各有各的键。
// 节点右键菜单行尾的键位提示从本表取（shortcut_catalog 的 canvasShortcutLabel），与设置「快捷键」页同源。
//
// 键位、门槛、回调、快捷键页文案都登记在注册表（shortcuts/canvas_shortcut_registry.dart 的
// kCanvasKeyRegistry）；本层只把它铺成 Shortcuts（[kCanvasShortcuts]）+ Actions（buildCanvasActions），
// 外加按住空格与焦点归属这两件注册表管不了的事。Intent 与 CanvasToolKeys / isEditingText 搬进了
// shortcuts/，由本文件 re-export，原有 import 路径照常可用。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/canvas_escape_ladder.dart';
import '../providers/canvas_tool_mode.dart';
import '../providers/canvas_transform_controller.dart';
import '../providers/current_canvas_id.dart';
import '../util/escape_ladder.dart';
import 'shortcuts/canvas_key_binding.dart';
import 'shortcuts/canvas_shortcut_registry.dart';
import 'shortcuts/canvas_tool_keys.dart';

export 'shortcuts/canvas_intents.dart';
export 'shortcuts/canvas_tool_keys.dart';

// 键位映射：由注册表派生（每条绑定的每个激活器 → 它的 Intent）；⌘ 与 Ctrl 变体同时注册，跨平台一致
// （桌面 macOS/Windows）。
//
// 公开（P7）：菜单行尾的键位提示（shortcut_catalog 的 canvasShortcutLabel）从这张表取；现有测试也直接拿
// `const SingleActivator(...)` 查它。设置「快捷键」页的清单则直接读注册表。
final Map<ShortcutActivator, Intent> kCanvasShortcuts =
    <ShortcutActivator, Intent>{
  for (final CanvasKeyBinding b in kCanvasKeyRegistry)
    for (final ShortcutActivator a in b.activators) a: b.intent,
};

/// 画布快捷键层：包裹画布主体（含 Inspector）。
///
/// 焦点归属（D1）：不用 autofocus——同一 FocusScope 内，autofocus 会输给更早挂载的
/// 祖先节点（PL-1 的 app 级 ⌘K 层 `CommandPaletteShortcuts.Focus(autofocus:true)`），
/// 导致按键根本进不到画布快捷键。改为持有显式 FocusNode 并在挂载后 post-frame
/// 显式 requestFocus 抢回焦点。⌘K 未在本层映射，画布持焦时仍冒泡到祖先命令面板层。
class CanvasShortcuts extends ConsumerStatefulWidget {
  const CanvasShortcuts({
    super.key,
    required this.isActive,
    required this.child,
  });

  /// 画布页当前是否是外壳里被激活（可见）的那一层。
  /// false 时本层交出焦点并拒绝再被聚焦——不可见的画布绝不吞
  /// Delete / Backspace / Esc / ⌘A / ⌘0，也不吞工具单键与空格。
  final bool isActive;
  final Widget child;

  /// 把键盘焦点当场要回最近的 CanvasShortcuts（不在其下则无事）：画布舞台或空态画布（canvas_empty_state）
  /// 按下指针时；画布菜单（新建 / 空白处右键 / 节点右键）选了一项或按 Esc 收起时（菜单那边见
  /// canvas_menu/canvas_menu_host.dart 的 _CanvasMenuHostState._dismiss）。
  static void reclaimFocus(BuildContext context) =>
      context.findAncestorStateOfType<_CanvasShortcutsState>()?._reclaimFocus();

  /// 画布上的浮层（画布菜单）收掉之后调用：焦点「落空」了才要回本层——主焦点是空的，或者落回了本层
  /// 所在的作用域本身（没有任何具体控件持焦）。被收掉的菜单里的搜索框失焦就落在那儿；不要回来的话
  /// Delete / Esc / 工具单键全都收不到。别的控件已经拿到焦点（点到了别的文本框、开了对话框）就不抢。
  /// 帧后再判：桌面上点到文本框外面，文本框自己的失焦与收菜单是同一次按下里的两件事，谁先谁后不定，
  /// 失焦又在微任务里才落地——收菜单的这一刻还看不出焦点最后落在哪。
  ///
  /// 本层所在的路由上面压着对话框时一律不要（见 _CanvasShortcutsState._onTopRoute）。
  static void reclaimFocusIfOrphaned(BuildContext context) => context
      .findAncestorStateOfType<_CanvasShortcutsState>()
      ?._reclaimFocusIfOrphaned();

  @override
  ConsumerState<CanvasShortcuts> createState() => _CanvasShortcutsState();
}

class _CanvasShortcutsState extends ConsumerState<CanvasShortcuts> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'CanvasShortcuts');

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _claimFocus();
  }

  @override
  void didUpdateWidget(CanvasShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // 必须 post-frame：隐藏期间 canRequestFocus 被祖先拉成 false
      // （focus_manager.dart:536），同帧 requestFocus() 是彻底的 no-op 且不排队；
      // 要等这一帧的 Focus.didUpdateWidget 把开关拨回来。
      // ExcludeFocus 文档（focus_scope.dart:924-926）明说重新可见不会自动复焦。
      _claimFocus();
    }
    // 变 false 不必手动 unfocus：focus_manager.dart:583-594 在
    // descendantsAreFocusable 置 false 时自己会 unfocus(previouslyFocusedChild)。
  }

  void _claimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _focusNode.requestFocus();
    });
  }

  /// 本层所在的路由此刻是不是最上面那一层。上面压着对话框（起名框 / 泳道框 / 导入框 / 命令面板……）时键盘归
  /// 那个框，本层一概不抢焦点——抢过来的话按键穿过对话框打到画布上：Backspace 删掉框后面选中的卡、L / I / T / H / F
  /// 在画布上起作用、Esc 关不掉框。判在本层每一个「要回焦点」的入口上（舞台按下、菜单收起后的帧后补焦点），
  /// 以后新加的入口照样受它约束。不在任何路由里（单测直接挂）按「在最上面」算。
  bool get _onTopRoute => ModalRoute.isCurrentOf(context) ?? true;

  /// 在画布舞台上按下鼠标：把键盘焦点要回本层。在提示词条 / 检查器的文本框里打完字
  /// 再点画布，文本框的 onTapOutside 只会把焦点交还给路由作用域——本层不持焦，
  /// Delete / Esc / 工具单键全都收不到，直到切一次标签才恢复。上面压着对话框时不要（[_onTopRoute]）。
  void _reclaimFocus() {
    if (widget.isActive && _onTopRoute && !_focusNode.hasPrimaryFocus) {
      _focusNode.requestFocus();
    }
  }

  void _reclaimFocusIfOrphaned() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive || !_onTopRoute) return;
      final FocusNode? focused = primaryFocus;
      if (focused == null || identical(focused, _focusNode.enclosingScope)) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 【这两条 watch 不是渲染用的，是生命周期用的】视口尺寸 provider 的全部读点
    // 都在回调里（快捷键缩放 zoomCanvasBy、各处新建节点落点），一个 watcher 都没有 ⇒
    // autoDispose 会在 LayoutBuilder 上报完 setSize 的下一拍就回收它并复位
    // Size.zero，⌘± 于是围绕 (0,0) 而不是视口中心（D2）。
    //
    // 锚挂在本层而不是回 keepAlive：本层是缩放的消费方，且与画布标签同生共死
    // ——换画布时旧 canvasId 的 watcher 当场断开 ⇒ 旧 entry 随之回收，
    // 不再"每开过一张画布就永久多留一份视口尺寸"（BOARD 债）。
    //
    // 锚挂在本层而不是舞台层也是刻意的：本层的孩子是上游传进来的同一个 widget
    // 实例，重建到这里即止（Element.updateChild 认 identical 直接跳过），
    // 上报尺寸不会连带重建整张舞台。
    final String? canvasId = ref.watch(currentCanvasIdProvider);
    if (canvasId != null) {
      ref.watch(canvasViewportSizeProvider(canvasId));
      // Esc 阶梯同理：读点全在按键回调里，后续切片还要在自己的 widget 里往里登记 / 注销层——
      // 本层保活它，与画布标签同生共死。
      ref.watch(canvasEscapeLadderProvider(canvasId));
    }
    return Shortcuts(
      shortcuts: kCanvasShortcuts,
      child: Actions(
        actions: buildCanvasActions(kCanvasKeyRegistry, _keyContext),
        child: Focus(
          focusNode: _focusNode,
          skipTraversal: true,
          canRequestFocus: widget.isActive,
          descendantsAreFocusable: widget.isActive, // 连 Inspector 的 TextField 一起排除
          onKeyEvent: _onKeyEvent,
          onFocusChange: _onFocusChange,
          child: widget.child,
        ),
      ),
    );
  }

  /// 按住空格临时平移：按下（含按住时的自动重复）开，松开关。
  ///
  /// 【只在画布本身持焦时接管空格】焦点落在某个控件上——检查器里的按钮 / 下拉框、
  /// 工具条键、提示词条或检查器的文本框——空格是那个控件的「激活」或「打一个空格」，
  /// 画布不能抢。本层的 onKeyEvent 比祖先层的快捷键表（含 WidgetsApp 的
  /// 空格 → ActivateIntent）先拿到事件，不加这道判断就会把它们全部截走。
  ///
  /// 【松开不论焦点在哪都收】按下时在画布、松开前焦点挪进了检查器的文本框，松开事件
  /// 照样冒泡经过本层；只要是空格松开就收，免得卡在平移里。焦点整个离开画布的情形
  /// 由 [_onFocusChange] 兜底。
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final String? canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      if (event.logicalKey != CanvasToolKeys.holdToPan.trigger) {
        return KeyEventResult.ignored;
      }
      final bool wasHeld = ref.read(canvasSpacePanProvider(canvasId));
      ref.read(canvasSpacePanProvider(canvasId).notifier).release();
      return wasHeld && node.hasPrimaryFocus
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;
    if (!CanvasToolKeys.holdToPan.accepts(event, HardwareKeyboard.instance)) {
      return KeyEventResult.ignored;
    }
    ref.read(canvasSpacePanProvider(canvasId).notifier).hold();
    return KeyEventResult.handled;
  }

  /// 焦点整个离开画布（开对话框 / 切标签 / 浮层盖上）之后，空格的松开事件不会再
  /// 送到本层——当场收掉临时平移，回来时不会还卡在里面。
  void _onFocusChange(bool hasFocus) {
    if (hasFocus || !mounted) return;
    final String? canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return;
    ref.read(canvasSpacePanProvider(canvasId).notifier).release();
  }

  /// 注册表回调拿到的上下文：按键那一刻的画布。没打开画布 ⇒ null，所有画布绑定不启用、不消费。
  CanvasKeyContext? _keyContext() {
    final String? canvasId = ref.read(currentCanvasIdProvider);
    if (canvasId == null) return null;
    return CanvasKeyContext(
      context: context,
      ref: ref,
      canvasId: canvasId,
      canvasFocus: _focusNode,
      // Esc 阶梯里只有本层才给得出的那一层：焦点在子树里的文本框（提示词条 / 检查器 / 左栏筛选框）时，
      // Esc 只让它失焦、把焦点交回画布，选中不动；再按一次才按层序往下剥。
      escapeRungs: <EscapeRungId, EscapeRung>{
        EscapeRungId.textField: (isActive: isEditingText, dismiss: _leaveTextField),
      },
    );
  }

  /// 输入框失焦、焦点回画布。光 unfocus 只会把焦点交给路由作用域——本层不持焦，紧接着的 H / Delete / Esc
  /// 全都收不到；所以要当场把焦点要回本层。失焦提交由各输入框自己负责，这里不额外写入。
  void _leaveTextField() {
    primaryFocus?.unfocus();
    _focusNode.requestFocus();
  }
}
