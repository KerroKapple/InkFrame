// 设置「快捷键」页的数据源：从真正注册的 Shortcuts 表反推出的只读清单。
//
// 这张清单的全部价值在于「不会和绑定分叉」——所以本测试钉的不是某一行长什么样，
// 而是两条结构性保证：① 表里每个 Intent 都被认领（加绑定忘了认领 = 红）；
// ② 每个认领过的动作在两个平台上都至少有一个键位（键位 label 漏了 = 红）。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/settings/util/shortcut_catalog.dart';

Map<ShortcutAction, List<String>> _byAction({required bool isMac}) =>
    <ShortcutAction, List<String>>{
      for (final ShortcutRow r in buildShortcutRows(isMac: isMac))
        r.action: r.keys,
    };

void main() {
  test('画布快捷键表里每个 Intent 都被清单认领', () {
    for (final Intent intent in kCanvasShortcuts.values) {
      expect(
        shortcutActionOf(intent),
        isNotNull,
        reason: '未认领的 Intent：${intent.runtimeType}——加了绑定就要给它一个动作名',
      );
    }
  });

  test('每个动作在两个平台上都至少有一个键位', () {
    for (final bool isMac in <bool>[true, false]) {
      final Map<ShortcutAction, List<String>> rows = _byAction(isMac: isMac);
      expect(
        rows.keys.toSet(),
        ShortcutAction.values.toSet(),
        reason: 'isMac=$isMac 下有动作没出键位（键位 label 没认领？）',
      );
      for (final MapEntry<ShortcutAction, List<String>> e in rows.entries) {
        expect(e.value, isNotEmpty, reason: '${e.key} 的键位列表为空');
      }
    }
  });

  test('macOS：⌘ 变体上屏，Ctrl 变体与小键盘重复项不上屏', () {
    final Map<ShortcutAction, List<String>> rows = _byAction(isMac: true);
    expect(rows[ShortcutAction.commandPalette], <String>['⌘K']);
    expect(rows[ShortcutAction.overlayDismiss], <String>['Esc']);
    expect(rows[ShortcutAction.canvasSelectAll], <String>['⌘A']);
    expect(rows[ShortcutAction.canvasZoomIn], <String>['⌘=']);
    expect(rows[ShortcutAction.canvasZoomOut], <String>['⌘-']);
    expect(rows[ShortcutAction.canvasZoomReset], <String>['⌘0']);
    expect(rows[ShortcutAction.canvasDelete], <String>['Delete', 'Backspace']);
    expect(rows[ShortcutAction.canvasEscape], <String>['Esc']);
  });

  test('Windows：Ctrl 变体上屏，⌘ 变体不上屏', () {
    final Map<ShortcutAction, List<String>> rows = _byAction(isMac: false);
    expect(rows[ShortcutAction.commandPalette], <String>['Ctrl+K']);
    expect(rows[ShortcutAction.canvasSelectAll], <String>['Ctrl+A']);
    expect(rows[ShortcutAction.canvasZoomReset], <String>['Ctrl+0']);
    expect(rows[ShortcutAction.canvasDelete], <String>['Delete', 'Backspace']);
  });

  test('行序 = ShortcutAction 声明序（与表的遍历序无关）', () {
    final List<ShortcutAction> order = buildShortcutRows(isMac: true)
        .map((ShortcutRow r) => r.action)
        .toList();
    expect(order, ShortcutAction.values);
  });

  group('formatShortcutActivator', () {
    test('小键盘 / 同义重复键不上屏（清单只留主键盘那一个）', () {
      for (final LogicalKeyboardKey k in <LogicalKeyboardKey>[
        LogicalKeyboardKey.numpadAdd,
        LogicalKeyboardKey.numpadSubtract,
        LogicalKeyboardKey.numpad0,
        LogicalKeyboardKey.add,
      ]) {
        expect(
          formatShortcutActivator(
            SingleActivator(k, meta: true),
            isMac: true,
          ),
          isNull,
          reason: '$k 是重复项',
        );
      }
    });

    test('组合修饰键按平台符号拼', () {
      const SingleActivator shiftA =
          SingleActivator(LogicalKeyboardKey.keyA, meta: true, shift: true);
      expect(formatShortcutActivator(shiftA, isMac: true), '⌘⇧A');
      const SingleActivator ctrlShiftA =
          SingleActivator(LogicalKeyboardKey.keyA, control: true, shift: true);
      expect(formatShortcutActivator(ctrlShiftA, isMac: false), 'Ctrl+Shift+A');
    });

    test('未认领的按键返回 null（不猜 keyLabel，宁可被上面的覆盖测试打红）', () {
      expect(
        formatShortcutActivator(
          const SingleActivator(LogicalKeyboardKey.f7),
          isMac: true,
        ),
        isNull,
      );
    });
  });
}
