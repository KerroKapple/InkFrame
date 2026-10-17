// CanvasCapsuleHost：画布轻提示胶囊在舞台上的宿主——定位、两侧让位、太窄不画、同一张卡不重放淡入、
// 换标签即收、悬停停表、不走通知、不进 Esc 链。
//
// 装置：pumpInkApp 里一块定宽的「舞台」（Stack），宿主挂在里面，与 canvas_screen.dart 一样是 Stack 的直接孩子。
// 胶囊有 120ms 交叉淡入：全文件只 pump 固定时长，不 pumpAndSettle。
//
// 变异对照：
//   - 宿主 bottom 写成 h + InkCanvasCapsuleSize.stageBottom（漏了间隙 8）⇒「条高 60：底边离舞台底 84」红；
//   - 宿主 left / right 写成 0 ⇒「左右各让出 171」红；
//   - 控制器 show 去掉同 dedupeKey 的原地分支（总是换卡）⇒「同 dedupeKey 不重放淡入」红；
//   - visible 变 false 不 dismiss ⇒「visible 变 false 立即收」红；
//   - MouseRegion 不接 setHovered ⇒「悬停停表」红。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_prompt_bar_height.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_capsule_host.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/theme/components/ink_canvas_capsule.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const String _cv = 'c1';
const Key _stageKey = Key('test.stage');
const String _long =
    'Connected after shot 7 · and a very long description that will never fit in the middle of the stage';

/// 舞台宽 [stageWidth]、高 400；[visible] 驱动宿主的可见性；[shortcuts] 时外包 CanvasShortcuts（Esc 用例）。
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double stageWidth = 900,
  ValueNotifier<bool>? visible,
  bool shortcuts = false,
  RecordingToastService? toasts,
}) async {
  final ValueNotifier<bool> vis = visible ?? ValueNotifier<bool>(true);
  Widget body = Center(
    child: SizedBox(
      key: _stageKey,
      width: stageWidth,
      height: 400,
      child: ValueListenableBuilder<bool>(
        valueListenable: vis,
        builder: (BuildContext context, bool v, _) => Stack(
          children: <Widget>[
            const Positioned.fill(child: SizedBox.expand()),
            CanvasCapsuleHost(canvasId: _cv, visible: v),
          ],
        ),
      ),
    ),
  );
  if (shortcuts) body = CanvasShortcuts(isActive: true, child: body);
  await pumpInkApp(
    tester,
    Scaffold(body: body),
    surfaceSize: const Size(1200, 800),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(tab: ShellTab.canvas, canvasId: _cv)),
      ),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(toasts ?? RecordingToastService()),
    ],
  );
  await tester.pump();
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byKey(_stageKey)));
}

void _show(ProviderContainer c, CanvasCapsuleMessage m) =>
    c.read(canvasCapsuleProvider(_cv).notifier).show(m);

/// 出胶囊并等淡入走完。
Future<void> _showAndSettle(WidgetTester tester, ProviderContainer c, CanvasCapsuleMessage m) async {
  _show(c, m);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Rect _stage(WidgetTester tester) => tester.getRect(find.byKey(_stageKey));
Rect _capsule(WidgetTester tester) => tester.getRect(find.byType(InkCanvasCapsule));

void main() {
  testWidgets('没有消息时什么都不画', (tester) async {
    await _pump(tester);
    expect(find.byType(InkCanvasCapsule), findsNothing);
  });

  testWidgets('无提示词条：水平居中，底边离舞台底 16', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Done'));

    expect(find.text('Done'), findsOneWidget);
    expect(_capsule(tester).bottom, closeTo(_stage(tester).bottom - InkCanvasCapsuleSize.stageBottom, 0.5));
    expect(InkCanvasCapsuleSize.stageBottom, 16);
    expect(_capsule(tester).center.dx, closeTo(_stage(tester).center.dx, 0.5));
  });

  testWidgets('条高 60：底边离舞台底 84（条子上方 8），条高变了跟着动', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage.zoom(80));

    c.read(canvasPromptBarHeightProvider(_cv).notifier).report(60);
    await tester.pump();
    expect(_capsule(tester).bottom, closeTo(_stage(tester).bottom - 84, 0.5));

    c.read(canvasPromptBarHeightProvider(_cv).notifier).report(100);
    await tester.pump();
    expect(_capsule(tester).bottom, closeTo(_stage(tester).bottom - 124, 0.5));

    c.read(canvasPromptBarHeightProvider(_cv).notifier).report(0);
    await tester.pump();
    expect(_capsule(tester).bottom, closeTo(_stage(tester).bottom - 16, 0.5));
  });

  testWidgets('缩放胶囊按 l10n 渲染比例：Zoom 80%', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage.zoom(80));
    expect(find.text('Zoom 80%'), findsOneWidget);
  });

  testWidgets('左右各让出 171：长文案时胶囊不越过让位线，文字省略', (tester) async {
    final ProviderContainer c = await _pump(tester, stageWidth: 700);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: _long));

    expect(tester.takeException(), isNull);
    final Rect stage = _stage(tester);
    final Rect r = _capsule(tester);
    expect(r.left, greaterThanOrEqualTo(stage.left + InkCanvasCapsuleSize.sideReserve - 0.5));
    expect(r.right, lessThanOrEqualTo(stage.right - InkCanvasCapsuleSize.sideReserve + 0.5));
    expect(InkCanvasCapsuleSize.sideReserve, 171);
    expect(tester.widget<Text>(find.text(_long)).overflow, TextOverflow.ellipsis);
  });

  testWidgets('舞台宽 300：两侧让位后放不下，不画', (tester) async {
    final ProviderContainer c = await _pump(tester, stageWidth: 300);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Done'));

    expect(tester.takeException(), isNull);
    expect(find.byType(InkCanvasCapsule), findsNothing);
    expect(c.read(canvasCapsuleProvider(_cv)), isNotNull, reason: '不画，但计时照走');
  });

  testWidgets('不同消息：交叉淡入，旧的淡出、新的淡入，走完只剩新的', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'First'));

    _show(c, const CanvasCapsuleMessage(text: 'Second'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(InkCanvasCapsule), findsNWidgets(2), reason: '交叉淡入中两张都在');

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(InkCanvasCapsule), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);
  });

  testWidgets('同 dedupeKey 不重放淡入：原地改字，仍是同一张卡（同一个 Element）', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage.zoom(80));
    final Element before = tester.element(find.byType(InkCanvasCapsule));

    _show(c, const CanvasCapsuleMessage.zoom(96));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byType(InkCanvasCapsule), findsOneWidget, reason: 'AnimatedSwitcher 里没有第二张');
    expect(tester.element(find.byType(InkCanvasCapsule)), same(before));
    expect(find.text('Zoom 96%'), findsOneWidget);
    expect(find.text('Zoom 80%'), findsNothing);
  });

  testWidgets('点动作：调 onAction 并收起', (tester) async {
    int taps = 0;
    final ProviderContainer c = await _pump(tester);
    await _showAndSettle(
      tester,
      c,
      CanvasCapsuleMessage(
        text: 'Undone · Move 3 nodes',
        kind: CanvasCapsuleKind.action,
        actionLabel: 'Redo',
        actionHint: 'Ctrl Y',
        onAction: () => taps++,
      ),
    );

    await tester.tap(find.text('Redo'));
    await tester.pump();
    expect(taps, 1);
    expect(c.read(canvasCapsuleProvider(_cv)), isNull);
  });

  testWidgets('visible 变 false 立即收；回来不重放', (tester) async {
    final ValueNotifier<bool> visible = ValueNotifier<bool>(true);
    addTearDown(visible.dispose);
    final ProviderContainer c = await _pump(tester, visible: visible);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Done'));
    expect(find.byType(InkCanvasCapsule), findsOneWidget);

    visible.value = false;
    await tester.pump();
    expect(find.byType(InkCanvasCapsule), findsNothing, reason: '当帧就画空，不等淡出');
    expect(c.read(canvasCapsuleProvider(_cv)), isNull, reason: '换标签即收，不是藏起来');

    visible.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(InkCanvasCapsule), findsNothing, reason: '回来不重放');
  });

  testWidgets('悬停停表：鼠标在胶囊上不收，移开后续跑剩余时间', (tester) async {
    final ProviderContainer c = await _pump(tester);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Done'));

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(_capsule(tester).center);
    await tester.pump();

    await tester.pump(const Duration(seconds: 5));
    expect(c.read(canvasCapsuleProvider(_cv)), isNotNull, reason: '悬停时不收');
    expect(find.byType(InkCanvasCapsule), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.pump(kCanvasCapsuleTextDwell);
    expect(c.read(canvasCapsuleProvider(_cv)), isNull);
  });

  testWidgets('显示胶囊不调 ToastService（不进铃铛）', (tester) async {
    final RecordingToastService toasts = RecordingToastService();
    final ProviderContainer c = await _pump(tester, toasts: toasts);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage.zoom(120));
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Done'));

    expect(find.byType(InkCanvasCapsule), findsOneWidget);
    expect(toasts.shown, isEmpty);
  });

  testWidgets('Esc 不收胶囊：Esc 照原阶梯清选中，胶囊仍在', (tester) async {
    final ProviderContainer c = await _pump(tester, shortcuts: true);
    final ProviderSubscription<Set<String>> sel =
        c.listen(canvasSelectionControllerProvider(_cv), (_, _) {});
    addTearDown(sel.close);
    c.read(canvasSelectionControllerProvider(_cv).notifier).replace(<String>['a']);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Done'));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(c.read(canvasSelectionControllerProvider(_cv)), isEmpty, reason: 'Esc 阶梯的 selection 层照常清选中');
    expect(c.read(canvasCapsuleProvider(_cv)), isNotNull);
    expect(find.byType(InkCanvasCapsule), findsOneWidget);
  });
}
