// InkShellTabBar（纯呈现层）：窄屏退化 + Key 原样透传 + 键盘可达性。
//
// 本文件**刻意不 import 任何 features/**——它测的是"给一串纯数据，画成什么样"。
// 接线（谁是当前标签、点了去哪、真实 en/zh 文案下的阈值实测）在
// test/features/shell/shell_tab_bar_test.dart。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_shell_tab_bar.dart';
import 'package:inkframe/theme/tokens.dart';

import '../_harness/test_app.dart';

const List<String> _names = <String>['alpha', 'beta', 'gamma'];

List<InkShellTabBarItem> _items({
  String selected = 'alpha',
  VoidCallback? onTap,
  Set<String> disabled = const <String>{},
}) =>
    <InkShellTabBarItem>[
      for (final String n in _names)
        InkShellTabBarItem(
          key: ValueKey<String>('shellTab-$n'),
          label: n,
          icon: Icons.home_outlined,
          selected: n == selected,
          // 禁用态给 null 而不是空闭包（lib 侧由 no_dead_interactive_test 钉死）。
          onTap: disabled.contains(n) ? null : (onTap ?? () {}),
        ),
    ];

Finder _chip(String name) => find.byKey(ValueKey<String>('shellTab-$name'));

/// 某一格的焦点节点。由 `_ShellTabState` 自己持有并交给
/// FocusableActionDetector——测试要断言"焦点现在落在哪一格"，拿得到节点才测得了。
FocusNode _chipFocus(WidgetTester tester, String name) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: _chip(name),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

/// 某一格的外框 Container（焦点环画在它的 foregroundDecoration 上：
/// 前景装饰不参与布局，所以加焦点环不会把 chip 撑宽、不动既有视觉）。
Container _chipBox(WidgetTester tester, String name) => tester.widget<Container>(
      find.descendant(of: _chip(name), matching: find.byType(Container)),
    );

Future<void> _pumpBar(
  WidgetTester tester, {
  List<InkShellTabBarItem>? items,
}) async {
  await pumpInkApp(
    tester,
    Scaffold(
      body: Column(children: <Widget>[InkShellTabBar(items: items ?? _items())]),
    ),
    surfaceSize: const Size(1440, 400),
  );
  await tester.pump();
}

/// Tab 键走 [times] 步。标签条里唯一可聚焦的东西就是 chip，
/// 所以第 n 次 Tab 恰好落在第 n 格（声明序 == 渲染序 == 焦点遍历序）。
Future<void> _tabKey(WidgetTester tester, int times) async {
  for (int i = 0; i < times; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
}

void main() {
  testWidgets('宽屏出文字标签，窄屏退化成纯图标；两种形态下 Key 都在', (tester) async {
    await pumpInkApp(
      tester,
      Scaffold(body: Column(children: <Widget>[InkShellTabBar(items: _items())])),
      surfaceSize: const Size(1440, 400),
    );
    await tester.pump();

    expect(find.text('beta'), findsOneWidget);
    expect(tester.getSize(find.byType(InkShellTabBar)).height, InkShellTabBar.height);

    await pumpInkApp(
      tester,
      Scaffold(body: Column(children: <Widget>[InkShellTabBar(items: _items())])),
      surfaceSize: const Size(InkShellTabBar.compactBelow - 1, 400),
    );
    await tester.pump();

    expect(find.text('beta'), findsNothing, reason: '窄屏应收成纯图标');
    // 退化前后 Key 都必须在：调用方给的 Key 原样落到 chip 上，是跨层契约
    // （外壳测试的 tapShellTab() 靠它命中）。
    for (final String n in _names) {
      expect(_chip(n), findsOneWidget);
    }
  });

  testWidgets('点 chip → 调用方给的 onTap 被触发（一帧落地）', (tester) async {
    int taps = 0;
    await _pumpBar(tester, items: _items(onTap: () => taps += 1));

    await tester.tap(_chip('gamma'));
    await tester.pump();
    expect(taps, 1);
  });

  // 旧债（BOARD，shell-tab-navigation R85–R90 轮）：chip 原本是
  // GestureDetector + Semantics，不可聚焦、不可回车激活——键盘用户到不了
  // 全应用最高频的那条交互。下面四条钉死"可聚焦 / 可键盘激活 / 禁用格跳过 /
  // 焦点指示走 token"。
  group('键盘可达性', () {
    testWidgets('Tab 键把焦点送进标签条：第一次 Tab 落在第一格', (tester) async {
      await _pumpBar(tester);

      expect(_chipFocus(tester, 'alpha').hasPrimaryFocus, isFalse);
      await _tabKey(tester, 1);
      expect(
        _chipFocus(tester, 'alpha').hasPrimaryFocus,
        isTrue,
        reason: 'chip 不可聚焦时，这一步到不了标签栏（键盘用户被挡在门外）',
      );
    });

    testWidgets('聚焦后按 Enter → 调用方的 onTap 被触发', (tester) async {
      int taps = 0;
      await _pumpBar(tester, items: _items(onTap: () => taps += 1));

      await _tabKey(tester, 2); // alpha → beta
      expect(_chipFocus(tester, 'beta').hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1, reason: 'Enter 必须等价于一次点击');
    });

    testWidgets('聚焦后按 Space → 同样激活', (tester) async {
      int taps = 0;
      await _pumpBar(tester, items: _items(onTap: () => taps += 1));

      await _tabKey(tester, 3); // alpha → beta → gamma
      expect(_chipFocus(tester, 'gamma').hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 1, reason: 'Space 是按钮类控件的第二个激活键，不能只认 Enter');
    });

    testWidgets('onTap == null 的格不可聚焦：Tab 直接跳到下一格', (tester) async {
      await _pumpBar(tester, items: _items(disabled: <String>{'beta'}));

      await _tabKey(tester, 2);
      expect(_chipFocus(tester, 'beta').hasPrimaryFocus, isFalse,
          reason: '此刻不可点的格不该能被聚焦——聚焦上去按 Enter 什么都不会发生');
      expect(_chipFocus(tester, 'gamma').hasPrimaryFocus, isTrue);
    });

    testWidgets('焦点环走 token（accent），失焦时不画', (tester) async {
      await _pumpBar(tester);
      final InkColors colors =
          tester.element(find.byType(InkShellTabBar)).inkColors;

      expect(_chipBox(tester, 'alpha').foregroundDecoration, isNull,
          reason: '没焦点时不该有环');

      await _tabKey(tester, 1);
      final BoxDecoration ring =
          _chipBox(tester, 'alpha').foregroundDecoration! as BoxDecoration;
      expect(
        ring.border!.top.color,
        colors.accent,
        reason: '焦点指示不许硬编码颜色（docs/CLAUDE.md 零硬编码视觉值）',
      );
    });
  });
}
