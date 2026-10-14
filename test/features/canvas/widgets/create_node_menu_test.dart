// 新建菜单本体（create_node_menu.dart 的 CanvasMenuPanel）：搜索框一打开就持焦、打字按文字过滤
// （不区分大小写的包含匹配）、一项都没匹配上出一行说明；↑ / ↓ 移动高亮（首尾相接、跨分组）、↵ 执行高亮项、
// Esc 关；鼠标悬停也移动高亮；点一行 = 执行它。没有搜索框的空白处右键菜单焦点落在菜单本身，键盘一样能用，
// 菜单开着时别的键不往外漏。
//
// 拿掉 ↑ / ↓ / ↵ / Esc 任何一个分支，对应用例当场红；拿掉过滤，「打字过滤」与「空匹配」红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';

import '../../../_harness/test_app.dart';

const List<List<CanvasMenuEntry<String>>> _groups = <List<CanvasMenuEntry<String>>>[
  <CanvasMenuEntry<String>>[
    CanvasMenuEntry<String>(value: 'a', label: 'Alpha'),
    CanvasMenuEntry<String>(value: 'b', label: 'Beta', keyHint: 'B'),
  ],
  <CanvasMenuEntry<String>>[
    CanvasMenuEntry<String>(value: 'c', label: 'Gamma'),
  ],
];

/// 记下菜单交回来的东西：选中了哪些项、关了几次、有几个键漏到了菜单外面。
class _Probe {
  final List<String> picked = <String>[];
  int dismissed = 0;
  int leaked = 0;
}

Future<_Probe> _pump(WidgetTester tester, {bool searchable = true}) async {
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
          alignment: Alignment.topLeft,
          child: CanvasMenuPanel<String>(
            width: CanvasMenuPanel.createWidth,
            groups: _groups,
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
}
