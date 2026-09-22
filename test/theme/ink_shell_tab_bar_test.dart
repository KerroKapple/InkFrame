// InkShellTabBar（纯呈现层）：窄屏退化 + Key 原样透传。
//
// 本文件**刻意不 import 任何 features/**——它测的是"给一串纯数据，画成什么样"。
// 接线（谁是当前标签、点了去哪、真实 en/zh 文案下的阈值实测）在
// test/features/shell/shell_tab_bar_test.dart。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/components/ink_shell_tab_bar.dart';

import '../_harness/test_app.dart';

const List<String> _names = <String>['alpha', 'beta', 'gamma'];

List<InkShellTabBarItem> _items({String selected = 'alpha', VoidCallback? onTap}) =>
    <InkShellTabBarItem>[
      for (final String n in _names)
        InkShellTabBarItem(
          key: ValueKey<String>('shellTab-$n'),
          label: n,
          icon: Icons.home_outlined,
          selected: n == selected,
          onTap: onTap ?? () {},
        ),
    ];

Finder _chip(String name) => find.byKey(ValueKey<String>('shellTab-$name'));

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
    await pumpInkApp(
      tester,
      Scaffold(
        body: Column(
          children: <Widget>[
            InkShellTabBar(items: _items(onTap: () => taps += 1)),
          ],
        ),
      ),
      surfaceSize: const Size(1440, 400),
    );
    await tester.pump();

    await tester.tap(_chip('gamma'));
    await tester.pump();
    expect(taps, 1);
  });
}
