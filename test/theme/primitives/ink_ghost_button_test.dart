import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_ghost_button.dart';
import 'package:inkframe/theme/tokens.dart';

Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
    home: Scaffold(body: body),
  ));
  await tester.pump();
}

FocusNode _focusOf(WidgetTester tester, Key key) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

/// 焦点环 = 前景装饰。按钮自己的 AnimatedContainer 也会生成一个背景位的
/// DecoratedBox，所以这里必须按 position 筛，不能只按类型找。
Finder _ring(Key key) => find.descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox && w.position == DecorationPosition.foreground,
      ),
    );

Future<void> _tabKey(WidgetTester tester, int times) async {
  for (int i = 0; i < times; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
}

void main() {
  testWidgets('InkGhostButton has no background by default', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
      home: Scaffold(
        body: InkGhostButton(label: 'Library', onPressed: () {}),
      ),
    ));
    expect(find.text('Library'), findsOneWidget);
  });

  // BOARD 210：#249 只把标签 chip 改成了可键盘到达，这件（仓库里 11 处消费点）
  // 还是裸 GestureDetector。抽出 InkActivatable 后一起换过来，下面钉死它。
  group('键盘可达（与标签 chip 共用 InkActivatable）', () {
    const Key k = Key('ghost');

    testWidgets('可 Tab 聚焦，Enter 激活 onPressed', (tester) async {
      int presses = 0;
      await _pump(
        tester,
        InkGhostButton(key: k, label: 'Library', onPressed: () => presses += 1),
      );

      await _tabKey(tester, 1);
      expect(
        _focusOf(tester, k).hasPrimaryFocus,
        isTrue,
        reason: '不可聚焦 ⇒ 键盘用户到不了这个按钮',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 1, reason: 'Enter 必须等价于一次点击');
    });

    testWidgets('onPressed == null ⇒ 不可聚焦（不是空闭包，是 null）', (tester) async {
      await _pump(
        tester,
        const Column(children: <Widget>[
          InkGhostButton(key: k, label: 'Disabled', onPressed: null),
          InkGhostButton(
            key: Key('next'),
            label: 'Enabled',
            onPressed: _noop,
          ),
        ]),
      );

      await _tabKey(tester, 1);
      expect(_focusOf(tester, k).hasPrimaryFocus, isFalse);
      expect(_focusOf(tester, const Key('next')).hasPrimaryFocus, isTrue);
    });

    testWidgets('聚焦时画 accent 焦点环，圆角跟按钮一致，且不改按钮尺寸',
        (tester) async {
      await _pump(
        tester,
        InkGhostButton(key: k, label: 'Library', onPressed: () {}),
      );
      final InkColors colors = tester.element(find.byKey(k)).inkColors;
      final Size before = tester.getSize(find.byKey(k));

      expect(_ring(k), findsNothing, reason: '没焦点时不该有环');

      await _tabKey(tester, 1);
      final BoxDecoration ring =
          tester.widget<DecoratedBox>(_ring(k)).decoration as BoxDecoration;
      expect(ring.border!.top.color, colors.accent);
      expect(ring.borderRadius, BorderRadius.circular(InkRadius.sm));
      expect(
        tester.getSize(find.byKey(k)),
        before,
        reason: '前景装饰不参与布局 ⇒ 加环不许撑大按钮',
      );
    });
  });
}

void _noop() {}
