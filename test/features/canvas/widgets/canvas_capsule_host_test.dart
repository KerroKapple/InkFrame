// CanvasCapsuleHost：画布轻提示胶囊在舞台上的宿主——定位、两侧让位、太窄不画、同一张卡不重放淡入、
// 换标签即收、悬停停表（含悬停中鼠标区域被卸下）、淡出中的旧卡不再执行动作、不进 Esc 链。
//
// 装置：pumpInkApp 里一块定宽的「舞台」（Stack；宽度可由 ValueNotifier 改），宿主挂在里面，与 canvas_screen.dart 一样是 Stack 的直接孩子。
// 「同轴」两条用例另挂真提示词条（与 canvas_screen.dart 同样的 Positioned(left 0, right 0, bottom 16)），
// 条子自己量高度报给 provider，胶囊的中心与条子本体（surfaceKey）的中心直接比，不拿 promptBarPlacement 自证。
// 胶囊有 120ms 交叉淡入：全文件只 pump 固定时长，不 pumpAndSettle。
//
// 变异对照：
//   - 宿主 bottom 写成 h + InkCanvasCapsuleSize.stageBottom（漏了间隙 8）⇒「条高 60：底边离舞台底 84」红；
//   - 宿主不让 sideReserve（_capsuleSpan 的 half 只取右侧那一项）⇒「左右各让出 171」与「条子显示 + 长文案」红；
//   - _capsuleSpan 的 center 不论条子显示与否都取舞台中心（stageWidth / 2）⇒「提示词条显示：胶囊与条子同轴」红
//     （舞台 855 时条子为左下那一簇让位，条子中心比舞台中心偏右约 80）；
//   - center 不论条子显示与否都取条子中心 ⇒ 同一条用例后半段「条子收起回到舞台中心」红；
//   - 控制器 show 去掉同 dedupeKey 的原地分支（总是换卡）⇒「同 dedupeKey 不重放淡入」红；
//   - visible 变 false 不 dismiss ⇒「visible 变 false 立即收」红；
//   - MouseRegion 不接 setHovered ⇒「悬停停表」红；
//   - 宿主 span == null 分支去掉 _clearHoverAfterFrame()（只 return SizedBox.shrink）⇒
//     「悬停中舞台变窄画不下：悬停复位，胶囊照常收」红；
//   - 动作闭包去掉「在场的还是不是这一条」的判断 ⇒「淡出中的旧卡再点：onAction 只执行一次」红。
// 「不走通知（不调 ToastService）」守在真入口上：canvas_capsule_zoom_test.dart——这里直接调 show() 绕过了入口，
// 而控制器与宿主根本不碰 ToastService，放在这里的断言不可能红。
// 换画布不淡出旧卡守在 canvas_capsule_zoom_test.dart（真外壳里切画布，key 加在 canvas_screen.dart）。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_prompt_bar_height.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/inspector_submit_controller.dart';
import 'package:inkframe/features/canvas/widgets/canvas_capsule_host.dart';
import 'package:inkframe/features/canvas/widgets/canvas_prompt_bar.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/theme/components/ink_canvas_capsule.dart';
import 'package:inkframe/theme/tokens.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

const String _cv = 'c1';
const Key _stageKey = Key('test.stage');
const String _long =
    'Connected after shot 7 · and a very long description that will never fit in the middle of the stage';

/// 选中它，提示词条就出现（image config 节点）。
const CanvasNode _imageNode = CanvasNode(
  id: 'img',
  label: 'Shot',
  type: CanvasNodeType.image,
  canvasId: _cv,
  typeConfig: <String, Object?>{'prompt': 'a cat'},
);

/// 打字不落库：同轴用例只看版式，防抖保存的计时器与仓储都不该被碰到。
class _NoSave extends InspectorSubmitController {
  @override
  void savePromptDebounced(String prompt) {}
}

/// 舞台宽 [stageWidth]（给了 [width] 就跟着它变）、高 400；[visible] 驱动宿主的可见性；
/// [shortcuts] 时外包 CanvasShortcuts（Esc 用例）；
/// [promptBar] 时照 canvas_screen.dart 在宿主前挂真提示词条，节点表换成 [_imageNode]。
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  double stageWidth = 900,
  ValueNotifier<double>? width,
  ValueNotifier<bool>? visible,
  bool shortcuts = false,
  bool promptBar = false,
}) async {
  final ValueNotifier<bool> vis = visible ?? ValueNotifier<bool>(true);
  final ValueNotifier<double> w = width ?? ValueNotifier<double>(stageWidth);
  Widget body = Center(
    child: ValueListenableBuilder<double>(
      valueListenable: w,
      builder: (BuildContext context, double sw, _) => SizedBox(
        key: _stageKey,
        width: sw,
        height: 400,
        child: ValueListenableBuilder<bool>(
          valueListenable: vis,
          builder: (BuildContext context, bool v, _) => Stack(
            children: <Widget>[
              const Positioned.fill(child: SizedBox.expand()),
              if (promptBar)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: InkToolbarSize.promptBarBottom,
                  child: CanvasPromptBar(canvasId: _cv),
                ),
              CanvasCapsuleHost(canvasId: _cv, visible: v),
            ],
          ),
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
      canvasNodesControllerProvider.overrideWith(
        () => FakeNodesController(promptBar ? const <CanvasNode>[_imageNode] : twoNodes),
      ),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
      if (promptBar) ...<Override>[
        canvasRepositoryProvider.overrideWith((_) async => InMemoryCanvasRepository()),
        inspectorSubmitControllerProvider.overrideWith(_NoSave.new),
      ],
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

  testWidgets('提示词条显示：胶囊与条子同轴（舞台 855，条子为左下让位而偏右）；条子收起回到舞台中心', (tester) async {
    final ProviderContainer c = await _pump(tester, stageWidth: 855, promptBar: true);
    c.read(canvasSelectionControllerProvider(_cv).notifier).replace(<String>[_imageNode.id]);
    await tester.pump();
    await tester.pump();
    await _showAndSettle(tester, c, const CanvasCapsuleMessage.zoom(80));

    expect(tester.takeException(), isNull);
    expect(find.byKey(CanvasPromptBar.surfaceKey), findsOneWidget);
    expect(c.read(canvasPromptBarHeightProvider(_cv)), greaterThan(0), reason: '条子把自己的高度报上来了');
    final Rect stage = _stage(tester);
    final Rect bar = tester.getRect(find.byKey(CanvasPromptBar.surfaceKey));
    // 前提：这个舞台宽下条子确实为左下那一簇让了位——否则条子中心 = 舞台中心，本条守不住任何东西。
    expect((bar.center.dx - stage.center.dx).abs(), greaterThan(40));

    final Rect capsule = _capsule(tester);
    expect(capsule.center.dx, closeTo(bar.center.dx, 0.5));
    expect(capsule.bottom, lessThanOrEqualTo(bar.top + 0.5), reason: '胶囊在条子上方');
    expect(capsule.left, greaterThanOrEqualTo(stage.left + InkCanvasCapsuleSize.sideReserve - 0.5));
    expect(capsule.right, lessThanOrEqualTo(stage.right + 0.5));

    c.read(canvasSelectionControllerProvider(_cv).notifier).clear();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(CanvasPromptBar.surfaceKey), findsNothing);
    expect(c.read(canvasPromptBarHeightProvider(_cv)), 0);
    expect(_capsule(tester).center.dx, closeTo(stage.center.dx, 0.5));
    expect(_capsule(tester).bottom, closeTo(stage.bottom - InkCanvasCapsuleSize.stageBottom, 0.5));
  });

  testWidgets('提示词条显示 + 长文案：左不越过缩放条让位线、右不出舞台，文字省略', (tester) async {
    final ProviderContainer c = await _pump(tester, stageWidth: 855, promptBar: true);
    c.read(canvasSelectionControllerProvider(_cv).notifier).replace(<String>[_imageNode.id]);
    await tester.pump();
    await tester.pump();
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: _long));

    expect(tester.takeException(), isNull);
    final Rect stage = _stage(tester);
    final Rect bar = tester.getRect(find.byKey(CanvasPromptBar.surfaceKey));
    final Rect r = _capsule(tester);
    expect(r.center.dx, closeTo(bar.center.dx, 0.5));
    expect(r.left, greaterThanOrEqualTo(stage.left + InkCanvasCapsuleSize.sideReserve - 0.5));
    expect(r.right, lessThanOrEqualTo(stage.right - InkSpacing.md + 0.5));
    expect(tester.widget<Text>(find.text(_long)).overflow, TextOverflow.ellipsis);
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

  testWidgets('淡出中的旧卡再点：onAction 只执行一次', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 30));
    expect(taps, 1);
    expect(c.read(canvasCapsuleProvider(_cv)), isNull);
    // 前提：收起后旧卡还在淡出（120ms），还点得到——否则第二下根本落不到卡上，本条守不住任何东西。
    expect(find.text('Redo'), findsOneWidget, reason: '前提：旧卡还在淡出');

    await tester.tap(find.text('Redo'));
    await tester.pump();
    expect(taps, 1, reason: '淡出中的旧卡不再执行动作');

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(InkCanvasCapsule), findsNothing);
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

  testWidgets('悬停中舞台变窄画不下：悬停复位，胶囊照常收，之后的胶囊也照常收', (tester) async {
    final ValueNotifier<double> width = ValueNotifier<double>(900);
    addTearDown(width.dispose);
    final ProviderContainer c = await _pump(tester, width: width);
    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Done'));

    final TestGesture mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(_capsule(tester).center);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(c.read(canvasCapsuleProvider(_cv)), isNotNull, reason: '前提：悬停停住了表');

    // 悬停中舞台变窄到画不下：鼠标区域连同胶囊一起卸下，收不到移出。
    width.value = 300;
    await tester.pump();
    await tester.pump();
    expect(find.byType(InkCanvasCapsule), findsNothing, reason: '前提：画不下');

    // 鼠标挪开时没有鼠标区域、不会有进出事件；舞台再变宽，胶囊不在鼠标下面——之后再没有任何事件能清悬停。
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    width.value = 900;
    await tester.pump();
    await tester.pump();
    expect(find.byType(InkCanvasCapsule), findsOneWidget, reason: '前提：变宽后又画出来了');

    await tester.pump(kCanvasCapsuleTextDwell);
    expect(c.read(canvasCapsuleProvider(_cv)), isNull, reason: '悬停已复位，按剩余时间收');

    await _showAndSettle(tester, c, const CanvasCapsuleMessage(text: 'Again'));
    expect(find.text('Again'), findsOneWidget);
    await tester.pump(kCanvasCapsuleTextDwell);
    expect(c.read(canvasCapsuleProvider(_cv)), isNull, reason: '本画布之后的胶囊照常计时');
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
