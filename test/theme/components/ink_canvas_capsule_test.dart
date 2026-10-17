// InkCanvasCapsule：画布轻提示胶囊的纯呈现件（文案全部由调用方给——theme 层不碰 ARB）。
//
// 钉：高 28、全圆角、surface4 底、overlayBorder 描边；带动作时文字 + 动作 + 键位，点动作回调一次；
// 动作不进焦点遍历（ExcludeFocus）；整枚胶囊是读屏 liveRegion；超长文字单行省略号、不溢出。
//
// 变异对照：去掉 ExcludeFocus ⇒「动作不进焦点遍历」红；去掉 liveRegion ⇒「liveRegion」红。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/theme/app_theme.dart';
import 'package:inkframe/theme/components/ink_canvas_capsule.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../_harness/test_app.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    pumpInkApp(tester, Scaffold(body: Center(child: child)));

/// 胶囊里动作按钮的焦点节点（InkActivatable 内的 FocusableActionDetector 持有）。
FocusNode _actionFocus(WidgetTester tester) => tester
    .widget<FocusableActionDetector>(
      find.descendant(
        of: find.byType(InkCanvasCapsule),
        matching: find.byType(FocusableActionDetector),
      ),
    )
    .focusNode!;

void main() {
  testWidgets('高 28、全圆角、surface4 底、overlayBorder 描边', (tester) async {
    await _pump(tester, const InkCanvasCapsule(text: 'Zoom 80%'));

    expect(tester.getSize(find.byType(InkCanvasCapsule)).height, InkCanvasCapsuleSize.height);
    expect(InkCanvasCapsuleSize.height, 28);

    final InkColors c = tester.element(find.byType(InkCanvasCapsule)).inkColors;
    final DecoratedBox box =
        tester.widget<DecoratedBox>(find.byKey(InkCanvasCapsule.surfaceKey));
    final BoxDecoration d = box.decoration as BoxDecoration;
    expect(d.color, c.surface4);
    expect(d.border, Border.all(color: c.overlayBorder));
    expect(d.borderRadius, BorderRadius.circular(InkRadius.pill));
    expect(find.text('Zoom 80%'), findsOneWidget);
  });

  testWidgets('带动作：文字 + 动作 + 键位；点动作回调一次', (tester) async {
    int taps = 0;
    await _pump(
      tester,
      InkCanvasCapsule(
        text: 'Undone · Move 3 nodes',
        actionLabel: 'Redo',
        actionHint: 'Ctrl Y',
        onAction: () => taps++,
      ),
    );

    expect(find.text('Undone · Move 3 nodes'), findsOneWidget);
    expect(find.text('Redo'), findsOneWidget);
    expect(find.text('Ctrl Y'), findsOneWidget);

    await tester.tap(find.text('Redo'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('没给回调就不画动作', (tester) async {
    await _pump(tester, const InkCanvasCapsule(text: 'Done', actionLabel: 'Redo'));
    expect(find.text('Redo'), findsNothing);
  });

  testWidgets('动作不进焦点遍历：前后各一个可聚焦件，Tab 只在它们之间走', (tester) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextButton(onPressed: () {}, child: const Text('Before')),
          InkCanvasCapsule(text: 'Undone', actionLabel: 'Redo', onAction: () {}),
          TextButton(onPressed: () {}, child: const Text('After')),
        ],
      ),
    );
    final FocusNode action = _actionFocus(tester);

    for (int i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(action.hasFocus, isFalse, reason: '第 ${i + 1} 次 Tab 不该落到胶囊的动作上');
      final BuildContext? focused = primaryFocus?.context;
      if (focused != null) {
        expect(
          find.descendant(of: find.byType(InkCanvasCapsule), matching: find.byWidget(focused.widget)),
          findsNothing,
          reason: '焦点不在胶囊子树里',
        );
      }
    }
  });

  testWidgets('liveRegion：整枚胶囊是一个读屏 liveRegion 容器', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, const InkCanvasCapsule(text: 'Zoom 80%'));

    expect(
      tester.getSemantics(find.byType(InkCanvasCapsule)),
      isSemantics(isLiveRegion: true, label: 'Zoom 80%'),
    );
    handle.dispose();
  });

  testWidgets('超长文字：单行省略号，不溢出', (tester) async {
    const String long = 'Connected after shot 7 · a very long description that cannot fit';
    await _pump(
      tester,
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: const InkCanvasCapsule(text: long),
      ),
    );

    expect(tester.takeException(), isNull);
    final Text text = tester.widget<Text>(find.text(long));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
    expect(tester.getSize(find.byType(InkCanvasCapsule)).width, lessThanOrEqualTo(120));
  });

  testWidgets('超长文字 + 动作：省略的是文字，动作与键位完整', (tester) async {
    const String long = 'Undone · Move 3 nodes and a very long tail that cannot fit';
    await _pump(
      tester,
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: InkCanvasCapsule(
          text: long,
          actionLabel: 'Redo',
          actionHint: 'Ctrl Y',
          onAction: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text(long)).overflow, TextOverflow.ellipsis);
    final Rect capsule = tester.getRect(find.byType(InkCanvasCapsule));
    expect(tester.getRect(find.text('Ctrl Y')).right, lessThanOrEqualTo(capsule.right));
  });
}
