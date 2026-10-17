// 外壳级：键盘缩放与「适应」之后，舞台底部出「Zoom N%」轻提示胶囊；滚轮 / 缩放条 + − 不出。
//
// 画布级 pump 挂不上缩放条和胶囊宿主（它们是 canvas_screen 在外壳里摆的），所以这里走真外壳，
// 装置照 test/features/shell/shell_canvas_fit_test.dart 的 _pumpOnCanvas。全外壳测试禁 pumpAndSettle。
//
// 变异对照：
//   - zoomCanvasBy 去掉 showZoomCapsule ⇒「Ctrl = 出 Zoom 120%」「⌘− 出 Zoom 83%」红；
//   - resetCanvasZoom 去掉 showZoomCapsule ⇒「Ctrl 0 出 Zoom 100%」红；
//   - _fitNodes 去掉 showZoomCapsule ⇒「Shift 1 适应全部出比例」「缩放条 Fit 出比例」红；
//   - 改成在 canvasTransformController 上挂 listener 统一出胶囊 ⇒「滚轮缩放不出」「缩放条 + − 不出」红；
//   - _fitNodes 没东西可框（resetWhenEmpty: false）时也出 ⇒「Shift 2 选中的卡都在折叠道里：不出」红；
//   - _fitNodes 在 next == null（视口未量出）时也出 ⇒「视口未量出时 Shift 1：不出」红；
//   - 删掉 _fitNodes resetWhenEmpty 分支里的 showZoomCapsule ⇒「空画布 Shift 1：相机回初始、出 Zoom 100%」红。
//   「Shift 2 无选中：不出」守不到 _fitNodes——fitSelectedNodes 在选中为空时先返回了，它只守入口那一道。
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_capsule.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/lane_collapse_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/canvas_zoom_bar.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/theme/components/ink_canvas_capsule.dart';
import 'package:inkframe/theme/components/ink_icon.dart';
import 'package:inkframe/theme/icons/ink_glyph.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/shell_app.dart';

const String _canvasId = 'cv-capsule';

/// 一张在初始视口里，两张远在外面：适应全部一定要缩小。
final List<CanvasNode> _nodes = <CanvasNode>[
  textNode('near', 'Near', 40, canvasId: _canvasId),
  const CanvasNode(
    id: 'far',
    label: 'Far',
    type: CanvasNodeType.text,
    canvasId: _canvasId,
    position: Offset(2400, 1600),
  ),
  const CanvasNode(
    id: 'west',
    label: 'West',
    type: CanvasNodeType.text,
    canvasId: _canvasId,
    position: Offset(-1200, -500),
  ),
];

Future<void> _frames(WidgetTester tester, [int n = 4]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> _pumpOnCanvas(
  WidgetTester tester,
  String prefix, {
  List<CanvasNode>? nodes,
}) async {
  final paths = await setupTempPaths(tester, prefix);
  await pumpInkShell(
    tester,
    paths: paths,
    initial: const ShellState(
      tab: ShellTab.canvas,
      canvasId: _canvasId,
      project: ProjectRef(id: 'p1', name: 'Alpha'),
    ),
    extraOverrides: <Override>[
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(nodes ?? _nodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
  );
  await _frames(tester);
  return readShellContainer(tester);
}

double _scale(ProviderContainer c) =>
    scaleOf(c.read(canvasTransformControllerProvider(_canvasId)).value);

/// 相机此刻比例对应的胶囊文案。
String _zoomText(ProviderContainer c) => 'Zoom ${(_scale(c) * 100).round()}%';

Finder _zoomBarGlyph(InkGlyph glyph) => find.descendant(
      of: find.byType(CanvasZoomBar),
      matching: find.byWidgetPredicate((Widget w) => w is InkIcon && w.glyph == glyph),
    );

Future<void> _shift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

void _expectNoCapsule(WidgetTester tester, ProviderContainer c) {
  expect(find.byType(InkCanvasCapsule), findsNothing);
  expect(c.read(canvasCapsuleProvider(_canvasId)), isNull);
}

void main() {
  testWidgets('开画布时没有胶囊', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_none_');
    _expectNoCapsule(tester, c);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Ctrl = 出「Zoom 120%」', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_in_');

    await sendCtrl(tester, LogicalKeyboardKey.equal);
    await _frames(tester, 2);

    expect(_scale(c), closeTo(1.2, 1e-9));
    expect(find.text('Zoom 120%'), findsOneWidget);
    expect(find.byType(InkCanvasCapsule), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('连按三次 Ctrl =：仍是一枚胶囊，原地改成最后的比例', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_repeat_');

    await sendCtrl(tester, LogicalKeyboardKey.equal);
    await sendCtrl(tester, LogicalKeyboardKey.equal);
    await sendCtrl(tester, LogicalKeyboardKey.equal);
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byType(InkCanvasCapsule), findsOneWidget);
    expect(find.text('Zoom 173%'), findsOneWidget);
    expect(_zoomText(c), 'Zoom 173%');
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('⌘− 出「Zoom 83%」', (tester) async {
    await _pumpOnCanvas(tester, 'ink_capsule_out_');

    await sendMeta(tester, LogicalKeyboardKey.minus);
    await _frames(tester, 2);

    expect(find.text('Zoom 83%'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Ctrl 0 出「Zoom 100%」（先缩小、等胶囊收掉，再复位）', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_reset_');

    await sendCtrl(tester, LogicalKeyboardKey.minus);
    await _frames(tester, 2);
    expect(find.text('Zoom 83%'), findsOneWidget);
    await _frames(tester, 14); // 过了 1.2 s 停留 + 淡出
    _expectNoCapsule(tester, c);

    await sendCtrl(tester, LogicalKeyboardKey.digit0);
    await _frames(tester, 2);

    expect(_scale(c), closeTo(1.0, 1e-9));
    expect(find.text('Zoom 100%'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Shift 1 适应全部：出相机此刻的比例', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_fit_all_');

    await _shift(tester, LogicalKeyboardKey.digit1);
    await _frames(tester, 2);

    expect(_scale(c), lessThan(1.0), reason: '前提：真的缩小了');
    expect(find.text(_zoomText(c)), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('缩放条「Fit」：出相机此刻的比例', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_fit_bar_');

    await tester.tap(find.descendant(of: find.byType(CanvasZoomBar), matching: find.text('Fit')));
    await _frames(tester, 2);

    expect(_scale(c), lessThan(1.0), reason: '前提：真的缩小了');
    expect(find.text(_zoomText(c)), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('空画布 Shift 1：相机回初始、出「Zoom 100%」', (tester) async {
    // 走进 _fitNodes 的 resetWhenEmpty 分支：没有卡可框，适应全部把相机复位到 initialCanvasTransform()。
    final ProviderContainer c = await _pumpOnCanvas(
      tester,
      'ink_capsule_fit_empty_',
      nodes: const <CanvasNode>[],
    );
    // 直接写相机挪到非初始位置（缩小 + 平移）：不走快捷键，免得先出一枚胶囊。
    c.read(canvasTransformControllerProvider(_canvasId)).value = Matrix4.identity()
      ..translateByDouble(-300.0, -200.0, 0.0, 1.0)
      ..scaleByDouble(0.6, 0.6, 1.0, 1.0);
    await _frames(tester, 2);
    expect(
      c.read(canvasTransformControllerProvider(_canvasId)).value,
      isNot(initialCanvasTransform()),
      reason: '前提：相机不在初始位置',
    );
    expect(_scale(c), closeTo(0.6, 1e-9), reason: '前提：相机缩小过');
    _expectNoCapsule(tester, c);

    await _shift(tester, LogicalKeyboardKey.digit1);
    await _frames(tester, 2);

    expect(c.read(canvasTransformControllerProvider(_canvasId)).value, initialCanvasTransform());
    expect(c.read(canvasCapsuleProvider(_canvasId)), isNotNull);
    expect(find.text('Zoom 100%'), findsOneWidget);
    expect(find.byType(InkCanvasCapsule), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Shift 2 无选中：相机不动，不出胶囊', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_fit_sel_');
    final Matrix4 before = c.read(canvasTransformControllerProvider(_canvasId)).value.clone();

    await _shift(tester, LogicalKeyboardKey.digit2);
    await _frames(tester, 2);

    expect(c.read(canvasTransformControllerProvider(_canvasId)).value, before);
    _expectNoCapsule(tester, c);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('Shift 2 选中的卡都在折叠道里：相机不动，不出胶囊', (tester) async {
    // 走进 _fitNodes 的「没东西可框」分支（resetWhenEmpty: false）：选中非空，但看得见的为空。
    const String lane = 'lane-folded';
    final ProviderContainer c = await _pumpOnCanvas(
      tester,
      'ink_capsule_fit_sel_folded_',
      nodes: <CanvasNode>[
        ..._nodes,
        const CanvasNode(
          id: 'folded',
          label: 'Folded',
          type: CanvasNodeType.text,
          canvasId: _canvasId,
          laneId: lane,
          position: Offset(600, 300),
        ),
      ],
    );
    c.read(canvasSelectionControllerProvider(_canvasId).notifier).select('folded');
    c.read(laneCollapseProvider(_canvasId).notifier).toggle(lane);
    await _frames(tester, 2);
    expect(
      c.read(canvasSelectionControllerProvider(_canvasId)),
      <String>{'folded'},
      reason: '前提：选中还在，Shift 2 走得进 _fitNodes',
    );
    expect(c.read(laneCollapseProvider(_canvasId)), contains(lane), reason: '前提：道已折叠');
    final Matrix4 before = c.read(canvasTransformControllerProvider(_canvasId)).value.clone();

    await _shift(tester, LogicalKeyboardKey.digit2);
    await _frames(tester, 2);

    expect(c.read(canvasTransformControllerProvider(_canvasId)).value, before);
    _expectNoCapsule(tester, c);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('视口未量出时 Shift 1：相机不动，不出胶囊', (tester) async {
    // 走进 _fitNodes 的 next == null 分支：有卡可框，但视口是 Size.zero（fitArea 返回 null）。
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_fit_no_viewport_');
    final Matrix4 before = c.read(canvasTransformControllerProvider(_canvasId)).value.clone();

    // 置零后不 pump、紧接着按键：舞台 LayoutBuilder 的帧后回调还来不及把真实尺寸写回来。
    c.read(canvasViewportSizeProvider(_canvasId).notifier).setSize(Size.zero);
    expect(c.read(canvasViewportSizeProvider(_canvasId)), Size.zero, reason: '前提：视口未量出');
    await _shift(tester, LogicalKeyboardKey.digit1);
    await _frames(tester, 2);

    expect(c.read(canvasTransformControllerProvider(_canvasId)).value, before);
    _expectNoCapsule(tester, c);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('滚轮缩放：相机变了，但不出胶囊', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_wheel_');
    final Rect stage = tester.getRect(find.byType(CanvasView));
    // 舞台右下一块空处：不在卡片、缩放条、提示词条上。
    final Offset at = stage.bottomRight - const Offset(200, 120);

    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.addPointer(location: at));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
    await _frames(tester, 2);
    await tester.sendEventToBinding(mouse.removePointer());

    expect(_scale(c), isNot(closeTo(1.0, 1e-6)), reason: '前提：滚轮真的缩放了相机');
    _expectNoCapsule(tester, c);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('缩放条 + / −：相机变了，但不出胶囊', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_capsule_bar_btn_');

    await tester.tap(_zoomBarGlyph(InkGlyph.zoomIn));
    await _frames(tester, 2);
    expect(_scale(c), closeTo(1.2, 1e-9), reason: '前提：放大了一档');
    _expectNoCapsule(tester, c);

    await tester.tap(_zoomBarGlyph(InkGlyph.zoomOut));
    await tester.tap(_zoomBarGlyph(InkGlyph.zoomOut));
    await _frames(tester, 2);
    expect(_scale(c), lessThan(1.0), reason: '前提：又缩小了两档');
    _expectNoCapsule(tester, c);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
