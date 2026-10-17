// 设置「快捷键」页的数据源：从真正注册的 Shortcuts 表反推出的只读清单。
//
// 这张清单的全部价值在于「不会和绑定分叉」——所以本测试钉的不是某一行长什么样，
// 而是两条结构性保证：① 注册表里每条上屏的绑定在两个平台都出得了字（键位 label 漏了 = 红）；
// ② 每个动作在两个平台上都至少有一个键位。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/shortcuts/canvas_key_binding.dart';
import 'package:inkframe/features/canvas/widgets/shortcuts/canvas_shortcut_registry.dart';
import 'package:inkframe/features/settings/util/shortcut_catalog.dart';

Map<String, List<String>> _byAction({required bool isMac}) =>
    <String, List<String>>{
      for (final ShortcutRow r in buildShortcutRows(isMac: isMac))
        r.id: r.keys,
    };

/// 期望行序，写死成改写前的 ShortcutAction 枚举声明序：全局两条在前，画布的在后（编辑 / 缩放 / 工具）。
const List<String> _expectedOrder = <String>[
  'commandPalette',
  'overlayDismiss',
  'canvasDelete',
  'canvasEscape',
  'canvasSelectAll',
  'canvasDuplicate',
  'canvasGenerate',
  'canvasZoomIn',
  'canvasZoomOut',
  'canvasZoomReset',
  'canvasFitAll',
  'canvasFitSelection',
  'canvasSelectTool',
  'canvasPanTool',
  'canvasHoldPan',
  'canvasAddImageNode',
  'canvasAddVideoNode',
  'canvasAddTextNode',
  'canvasAddLane',
  'canvasOpenCreateMenu',
  'canvasToggleLink',
  'canvasToggleLeftRail',
];

void main() {
  test('注册表里每条上屏的绑定在两个平台都出得了字', () {
    for (final bool isMac in <bool>[true, false]) {
      for (final CanvasKeyBinding b in kCanvasKeyRegistry) {
        if (!b.listed) continue;
        expect(
          b.activators
              .map((ShortcutActivator a) => formatShortcutActivator(a, isMac: isMac))
              .whereType<String>(),
          isNotEmpty,
          reason: 'isMac=$isMac 下 ${b.id} 一个键位都出不了字（键位 label 没认领？）',
        );
      }
    }
  });

  test('每个动作在两个平台上都至少有一个键位', () {
    for (final bool isMac in <bool>[true, false]) {
      final Map<String, List<String>> rows = _byAction(isMac: isMac);
      expect(
        rows.keys.toSet(),
        _expectedOrder.toSet(),
        reason: 'isMac=$isMac 下有动作没出键位（键位 label 没认领？）',
      );
      for (final MapEntry<String, List<String>> e in rows.entries) {
        expect(e.value, isNotEmpty, reason: '${e.key} 的键位列表为空');
      }
    }
  });

  test('macOS：⌘ 变体上屏，Ctrl 变体与小键盘重复项不上屏', () {
    final Map<String, List<String>> rows = _byAction(isMac: true);
    expect(rows['commandPalette'], <String>['⌘K']);
    expect(rows['overlayDismiss'], <String>['Esc']);
    expect(rows['canvasSelectAll'], <String>['⌘A']);
    expect(rows['canvasZoomIn'], <String>['⌘=']);
    expect(rows['canvasZoomOut'], <String>['⌘-']);
    expect(rows['canvasZoomReset'], <String>['⌘0']);
    expect(rows['canvasDelete'], <String>['Delete', 'Backspace']);
    expect(rows['canvasEscape'], <String>['Esc']);
  });

  test('画布工具单键：不带修饰键，两个平台同一个字母', () {
    for (final bool isMac in <bool>[true, false]) {
      final Map<String, List<String>> rows = _byAction(isMac: isMac);
      expect(rows['canvasSelectTool'], <String>['V']);
      expect(rows['canvasPanTool'], <String>['H']);
      expect(rows['canvasAddImageNode'], <String>['I']);
      expect(rows['canvasAddVideoNode'], <String>['G']);
      expect(rows['canvasAddTextNode'], <String>['T']);
      expect(rows['canvasAddLane'], <String>['F']);
      expect(rows['canvasToggleLink'], <String>['L']);
    }
  });

  // 按住空格不在 kCanvasShortcuts 里（要按下与松开两个事件），清单从 CanvasShortcuts
  // 自己用的那个常量收它——不收的话，设置页上这条键位根本不存在。
  test('按住空格临时平移：两个平台都列「Space」，与 CanvasShortcuts 用的是同一个键', () {
    expect(CanvasToolKeys.holdToPan.trigger, LogicalKeyboardKey.space);
    for (final bool isMac in <bool>[true, false]) {
      expect(_byAction(isMac: isMac)['canvasHoldPan'], <String>['Space']);
    }
  });

  // PR-4：左栏开合进清单。键位与导航条收起键的 tooltip 同源（CanvasToolKeys.toggleLeftRail*），
  // 这里钉的是「设置页上真的列得出来、而且按平台各出一个」。
  test('左栏开合：macOS 列 ⌘\\，Windows 列 Ctrl+\\，与 CanvasToolKeys 是同一组激活器', () {
    expect(kCanvasShortcuts[CanvasToolKeys.toggleLeftRailMeta], isA<CanvasToggleLeftRailIntent>());
    expect(kCanvasShortcuts[CanvasToolKeys.toggleLeftRailControl], isA<CanvasToggleLeftRailIntent>());
    expect(_byAction(isMac: true)['canvasToggleLeftRail'], <String>[r'⌘\']);
    expect(_byAction(isMac: false)['canvasToggleLeftRail'], <String>[r'Ctrl+\']);
    expect(
      formatShortcutActivator(CanvasToolKeys.toggleLeftRailControl, isMac: false),
      r'Ctrl+\',
      reason: '导航条收起键的 tooltip 走的就是这一句',
    );
  });

  // PR-8a：Tab = 新建…进清单。键位与空白处右键菜单「新建…」行尾的提示同源（CanvasToolKeys.createMenu）。
  test('新建…：两个平台都列「Tab」，与 CanvasToolKeys.createMenu 是同一个键', () {
    expect(CanvasToolKeys.createMenu, LogicalKeyboardKey.tab);
    expect(
      kCanvasShortcuts[const SingleActivator(CanvasToolKeys.createMenu, includeRepeats: false)],
      isA<CanvasOpenCreateMenuIntent>(),
    );
    for (final bool isMac in <bool>[true, false]) {
      expect(
        _byAction(isMac: isMac)['canvasOpenCreateMenu'],
        <String>['Tab'],
      );
    }
  });

  // PR-8b：生成选中 / 复制一份 / 适应全部 / 适应选中进清单。键位与节点右键菜单、空白处右键菜单行尾的提示
  // 同源（CanvasToolKeys）；回车按平台换字，与提示词条「生成」按钮尾标（submitShortcutLabel）一字不差。
  test('生成选中：macOS 列 ⌘↵，Windows 列 Ctrl+Enter（与提示词条「生成」按钮尾标同一个写法）', () {
    expect(kCanvasShortcuts[CanvasToolKeys.generateMeta], isA<CanvasGenerateIntent>());
    expect(kCanvasShortcuts[CanvasToolKeys.generateControl], isA<CanvasGenerateIntent>());
    expect(_byAction(isMac: true)['canvasGenerate'], <String>['⌘↵']);
    expect(_byAction(isMac: false)['canvasGenerate'], <String>['Ctrl+Enter']);
  });

  test('复制一份：macOS 列 ⌘D，Windows 列 Ctrl+D', () {
    expect(kCanvasShortcuts[CanvasToolKeys.duplicateMeta], isA<CanvasDuplicateIntent>());
    expect(kCanvasShortcuts[CanvasToolKeys.duplicateControl], isA<CanvasDuplicateIntent>());
    expect(_byAction(isMac: true)['canvasDuplicate'], <String>['⌘D']);
    expect(_byAction(isMac: false)['canvasDuplicate'], <String>['Ctrl+D']);
  });

  test('适应全部 / 适应选中：Shift+1 / Shift+2，两个平台同键（macOS 写 ⇧）', () {
    expect(kCanvasShortcuts[CanvasToolKeys.fitAll], isA<CanvasFitAllIntent>());
    expect(kCanvasShortcuts[CanvasToolKeys.fitSelection], isA<CanvasFitSelectionIntent>());
    expect(_byAction(isMac: true)['canvasFitAll'], <String>['⇧1']);
    expect(_byAction(isMac: false)['canvasFitAll'], <String>['Shift+1']);
    expect(_byAction(isMac: true)['canvasFitSelection'], <String>['⇧2']);
    expect(_byAction(isMac: false)['canvasFitSelection'], <String>['Shift+2']);
  });

  test('⌘0 / Ctrl+0 仍是缩放复位，不是适应', () {
    expect(
      kCanvasShortcuts[const SingleActivator(LogicalKeyboardKey.digit0, control: true)],
      isA<CanvasZoomResetIntent>(),
    );
  });

  test('四个新键都不吃按住不放的自动重复（按住 Ctrl+D 不该连复制一串）', () {
    for (final SingleActivator a in <SingleActivator>[
      CanvasToolKeys.generateMeta,
      CanvasToolKeys.generateControl,
      CanvasToolKeys.duplicateMeta,
      CanvasToolKeys.duplicateControl,
      CanvasToolKeys.fitAll,
      CanvasToolKeys.fitSelection,
    ]) {
      expect(a.includeRepeats, isFalse, reason: '$a');
    }
  });

  // 菜单行尾的键位提示从快捷键表里取（空白处右键菜单的「全选」），按平台出字。
  test('canvasShortcutLabel：按平台取表里第一条能出字的绑定；没有匹配 ⇒ null', () {
    bool selectAll(Intent intent) => intent is SelectAllNodesIntent;
    expect(canvasShortcutLabel(selectAll, isMac: true), '⌘A');
    expect(canvasShortcutLabel(selectAll, isMac: false), 'Ctrl+A');
    expect(
      canvasShortcutLabel((Intent intent) => false, isMac: true),
      isNull,
    );
    // 节点右键菜单「生成」行尾：与 Windows 下的 Ctrl+Enter、macOS 下的 ⌘↵ 一致。
    bool generate(Intent intent) => intent is CanvasGenerateIntent;
    expect(canvasShortcutLabel(generate, isMac: true), '⌘↵');
    expect(canvasShortcutLabel(generate, isMac: false), 'Ctrl+Enter');
  });

  test('canvasBindingActivator / canvasBindingLabel：按 id 取本平台第一个出得了字的键位；没有这个 id ⇒ null', () {
    expect(
      canvasBindingActivator('canvasSelectAll', isMac: true),
      same(const SingleActivator(LogicalKeyboardKey.keyA, meta: true)),
    );
    expect(
      canvasBindingActivator('canvasSelectAll', isMac: false),
      same(const SingleActivator(LogicalKeyboardKey.keyA, control: true)),
    );
    // ⌘+ / 小键盘 + 是重复项、不出字：取到的是主键盘的 ⌘=。
    expect(canvasBindingLabel('canvasZoomIn', isMac: true), '⌘=');
    expect(canvasBindingLabel('canvasZoomIn', isMac: false), 'Ctrl+=');
    expect(canvasBindingLabel('canvasNoSuchKey', isMac: true), isNull);
    expect(canvasBindingActivator('canvasNoSuchKey', isMac: false), isNull);
  });

  test('Windows：Ctrl 变体上屏，⌘ 变体不上屏', () {
    final Map<String, List<String>> rows = _byAction(isMac: false);
    expect(rows['commandPalette'], <String>['Ctrl+K']);
    expect(rows['canvasSelectAll'], <String>['Ctrl+A']);
    expect(rows['canvasZoomReset'], <String>['Ctrl+0']);
    expect(rows['canvasDelete'], <String>['Delete', 'Backspace']);
  });

  test('行序 = app 两行 + 注册表顺序，按住空格平移紧跟平移工具', () {
    final List<String> order = buildShortcutRows(isMac: true)
        .map((ShortcutRow r) => r.id)
        .toList();
    expect(order, _expectedOrder);
  });

  test('listed: false 的绑定不上屏', () {
    final List<CanvasKeyBinding> registry = <CanvasKeyBinding>[
      CanvasKeyBinding(
        id: 'canvasSyntheticListed',
        activators: const <ShortcutActivator>[
          SingleActivator(LogicalKeyboardKey.keyV, includeRepeats: false),
        ],
        intent: const CanvasSelectToolIntent(),
        gate: CanvasKeyGate.notEditingText,
        group: ShortcutGroup.tools,
        label: (l) => l.settingsShortcutCanvasSelectTool,
        onInvoke: (_, _) {},
      ),
      CanvasKeyBinding(
        id: 'canvasSyntheticUnlisted',
        activators: const <ShortcutActivator>[
          SingleActivator(LogicalKeyboardKey.keyL, includeRepeats: false),
        ],
        intent: const CanvasToggleLinkIntent(),
        gate: CanvasKeyGate.notEditingText,
        group: ShortcutGroup.tools,
        label: (l) => l.settingsShortcutCanvasToggleLink,
        onInvoke: (_, _) {},
        listed: false,
      ),
    ];
    for (final bool isMac in <bool>[true, false]) {
      final List<String> ids = buildShortcutRows(isMac: isMac, registry: registry)
          .map((ShortcutRow r) => r.id)
          .toList();
      expect(ids, contains('canvasSyntheticListed'), reason: '前提：合成表本身上得了屏');
      expect(ids, isNot(contains('canvasSyntheticUnlisted')));
    }
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
