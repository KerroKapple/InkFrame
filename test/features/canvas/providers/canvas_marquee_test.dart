// CanvasMarqueeController（providers/canvas_marquee.dart）：框选进行中的状态机。
//
//   - begin 快照按下前的选中、清掉选中连线，选中此刻不动；
//   - update 按模式（替换 / 加选 / 反选）把命中实时写回选中控制器，selectedCount = 写回后的选中数；
//     每次按此刻的节点集重算（被删的节点不会留在选中里）；setMode 不等指针再动就重算；
//   - commit 收框、选中保留；cancel 恢复按下前的选中并滤掉已删节点，没在框选时返回 false；
//     收框之后 update 不理（不重新起框）；
//   - marqueeModeFor：mac 上 ⌘ 反选、Ctrl 不参与；其余平台 Ctrl 反选；Shift 加选；反选优先。
//
// 变异对照：cancel 不恢复 before ⇒「cancel 恢复 before」红；cancel 不滤已删节点 ⇒ 同一条红；
// marqueeModeFor 在 mac 上把 control 当反选 / 删掉 meta 判断 ⇒「marqueeModeFor」红。
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_marquee.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/lane_collapse_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_extent.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/util/selection_geometry.dart';

import '../../../_harness/fake_canvas.dart';

// 无道的三张卡（命中矩形 kNodeCardSize 224×191，舞台坐标 = 世界 + kStageOrigin，初始相机缩放 1）。
const CanvasNode _a = CanvasNode(
  id: 'a',
  label: 'A',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(0, 0),
);
const CanvasNode _b = CanvasNode(
  id: 'b',
  label: 'B',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(300, 0),
);
const CanvasNode _c = CanvasNode(
  id: 'c',
  label: 'C',
  type: CanvasNodeType.text,
  canvasId: 'c1',
  position: Offset(0, 400),
);

/// 世界坐标 → 舞台坐标。
Offset _stage(double x, double y) => Offset(x, y) + kStageOrigin;

/// 框住 a、b 的两个角（世界坐标 (-20,-20) → (400,100)）。
final Offset _abStart = _stage(-20, -20);
final Offset _abEnd = _stage(400, 100);

/// 只框住 b 的另一角（与 [_bStart] 配对）。
final Offset _bStart = _stage(280, -20);
final Offset _bEnd = _stage(400, 100);

const Offset _pointer = Offset(10, 10);

Future<ProviderContainer> _container() async {
  final ProviderContainer c = ProviderContainer(
    overrides: <Override>[
      canvasNodesControllerProvider
          .overrideWith(() => FakeNodesController(<CanvasNode>[_a, _b, _c])),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      canvasLaneDirectionProvider('c1')
          .overrideWith((_) async => LaneDirection.horizontal),
    ],
  );
  addTearDown(c.dispose);
  // 全是 autoDispose：挂住订阅，测试期间不被回收。
  c.listen(canvasMarqueeProvider('c1'), (_, _) {});
  c.listen(canvasSelectionControllerProvider('c1'), (_, _) {});
  c.listen(selectedEdgeControllerProvider('c1'), (_, _) {});
  c.listen(canvasNodesControllerProvider('c1'), (_, _) {});
  c.listen(canvasLanesControllerProvider('c1'), (_, _) {});
  c.listen(canvasLaneDirectionProvider('c1'), (_, _) {});
  c.listen(laneCollapseProvider('c1'), (_, _) {});
  c.listen(canvasTransformControllerProvider('c1'), (_, _) {});
  await c.read(canvasNodesControllerProvider('c1').future);
  await c.read(canvasLanesControllerProvider('c1').future);
  await c.read(canvasLaneDirectionProvider('c1').future);
  return c;
}

CanvasMarqueeController _marquee(ProviderContainer c) =>
    c.read(canvasMarqueeProvider('c1').notifier);

Set<String> _selection(ProviderContainer c) =>
    c.read(canvasSelectionControllerProvider('c1'));

void _select(ProviderContainer c, Set<String> ids) =>
    c.read(canvasSelectionControllerProvider('c1').notifier).replace(ids);

void main() {
  test('begin 快照 before、清选中连线；选中此刻不动', () async {
    final ProviderContainer c = await _container();
    _select(c, <String>{'c'});
    c.read(selectedEdgeControllerProvider('c1').notifier).select('e1');

    _marquee(c).begin(_abStart, mode: MarqueeMode.add);

    final MarqueeState? s = c.read(canvasMarqueeProvider('c1'));
    expect(s, isNotNull);
    expect(s!.before, <String>{'c'});
    expect(s.mode, MarqueeMode.add);
    expect(s.startStage, _abStart);
    expect(s.stageRect, Rect.fromPoints(_abStart, _abStart));
    expect(c.read(selectedEdgeControllerProvider('c1')), isNull);
    expect(_selection(c), <String>{'c'});
  });

  test('update 按模式写回选中，selectedCount 正确', () async {
    final ProviderContainer c = await _container();

    // 替换：按下前选着 c，框住 a、b ⇒ {a, b}。
    _select(c, <String>{'c'});
    _marquee(c).begin(_abStart, mode: MarqueeMode.replace);
    _marquee(c).update(_abEnd, pointerGlobal: _pointer);
    expect(_selection(c), <String>{'a', 'b'});
    expect(c.read(canvasMarqueeProvider('c1'))!.selectedCount, 2);
    expect(c.read(canvasMarqueeProvider('c1'))!.pointerGlobal, _pointer);
    _marquee(c).commit();

    // 加选：before {c} ∪ {a, b}。
    _select(c, <String>{'c'});
    _marquee(c).begin(_abStart, mode: MarqueeMode.add);
    _marquee(c).update(_abEnd, pointerGlobal: _pointer);
    expect(_selection(c), <String>{'a', 'b', 'c'});
    expect(c.read(canvasMarqueeProvider('c1'))!.selectedCount, 3);
    _marquee(c).commit();

    // 反选：before {a} △ {a, b} = {b}。
    _select(c, <String>{'a'});
    _marquee(c).begin(_abStart, mode: MarqueeMode.invert);
    _marquee(c).update(_abEnd, pointerGlobal: _pointer);
    expect(_selection(c), <String>{'b'});
    expect(c.read(canvasMarqueeProvider('c1'))!.selectedCount, 1);
    _marquee(c).commit();
  });

  test('setMode：不等指针再动，当场按新方式重算', () async {
    final ProviderContainer c = await _container();
    _select(c, <String>{'c'});
    _marquee(c).begin(_bStart, mode: MarqueeMode.replace);
    _marquee(c).update(_bEnd, pointerGlobal: _pointer);
    expect(_selection(c), <String>{'b'});

    _marquee(c).setMode(MarqueeMode.add);
    expect(_selection(c), <String>{'b', 'c'});
    expect(c.read(canvasMarqueeProvider('c1'))!.mode, MarqueeMode.add);

    _marquee(c).setMode(MarqueeMode.replace);
    expect(_selection(c), <String>{'b'});
  });

  test('update 按此刻的节点集重算：框选中被删的节点不会留在选中里', () async {
    final ProviderContainer c = await _container();
    _select(c, <String>{'c'});
    _marquee(c).begin(_abStart, mode: MarqueeMode.add);
    _marquee(c).update(_abEnd, pointerGlobal: _pointer);
    expect(_selection(c), <String>{'a', 'b', 'c'});

    await c.read(canvasNodesControllerProvider('c1').notifier).removeNode('a');
    await c.read(canvasNodesControllerProvider('c1').notifier).removeNode('c');
    _marquee(c).update(_abEnd, pointerGlobal: _pointer);
    expect(_selection(c), <String>{'b'});
  });

  test('cancel 恢复 before 并滤掉已删节点，返回 true；未在框选时返回 false', () async {
    final ProviderContainer c = await _container();
    expect(_marquee(c).cancel(), isFalse, reason: '没在框选：没东西可退');

    _select(c, <String>{'a', 'c'});
    _marquee(c).begin(_bStart, mode: MarqueeMode.replace);
    _marquee(c).update(_bEnd, pointerGlobal: _pointer);
    expect(_selection(c), <String>{'b'});

    await c.read(canvasNodesControllerProvider('c1').notifier).removeNode('c');
    expect(_marquee(c).cancel(), isTrue);
    expect(_selection(c), <String>{'a'}, reason: '恢复按下前的选中，已删的 c 滤掉');
    expect(c.read(canvasMarqueeProvider('c1')), isNull);
    expect(_marquee(c).cancel(), isFalse);
  });

  test('cancel 之后 update 不理：不重新起框、选中不变', () async {
    final ProviderContainer c = await _container();
    _select(c, <String>{'c'});
    _marquee(c).begin(_abStart, mode: MarqueeMode.replace);
    _marquee(c).update(_bEnd, pointerGlobal: _pointer);
    _marquee(c).cancel();

    _marquee(c).update(_abEnd, pointerGlobal: _pointer);
    _marquee(c).setMode(MarqueeMode.add);
    expect(c.read(canvasMarqueeProvider('c1')), isNull);
    expect(_selection(c), <String>{'c'});
  });

  test('commit 后 state 为 null、选中保留', () async {
    final ProviderContainer c = await _container();
    _marquee(c).begin(_abStart, mode: MarqueeMode.replace);
    _marquee(c).update(_abEnd, pointerGlobal: _pointer);
    _marquee(c).commit();

    expect(c.read(canvasMarqueeProvider('c1')), isNull);
    expect(_selection(c), <String>{'a', 'b'});
  });

  test('marqueeModeFor：四个平台 × 修饰键组合', () {
    MarqueeMode mode(
      TargetPlatform platform, {
      bool shift = false,
      bool control = false,
      bool meta = false,
    }) =>
        marqueeModeFor(shift: shift, control: control, meta: meta, platform: platform);

    // mac：⌘ 反选，Ctrl 不参与。
    expect(mode(TargetPlatform.macOS), MarqueeMode.replace);
    expect(mode(TargetPlatform.macOS, meta: true), MarqueeMode.invert);
    expect(mode(TargetPlatform.macOS, control: true), MarqueeMode.replace);
    expect(mode(TargetPlatform.macOS, shift: true), MarqueeMode.add);
    expect(mode(TargetPlatform.macOS, shift: true, control: true), MarqueeMode.add);
    expect(mode(TargetPlatform.macOS, shift: true, meta: true), MarqueeMode.invert,
        reason: '反选优先');

    // 其余平台：Ctrl 反选，⌘ / Win 键不参与。
    for (final TargetPlatform p in <TargetPlatform>[
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.android,
    ]) {
      expect(mode(p), MarqueeMode.replace, reason: '$p');
      expect(mode(p, control: true), MarqueeMode.invert, reason: '$p');
      expect(mode(p, meta: true), MarqueeMode.replace, reason: '$p');
      expect(mode(p, shift: true), MarqueeMode.add, reason: '$p');
      expect(mode(p, shift: true, meta: true), MarqueeMode.add, reason: '$p');
      expect(mode(p, shift: true, control: true), MarqueeMode.invert,
          reason: '$p 反选优先');
    }
  });
}
