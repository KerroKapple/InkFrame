// 画布快捷键注册表的一条：键位 + Intent + 门槛 + 回调 + 快捷键页文案 + 分组。
//
// 画布快捷键原先是一张 Map（键位 → Intent）+ 一串 _xxx() 回调 + 设置页的一份枚举 / switch，三处各写一遍。
// 现在一条 [CanvasKeyBinding] 就是一个动作的全部：CanvasShortcuts 用它铺 Shortcuts + Actions
// （[buildCanvasActions]），设置「快捷键」页用它出行（shortcut_catalog.dart 的 buildShortcutRows）。
// 后续切片加键 = 往 canvas_shortcut_registry.dart 追加一行，不改本层、不改设置页。
//
// 门槛（[CanvasKeyGate]）：
//   - always：只看 enabledWhen（Esc——输入框失焦是阶梯上的一层，不能对文本编辑让位）。
//   - notEditingText：主焦点在文本框里时让位（isEnabled / consumesKey 都 false，按键冒泡给文本编辑）。
//     删除 / 全选 / 缩放 / 工具单键 / 生成 / 复制都走这道——在提示词条里打字时「v」就该是一个「v」。
//   - canvasFocused：只在画布快捷键层**自己**持主焦点时生效（Tab = 新建…）。Tab 是焦点遍历键，焦点落在
//     本层子树里任何一个控件上都要放行给 WidgetsApp 的焦点遍历；文本编辑让位照旧叠在上面。
// 没打开画布（context() 返回 null）⇒ 所有画布绑定都不启用、不消费。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../util/escape_ladder.dart';
import 'canvas_tool_keys.dart';

/// 一条绑定什么时候生效。
enum CanvasKeyGate { always, notEditingText, canvasFocused }

/// 快捷键页上的分组。app = ⌘K / 浮层 Esc 这类非画布行。
enum ShortcutGroup { app, tools, edit, view, generate, panels }

/// 回调拿到的上下文：按键那一刻的画布。
@immutable
class CanvasKeyContext {
  const CanvasKeyContext({
    required this.context,
    required this.ref,
    required this.canvasId,
    required this.canvasFocus,
    this.escapeRungs = const <EscapeRungId, EscapeRung>{},
  });

  final BuildContext context;
  final WidgetRef ref;
  final String canvasId;

  /// 画布快捷键层自己的 FocusNode（[CanvasKeyGate.canvasFocused] 判它是否持主焦点）。
  final FocusNode canvasFocus;

  /// 由 CanvasShortcuts 以 local 传给 Esc 阶梯的层（文字输入框那一层：它要 [canvasFocus]，不进 provider）。
  final Map<EscapeRungId, EscapeRung> escapeRungs;
}

/// 注册表里的一条。
@immutable
class CanvasKeyBinding {
  const CanvasKeyBinding({
    required this.id,
    required this.activators,
    required this.intent,
    required this.gate,
    required this.group,
    required this.label,
    required this.onInvoke,
    this.listed = true,
    this.enabledWhen,
  });

  /// 全局唯一，lowerCamel、以 canvas 开头、不含 '.'（canvasDelete、canvasUndo……）。
  final String id;

  /// 这个动作的全部键位（⌘ 与 Ctrl 变体都列，meta 在 control 前）。
  final List<ShortcutActivator> activators;

  /// 键位映射到的 Intent。同一 Intent 类型的多条绑定（I / G / T 共用 CanvasAddNodeIntent）合成一个 Action。
  final Intent intent;

  /// 生效门槛（同一 Intent 类型的绑定必须共用同一个门槛）。
  final CanvasKeyGate gate;

  /// 快捷键页分组。
  final ShortcutGroup group;

  /// 快捷键页文案。
  final String Function(AppLocalizations l) label;

  /// 按下时做什么；[intent] 是 Shortcuts 交过来的那一个（原样）。
  final void Function(CanvasKeyContext c, Intent intent) onInvoke;

  /// false = 不上快捷键页（如重复触发键）。
  final bool listed;

  /// 门槛之外的附加条件；false ⇒ 不启用、不消费，按键冒泡给祖先（Esc 无事可剥时）。
  final bool Function(CanvasKeyContext c)? enabledWhen;
}

/// 把注册表铺成 Actions 的 actions 表：每个 Intent 类型一个 Action。
///
/// [context] 在每次判启用 / 执行时现取（按键那一刻的画布）；返回 null（没打开画布）⇒ 不启用、不消费。
Map<Type, Action<Intent>> buildCanvasActions(
  List<CanvasKeyBinding> bindings,
  CanvasKeyContext? Function() context,
) {
  final Map<Type, List<CanvasKeyBinding>> byType =
      <Type, List<CanvasKeyBinding>>{};
  for (final CanvasKeyBinding b in bindings) {
    byType.putIfAbsent(b.intent.runtimeType, () => <CanvasKeyBinding>[]).add(b);
  }
  return <Type, Action<Intent>>{
    for (final MapEntry<Type, List<CanvasKeyBinding>> e in byType.entries)
      e.key: _CanvasBindingAction(e.value, context),
  };
}

/// 同一 Intent 类型的全部绑定合成的 Action。
class _CanvasBindingAction extends Action<Intent> {
  _CanvasBindingAction(this._bindings, this._context);

  final List<CanvasKeyBinding> _bindings;
  final CanvasKeyContext? Function() _context;

  /// 交过来的 intent 属于哪一条（Shortcuts 表里的值就是绑定上的同一个 const 实例）；认不出来取第一条。
  CanvasKeyBinding _bindingFor(Intent intent) {
    for (final CanvasKeyBinding b in _bindings) {
      if (identical(b.intent, intent) || b.intent == intent) return b;
    }
    return _bindings.first;
  }

  /// 门槛开着吗（不含 enabledWhen）。
  bool _gateOpen(CanvasKeyContext c, CanvasKeyBinding b) => switch (b.gate) {
        CanvasKeyGate.always => true,
        CanvasKeyGate.notEditingText => !isEditingText(),
        CanvasKeyGate.canvasFocused =>
          c.canvasFocus.hasPrimaryFocus && !isEditingText(),
      };

  @override
  bool isEnabled(Intent intent) {
    final CanvasKeyContext? c = _context();
    if (c == null) return false;
    final CanvasKeyBinding b = _bindingFor(intent);
    if (!_gateOpen(c, b)) return false;
    final bool Function(CanvasKeyContext c)? extra = b.enabledWhen;
    return extra == null || extra(c);
  }

  /// 只看门槛、不看 enabledWhen：ShortcutManager 是在**执行之后**才问 consumesKey 的
  /// （Action.toKeyEventResult），那时 enabledWhen 多半已经变了——Esc 刚剥掉最后一层，再问「还有没有可剥的」
  /// 就是 false，按键会被当成没处理交回给平台。不启用的情形由 [isEnabled] 挡住，根本走不到这里。
  @override
  bool consumesKey(Intent intent) {
    final CanvasKeyContext? c = _context();
    return c != null && _gateOpen(c, _bindingFor(intent));
  }

  @override
  Object? invoke(Intent intent) {
    final CanvasKeyContext? c = _context();
    if (c == null) return null;
    _bindingFor(intent).onInvoke(c, intent);
    return null;
  }
}
