// 新建菜单本体（create_node_menu.dart 的 InkMenuPanel）：搜索框一打开就持焦、打字按文字过滤
// （不区分大小写的包含匹配）、一项都没匹配上出一行说明；↑ / ↓ 移动高亮（首尾相接、跨分组）、↵ 执行高亮项、
// Esc 关；鼠标悬停也移动高亮；点一行 = 执行它。没有搜索框的空白处右键菜单焦点落在菜单本身，键盘一样能用，
// 菜单开着时别的键不往外漏。
//
// 拿掉 ↑ / ↓ / ↵ / Esc 任何一个分支，对应用例当场红；拿掉过滤，「打字过滤」与「空匹配」红。
//
// PR-8b（节点右键菜单）给菜单本体加的：置灰（不隐藏，↑ / ↓ 跳过、点了不执行、降 0.5）、危险色、打勾（不降色）、
// 子菜单（悬停 / 点击 / → 打开，键盘打开时高亮落在第一个能点的项；子菜单开着时 ↑ / ↓ / ↵ 归它，← / Esc 只收回
// 子菜单；悬停到主菜单别的行收回；右边放不下翻到左边）。拿掉「跳过置灰」⇒ 两条键盘用例红；拿掉子菜单的
// ← / Esc 分支 ⇒「只收回子菜单」红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/test_app.dart';

const List<List<InkMenuEntry<String>>> _groups = <List<InkMenuEntry<String>>>[
  <InkMenuEntry<String>>[
    InkMenuEntry<String>(value: 'a', label: 'Alpha'),
    InkMenuEntry<String>(value: 'b', label: 'Beta', keyHint: 'B'),
  ],
  <InkMenuEntry<String>>[
    InkMenuEntry<String>(value: 'c', label: 'Gamma'),
  ],
];

/// 置灰 / 危险 / 打勾 / 子菜单（节点右键菜单那一套）的夹具：第一项置灰；第三项带子菜单，子菜单第一项是
/// 打勾的「当前所在」（不可点）；最后一组是危险项。
const List<List<InkMenuEntry<String>>> _richGroups = <List<InkMenuEntry<String>>>[
  <InkMenuEntry<String>>[
    InkMenuEntry<String>(value: 'off', label: 'Off', enabled: false),
    InkMenuEntry<String>(value: 'on', label: 'On'),
    InkMenuEntry<String>(
      value: 'lanes',
      label: 'Lanes',
      submenu: <List<InkMenuEntry<String>>>[
        <InkMenuEntry<String>>[
          InkMenuEntry<String>(value: 'here', label: 'Here', checked: true, enabled: false),
          InkMenuEntry<String>(value: 'there', label: 'There'),
        ],
        <InkMenuEntry<String>>[
          InkMenuEntry<String>(value: 'none', label: 'None'),
        ],
      ],
    ),
  ],
  <InkMenuEntry<String>>[
    InkMenuEntry<String>(value: 'kill', label: 'Kill', danger: true),
  ],
];

/// 记下菜单交回来的东西：选中了哪些项、关了几次、有几个键漏到了菜单外面。
class _Probe {
  final List<String> picked = <String>[];
  int dismissed = 0;
  int leaked = 0;
}

Future<_Probe> _pump(
  WidgetTester tester, {
  bool searchable = true,
  List<List<InkMenuEntry<String>>> groups = _groups,
  Alignment alignment = Alignment.topLeft,
}) async {
  final _Probe probe = _Probe();
  await pumpInkApp(
    tester,
    Scaffold(
      // 菜单外面一层快捷键：右键菜单开着时「I」不该漏到这里（画布的单键快捷键就在菜单外面）。
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyI): () => probe.leaked++,
        },
        child: Align(
          alignment: alignment,
          child: InkMenuPanel<String>(
            width: InkMenuPanel.createWidth,
            groups: groups,
            onSelected: probe.picked.add,
            onDismiss: () => probe.dismissed++,
            emptyText: 'Nothing here',
            searchHint: searchable ? 'Search' : null,
          ),
        ),
      ),
    ),
  );
  // 菜单挂上之后帧后才要焦点。
  await tester.pumpAndSettle();
  return probe;
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  testWidgets('搜索框一打开就持焦：直接打字就是在搜', (tester) async {
    await _pump(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(isEditingText(), isTrue, reason: '主焦点应在搜索框里');
    expect(find.text('Search'), findsOneWidget, reason: '占位文字');
  });

  testWidgets('↵ 执行高亮项：一打开高亮在第一项', (tester) async {
    final _Probe probe = await _pump(tester);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(probe.picked, <String>['a']);
  });

  testWidgets('↓ 往下移（跨分组），↵ 执行移到的那一项', (tester) async {
    final _Probe probe = await _pump(tester);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(probe.picked, <String>['c']);
  });

  testWidgets('↑ 从第一项往上首尾相接到最后一项', (tester) async {
    final _Probe probe = await _pump(tester);
    await _key(tester, LogicalKeyboardKey.arrowUp);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(probe.picked, <String>['c']);
  });

  testWidgets('Esc 关菜单，不执行任何项', (tester) async {
    final _Probe probe = await _pump(tester);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(probe.dismissed, 1);
    expect(probe.picked, isEmpty);
  });

  testWidgets('打字过滤：不区分大小写的包含匹配，整组没匹配上的连分隔线一起不出', (tester) async {
    final _Probe probe = await _pump(tester);
    await tester.enterText(find.byKey(CanvasMenuKeys.search), 'GAM');
    await tester.pump();
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsNothing);
    // 过滤之后高亮回到第一个看得见的项。
    await _key(tester, LogicalKeyboardKey.enter);
    expect(probe.picked, <String>['c']);
  });

  testWidgets('一项都没匹配上：出一行说明，↵ 什么都不做', (tester) async {
    final _Probe probe = await _pump(tester);
    await tester.enterText(find.byKey(CanvasMenuKeys.search), 'zzz');
    await tester.pump();
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(probe.picked, isEmpty);
  });

  testWidgets('鼠标悬停把高亮挪到那一行，↵ 执行它', (tester) async {
    final _Probe probe = await _pump(tester);
    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 550));
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.text('Beta')));
    await tester.pump();
    await _key(tester, LogicalKeyboardKey.enter);
    expect(probe.picked, <String>['b']);
  });

  testWidgets('点一行 = 执行那一行', (tester) async {
    final _Probe probe = await _pump(tester);
    await tester.tap(find.text('Gamma'));
    await tester.pump();
    expect(probe.picked, <String>['c']);
  });

  testWidgets('键位提示画在行尾', (tester) async {
    await _pump(tester);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('没有搜索框（空白处右键菜单）：焦点落在菜单本身，↓ ↵ 照样能用；别的键不往外漏', (tester) async {
    final _Probe probe = await _pump(tester, searchable: false);
    expect(find.byType(TextField), findsNothing);

    await _key(tester, LogicalKeyboardKey.keyI);
    expect(probe.leaked, 0, reason: '菜单开着时按 I 不该落到菜单外面的快捷键上');

    await _key(tester, LogicalKeyboardKey.arrowDown);
    await _key(tester, LogicalKeyboardKey.enter);
    expect(probe.picked, <String>['b']);
  });

  group('置灰 / 危险色 / 打勾 / 子菜单（PR-8b）', () {
    Future<_Probe> pumpRich(WidgetTester tester, {Alignment alignment = Alignment.topLeft}) =>
        _pump(tester, searchable: false, groups: _richGroups, alignment: alignment);

    Finder submenu() => find.byKey(CanvasMenuKeys.submenu);

    double opacityOf(WidgetTester tester, String label) => tester
        .widget<Opacity>(find.ancestor(of: find.text(label), matching: find.byType(Opacity)).first)
        .opacity;

    testWidgets('置灰的项：一打开高亮就跳过它，↵ 执行第一个能点的', (tester) async {
      final _Probe probe = await pumpRich(tester);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(probe.picked, <String>['on']);
    });

    testWidgets('↑ / ↓ 跳过置灰的项：从第一个能点的往上，越过置灰的那一项首尾相接到最后', (tester) async {
      final _Probe probe = await pumpRich(tester);
      await _key(tester, LogicalKeyboardKey.arrowUp);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(probe.picked, <String>['kill']);
    });

    testWidgets('点置灰的项：不执行；置灰的行降 0.5，危险项用 danger 色', (tester) async {
      final _Probe probe = await pumpRich(tester);
      await tester.tap(find.text('Off'));
      await tester.pump();
      expect(probe.picked, isEmpty);

      expect(opacityOf(tester, 'Off'), 0.5);
      expect(opacityOf(tester, 'On'), 1.0);
      final InkColors colors =
          tester.element(find.byType(InkMenuPanel<String>)).inkColors;
      expect(tester.widget<Text>(find.text('Kill')).style?.color, colors.danger);
      expect(tester.widget<Text>(find.text('On')).style?.color, colors.fg2);
    });

    testWidgets('带子菜单的行画 ›；→ 打开子菜单，高亮落在第一个能点的项（跳过打勾的当前项），↵ 执行它', (tester) async {
      final _Probe probe = await pumpRich(tester);
      expect(find.text('›'), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowDown); // On → Lanes
      expect(submenu(), findsNothing);

      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(submenu(), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.enter);

      expect(probe.picked, <String>['there']);
    });

    testWidgets('子菜单开着：↓ 在子菜单里跨分组移动，↵ 执行子菜单的项（不是主菜单的）', (tester) async {
      final _Probe probe = await pumpRich(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      await _key(tester, LogicalKeyboardKey.arrowDown); // There → None
      await _key(tester, LogicalKeyboardKey.enter);

      expect(probe.picked, <String>['none']);
    });

    testWidgets('↵ 在带子菜单的行上：打开子菜单，不交回这一行', (tester) async {
      final _Probe probe = await pumpRich(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submenu(), findsOneWidget);
      expect(probe.picked, isEmpty);
    });

    testWidgets('子菜单里 Esc / ←：只收回子菜单、菜单还开着；再按 Esc 才关菜单', (tester) async {
      final _Probe probe = await pumpRich(tester);
      await _key(tester, LogicalKeyboardKey.arrowDown);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(submenu(), findsNothing);
      expect(probe.dismissed, 0);

      await _key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(submenu(), findsNothing);
      expect(probe.dismissed, 0);

      await _key(tester, LogicalKeyboardKey.escape);
      expect(probe.dismissed, 1);
    });

    testWidgets('打勾的行：行尾一个勾，不降色（它是「现在就在这儿」，只是点不动）', (tester) async {
      await pumpRich(tester);
      await tester.tap(find.text('Lanes'));
      await tester.pumpAndSettle();

      final Finder here = find.ancestor(of: find.text('Here'), matching: find.byType(Row)).first;
      expect(
        find.descendant(
          of: here,
          matching: find.byWidgetPredicate((Widget w) => w is InkIcon && w.glyph == InkGlyph.success),
        ),
        findsOneWidget,
      );
      expect(opacityOf(tester, 'Here'), 1.0);
    });

    testWidgets('鼠标悬停带子菜单的行就打开子菜单，点子菜单里的项执行它；点子菜单里打勾的当前项不执行', (tester) async {
      final _Probe probe = await pumpRich(tester);
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 550));
      addTearDown(mouse.removePointer);
      await tester.pump();

      await mouse.moveTo(tester.getCenter(find.text('Lanes')));
      await tester.pumpAndSettle();
      expect(submenu(), findsOneWidget);

      await tester.tap(find.text('Here'));
      await tester.pump();
      expect(probe.picked, isEmpty);

      await tester.tap(find.text('There'));
      await tester.pump();
      expect(probe.picked, <String>['there']);
    });

    testWidgets('悬停到主菜单别的行：开着的子菜单收起', (tester) async {
      await pumpRich(tester);
      final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 550));
      addTearDown(mouse.removePointer);
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Lanes')));
      await tester.pumpAndSettle();
      expect(submenu(), findsOneWidget);

      await mouse.moveTo(tester.getCenter(find.text('On')));
      await tester.pumpAndSettle();

      expect(submenu(), findsNothing);
    });

    testWidgets('子菜单贴着父行：右边放得下就在右边、第一行与父行对齐', (tester) async {
      await pumpRich(tester);
      await tester.tap(find.text('Lanes'));
      await tester.pumpAndSettle();

      final Rect panel = tester.getRect(find.byType(InkMenuPanel<String>));
      final Rect sub = tester.getRect(submenu());
      expect(sub.left, closeTo(panel.right, 0.5));
      expect(
        tester.getCenter(find.text('There')).dy - tester.getCenter(find.text('Here')).dy,
        closeTo(InkMenuPanel.rowHeight, 0.5),
      );
      expect(tester.getCenter(find.text('Here')).dy, closeTo(tester.getCenter(find.text('Lanes')).dy, 0.5),
          reason: '子菜单第一行与父行同高');
    });

    testWidgets('右边放不下：子菜单翻到左边', (tester) async {
      await pumpRich(tester, alignment: Alignment.topRight);
      await tester.tap(find.text('Lanes'));
      await tester.pumpAndSettle();

      final Rect panel = tester.getRect(find.byType(InkMenuPanel<String>));
      final Rect sub = tester.getRect(submenu());
      expect(sub.right, closeTo(panel.left, 0.5));
    });
  });
}
