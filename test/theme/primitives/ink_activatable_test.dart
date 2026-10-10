// InkActivatable（可达性的唯一点击壳）：指针与键盘走同一条回调。
//
// 这几条性质原本只长在 `ink_shell_tab_bar` 的 chip 上（#249）。抽成共用件之后，
// 契约必须钉在包装件【自己】这一层——否则三个消费点各自测一遍「我这儿能回车」，
// 而包装件本身的性质（激活键不吃宿主默认表 / 禁用不可聚焦 / 环走 token /
// 环不改尺寸）没人看守，下一次改动就会静默走形。
//
// 消费点侧的用例各自在：test/theme/ink_shell_tab_bar_test.dart（chip）、
// test/theme/primitives/ink_ghost_button_test.dart、
// test/features/shell/shell_tab_bar_actions_a11y_test.dart（标签栏右侧动作）。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/primitives/ink_activatable.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

const Key _a = Key('probe-a');
const Key _b = Key('probe-b');

/// 一个最小探针：盒子尺寸写死，这样"焦点环不改尺寸"才量得出来。
Widget _probe(
  Key key, {
  required VoidCallback? onTap,
  String? label,
  bool paintFocusRing = true,
}) =>
    InkActivatable(
      key: key,
      onTap: onTap,
      semanticLabel: label,
      paintFocusRing: paintFocusRing,
      builder: (BuildContext context, bool hovered, bool focused) => SizedBox(
        width: 120,
        height: 30,
        child: Text(hovered ? 'hovered' : 'idle'),
      ),
    );

FocusNode _focusOf(WidgetTester tester, Key key) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

/// 包装件自己那层 MouseRegion（最外一层；FocusableActionDetector 内部还有一层，
/// 它的 cursor 是 defer，所以外层说什么就是什么）。
MouseRegion _outerRegion(WidgetTester tester, Key key) => tester.widget<MouseRegion>(
      find
          .descendant(of: find.byKey(key), matching: find.byType(MouseRegion))
          .first,
    );

Future<void> _tabKey(WidgetTester tester, int times) async {
  for (int i = 0; i < times; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await pumpInkApp(
    tester,
    Scaffold(body: Column(children: <Widget>[child])),
    surfaceSize: const Size(600, 300),
  );
  await tester.pump();
}

void main() {
  group('InkActivatable', () {
    testWidgets('可 Tab 聚焦：第一次 Tab 就落在它上面', (tester) async {
      await _pump(tester, _probe(_a, onTap: () {}));

      expect(_focusOf(tester, _a).hasPrimaryFocus, isFalse);
      await _tabKey(tester, 1);
      expect(
        _focusOf(tester, _a).hasPrimaryFocus,
        isTrue,
        reason: '不可聚焦 ⇒ 键盘用户根本到不了这个控件',
      );
    });

    testWidgets('Enter / NumpadEnter / Space 三键都激活，且与指针同一条回调',
        (tester) async {
      int taps = 0;
      await _pump(tester, _probe(_a, onTap: () => taps += 1));
      await _tabKey(tester, 1);

      for (final LogicalKeyboardKey k in <LogicalKeyboardKey>[
        LogicalKeyboardKey.enter,
        LogicalKeyboardKey.numpadEnter,
        LogicalKeyboardKey.space,
      ]) {
        await tester.sendKeyEvent(k);
        await tester.pump();
      }
      expect(taps, 3, reason: '三个激活键必须各算一次');

      // 同一个计数器被指针也加上去 ⇒ 键盘与指针不可能走岔（性质 3）。
      await tester.tap(find.byKey(_a));
      await tester.pump();
      expect(taps, 4);
    });

    testWidgets('激活键不依赖宿主的默认 shortcuts 表：裸宿主（无 MaterialApp）下回车照样激活',
        (tester) async {
      int taps = 0;
      // WidgetsApp 的默认表也把 Enter 映射成 ActivateIntent，所以在 MaterialApp
      // 下测不出"自己带表"这件事。这里刻意不给宿主。
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: _probe(_a, onTap: () => taps += 1)),
      ));
      await tester.pump();

      _focusOf(tester, _a).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(
        taps,
        1,
        reason: 'theme 层是可复用组件，不该假设宿主一定是 MaterialApp；'
            '激活键要显式写在自己的 shortcuts 里',
      );
    });

    testWidgets('onTap == null ⇒ 不可聚焦：Tab 直接跳到下一个', (tester) async {
      await _pump(
        tester,
        Column(children: <Widget>[
          _probe(_a, onTap: null),
          _probe(_b, onTap: () {}),
        ]),
      );

      await _tabKey(tester, 1);
      expect(
        _focusOf(tester, _a).hasPrimaryFocus,
        isFalse,
        reason: '此刻不可点的控件不该能被聚焦——聚焦上去按回车什么都不会发生',
      );
      expect(_focusOf(tester, _b).hasPrimaryFocus, isTrue);
    });

    testWidgets('焦点环走 accent token，失焦不画，且不改控件尺寸', (tester) async {
      await _pump(tester, _probe(_a, onTap: () {}));
      final InkColors colors = tester.element(find.byKey(_a)).inkColors;
      final Size before = tester.getSize(find.byKey(_a));

      expect(
        find.descendant(of: find.byKey(_a), matching: find.byType(DecoratedBox)),
        findsNothing,
        reason: '没焦点时不该有环',
      );

      await _tabKey(tester, 1);
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(_a),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        box.position,
        DecorationPosition.foreground,
        reason: '环走前景装饰，才不会参与布局（性质 5）',
      );
      expect(
        (box.decoration as BoxDecoration).border!.top.color,
        colors.accent,
        reason: '焦点指示不许硬编码颜色（docs/CLAUDE.md 零硬编码视觉值）',
      );
      expect(
        tester.getSize(find.byKey(_a)),
        before,
        reason: '加环把控件撑宽了 ⇒ 既有宽度阈值实测会静默失准',
      );
    });

    testWidgets('paintFocusRing: false ⇒ 环交给 builder 自己画（chip 走这条）',
        (tester) async {
      await _pump(tester, _probe(_a, onTap: () {}, paintFocusRing: false));
      await _tabKey(tester, 1);

      expect(_focusOf(tester, _a).hasPrimaryFocus, isTrue);
      expect(
        find.descendant(of: find.byKey(_a), matching: find.byType(DecoratedBox)),
        findsNothing,
        reason: '关掉之后包装件自己不画环（chip 要把环贴在它已有的盒上）',
      );
    });

    testWidgets('hover 透出给 builder；光标按 enabled 切', (tester) async {
      await _pump(
        tester,
        Column(children: <Widget>[
          _probe(_a, onTap: () {}),
          _probe(_b, onTap: null),
        ]),
      );

      expect(_outerRegion(tester, _a).cursor, SystemMouseCursors.click);
      expect(
        _outerRegion(tester, _b).cursor,
        SystemMouseCursors.basic,
        reason: '不可点的控件不该给"可点"光标',
      );

      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byKey(_a)));
      await tester.pump();

      expect(
        find.text('hovered'),
        findsOneWidget,
        reason: 'hover 要透出给 builder——各家的 hover 态视觉靠它',
      );
    });

    testWidgets('Semantics：label 透出，禁用态标 disabled', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        Column(children: <Widget>[
          _probe(_a, onTap: () {}, label: 'Alpha'),
          _probe(_b, onTap: null, label: 'Beta'),
        ]),
      );

      // 正则匹配：label 会与 builder 里的文字合并成一个节点，不是精确等于。
      expect(find.bySemanticsLabel(RegExp('Alpha')), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(_b))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'onTap == null 的控件不该对外宣称可点',
      );
      handle.dispose();
    });
  });
}
