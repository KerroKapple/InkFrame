// 画布快捷键注册表（kCanvasKeyRegistry）的结构约束：后续切片往表里追加一行时，这里兜底。
//
// 变异对照：core_canvas_keys.dart 里 L 键去掉 includeRepeats: false ⇒「新键不吃自动重复」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/shortcuts/canvas_key_binding.dart';
import 'package:inkframe/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart';

/// 改写前就吃自动重复的老键（按住 Delete 连删、按住 ⌘+ 连续放大是有意的）。写死在这里：
/// 后续切片加键不许改这份名单——新键一律 includeRepeats: false。
const Set<String> _repeatWhitelist = <String>{
  'canvasDelete',
  'canvasEscape',
  'canvasSelectAll',
  'canvasZoomIn',
  'canvasZoomOut',
  'canvasZoomReset',
};

void main() {
  test('id 唯一，且都是 canvas 开头、不含点', () {
    final List<String> ids = <String>[
      for (final CanvasKeyBinding b in kCanvasKeyRegistry) b.id,
    ];
    expect(ids.toSet().length, ids.length, reason: '有重复 id：$ids');
    for (final String id in ids) {
      expect(id.startsWith('canvas'), isTrue, reason: id);
      expect(id.contains('.'), isFalse, reason: id);
    }
  });

  test('新键不吃自动重复（白名单外每个 SingleActivator 都是 includeRepeats: false）', () {
    for (final CanvasKeyBinding b in kCanvasKeyRegistry) {
      if (_repeatWhitelist.contains(b.id)) continue;
      for (final ShortcutActivator a in b.activators) {
        if (a is! SingleActivator) continue;
        expect(a.includeRepeats, isFalse, reason: '${b.id}：$a');
      }
    }
  });

  test('同一 Intent 类型的绑定共用同一个门槛', () {
    final Map<Type, CanvasKeyGate> gates = <Type, CanvasKeyGate>{};
    for (final CanvasKeyBinding b in kCanvasKeyRegistry) {
      final CanvasKeyGate gate = gates.putIfAbsent(b.intent.runtimeType, () => b.gate);
      expect(gate, b.gate, reason: '${b.id} 与同类型的另一条绑定门槛不同');
    }
  });

  test('kCanvasShortcuts 与注册表一一对应：条数相等、每个激活器映射到所属绑定的 intent', () {
    int activators = 0;
    for (final CanvasKeyBinding b in kCanvasKeyRegistry) {
      for (final ShortcutActivator a in b.activators) {
        activators++;
        expect(identical(kCanvasShortcuts[a], b.intent), isTrue, reason: '${b.id}：$a');
      }
    }
    expect(kCanvasShortcuts.length, activators, reason: '有两条绑定共用了同一个激活器');
  });

  test('没打开画布（context 返回 null）：所有画布绑定都不启用、不消费', () {
    final Map<Type, Action<Intent>> actions =
        buildCanvasActions(kCanvasKeyRegistry, () => null);
    expect(
      actions.keys.toSet(),
      <Type>{for (final CanvasKeyBinding b in kCanvasKeyRegistry) b.intent.runtimeType},
    );
    for (final CanvasKeyBinding b in kCanvasKeyRegistry) {
      final Action<Intent> action = actions[b.intent.runtimeType]!;
      expect(action.isEnabled(b.intent), isFalse, reason: b.id);
      expect(action.consumesKey(b.intent), isFalse, reason: b.id);
    }
  });
}
