// 舞台外的菜单弹层（canvas_menu/canvas_menu_popover.dart 的 CanvasMenuPopover）：anchor 为 null 不出面板，给一个
// 全局点就开在那一点（左上角对准），右 / 下放不下往回收进 Overlay；点外面 / 面板失焦 / Esc ⇒ onDismiss，点一行 ⇒
// onSelected；子菜单里点击不算点外面（与宿主共用 InkMenuPanel.tapRegionGroup）。
//
// 拿掉 TapRegion 的 onTapOutside ⇒「点外面 ⇒ onDismiss 调一次」红；拿掉 CanvasMenuAnchorLayout 的回收 ⇒
// 「右边 / 下边放不下」红；_onFocusChange 里删掉 widget.onDismiss() ⇒「面板失焦」红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/widgets/create_node_menu.dart';

import '../../../../_harness/test_app.dart';

const Key _panelKey = ValueKey<String>('popoverTest.panel');

const List<List<InkMenuEntry<String>>> _groups = <List<InkMenuEntry<String>>>[
  <InkMenuEntry<String>>[
    InkMenuEntry<String>(value: 'a', label: 'Alpha'),
    InkMenuEntry<String>(value: 'b', label: 'Beta'),
  ],
  <InkMenuEntry<String>>[
    InkMenuEntry<String>(
      value: 'lanes',
      label: 'Lanes',
      submenu: <List<InkMenuEntry<String>>>[
        <InkMenuEntry<String>>[
          InkMenuEntry<String>(value: 'there', label: 'There'),
        ],
      ],
    ),
  ],
];

/// 记下弹层交回来的东西。
class _Probe {
  final List<String> picked = <String>[];
  int dismissed = 0;
}

/// 挂一个 CanvasMenuPopover，锚点由 [anchor] 控制（改它的值 = 父层重建传新的 anchor）。[child] 是触发菜单的
/// 那块界面，缺省铺满一块不可聚焦的空白。
Future<_Probe> _pump(
  WidgetTester tester,
  ValueNotifier<Offset?> anchor, {
  Widget child = const SizedBox.expand(),
}) async {
  final _Probe probe = _Probe();
  await pumpInkApp(
    tester,
    Scaffold(
      body: ValueListenableBuilder<Offset?>(
        valueListenable: anchor,
        builder: (BuildContext context, Offset? value, Widget? child) =>
            CanvasMenuPopover<String>(
          anchor: value,
          groups: _groups,
          onSelected: probe.picked.add,
          onDismiss: () => probe.dismissed++,
          emptyText: 'Nothing here',
          panelKey: _panelKey,
          child: child,
        ),
      ),
    ),
  );
  // 面板挂上之后帧后才要焦点。
  await tester.pumpAndSettle();
  return probe;
}

void main() {
  testWidgets('anchor 为 null 时不出面板；给了全局点就开在那一点', (tester) async {
    final ValueNotifier<Offset?> anchor = ValueNotifier<Offset?>(null);
    addTearDown(anchor.dispose);
    await _pump(tester, anchor);
    expect(find.byKey(_panelKey), findsNothing);

    anchor.value = const Offset(120, 80);
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_panelKey)), const Offset(120, 80));

    anchor.value = null;
    await tester.pumpAndSettle();
    expect(find.byKey(_panelKey), findsNothing, reason: 'anchor 变回 null ⇒ 收起');
  });

  testWidgets('右边 / 下边放不下：往回收进 Overlay', (tester) async {
    final ValueNotifier<Offset?> anchor = ValueNotifier<Offset?>(null);
    addTearDown(anchor.dispose);
    await _pump(tester, anchor);
    final Size screen = tester.getSize(find.byType(Overlay).first);

    anchor.value = Offset(screen.width - 4, screen.height - 4);
    await tester.pumpAndSettle();
    final Rect panel = tester.getRect(find.byKey(_panelKey));
    expect(panel.right, lessThanOrEqualTo(screen.width));
    expect(panel.bottom, lessThanOrEqualTo(screen.height));
    expect(panel.left, lessThan(screen.width - 4), reason: '确实往左收了');
    expect(panel.top, lessThan(screen.height - 4), reason: '确实往上收了');
  });

  testWidgets('点外面 ⇒ onDismiss 调一次', (tester) async {
    final ValueNotifier<Offset?> anchor = ValueNotifier<Offset?>(const Offset(300, 200));
    addTearDown(anchor.dispose);
    final _Probe probe = await _pump(tester, anchor);
    expect(find.byKey(_panelKey), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();
    expect(probe.dismissed, 1);
    expect(probe.picked, isEmpty);
  });

  testWidgets('Esc ⇒ onDismiss', (tester) async {
    final ValueNotifier<Offset?> anchor = ValueNotifier<Offset?>(const Offset(300, 200));
    addTearDown(anchor.dispose);
    final _Probe probe = await _pump(tester, anchor);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(probe.dismissed, 1);
  });

  testWidgets('面板失焦（焦点被旁边的输入框拿走）⇒ onDismiss', (tester) async {
    final ValueNotifier<Offset?> anchor = ValueNotifier<Offset?>(const Offset(300, 200));
    addTearDown(anchor.dispose);
    final FocusNode field = FocusNode(debugLabel: 'popoverTest.field');
    addTearDown(field.dispose);
    final _Probe probe = await _pump(
      tester,
      anchor,
      child: Column(
        children: <Widget>[
          const Expanded(child: SizedBox.expand()),
          TextField(focusNode: field),
        ],
      ),
    );
    expect(find.byKey(_panelKey), findsOneWidget);
    expect(field.hasFocus, isFalse, reason: '前提：开着菜单时焦点在面板上');

    // 不点（点会走「点外面」那条路）：直接把焦点交给输入框，只剩「面板失焦」这一条。
    field.requestFocus();
    await tester.pump();
    expect(field.hasFocus, isTrue);
    expect(probe.dismissed, greaterThanOrEqualTo(1));
    expect(probe.picked, isEmpty);
  });

  testWidgets('点一行 ⇒ onSelected 收到它的 value', (tester) async {
    final ValueNotifier<Offset?> anchor = ValueNotifier<Offset?>(const Offset(300, 200));
    addTearDown(anchor.dispose);
    final _Probe probe = await _pump(tester, anchor);

    await tester.tap(find.text('Beta'));
    await tester.pump();
    expect(probe.picked, <String>['b']);
  });

  testWidgets('子菜单里点击不算点外面', (tester) async {
    final ValueNotifier<Offset?> anchor = ValueNotifier<Offset?>(const Offset(100, 80));
    addTearDown(anchor.dispose);
    final _Probe probe = await _pump(tester, anchor);
    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 550));
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.text('Lanes')));
    await tester.pumpAndSettle();
    expect(find.byKey(InkMenuPanelKeys.submenu), findsOneWidget);

    await tester.tap(find.text('There'));
    await tester.pump();
    expect(probe.picked, <String>['there']);
    expect(probe.dismissed, 0, reason: '子菜单与主菜单同一个点击区组');
  });
}
