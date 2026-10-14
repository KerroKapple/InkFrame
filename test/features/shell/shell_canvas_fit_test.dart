// 外壳级：适应全部之后，所有卡片都落在画布区里——扣掉顶部浮动工具条那一条与底部缩放条那一截。
//
// 画布级 pump 量不出这件事：舞台上方压着的浮动工具条、左下的缩放条都是 canvas_screen 在外壳里摆的，
// 画布区的大小也由外壳的三栏（左栏 | 画布区 | 检查器）决定。这里在真外壳里按 Shift+1，再点一次缩放条
// 「适应」，两条路都要把卡片框进同一块。
// 全外壳测试禁 pumpAndSettle（见 test/_harness/shell_app.dart）。
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_tool_actions.dart';
import 'package:inkframe/features/canvas/util/canvas_zoom.dart';
import 'package:inkframe/features/canvas/widgets/canvas_toolbar.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/canvas_zoom_bar.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';

import '../../_harness/fake_canvas.dart';
import '../../_harness/shell_app.dart';

const String _canvasId = 'cv-fit';

/// 一张在初始视口里，两张远在外面（右下、左上）。
final List<CanvasNode> _nodes = <CanvasNode>[
  textNode('near', 'Near', 40, canvasId: _canvasId),
  // 散得够开（初始视口装不下），又不至于开到最小缩放也装不下：外壳里画布区大约 850 宽。
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

Finder _card(String id) => find.byKey(ValueKey<String>('node-card-$id'));

Future<void> _frames(WidgetTester tester, [int n = 4]) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> _pumpOnCanvas(WidgetTester tester, String prefix) async {
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
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(_nodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
    ],
  );
  await _frames(tester);
  return readShellContainer(tester);
}

/// 画布区扣掉适应的留白之后的那一块（全局坐标）。
Rect _fitArea(WidgetTester tester) =>
    kCanvasFitInsets.deflateRect(tester.getRect(find.byType(CanvasView)));

/// 每一张卡都整个落在 [_fitArea] 里，且上沿不高于浮动工具条的下沿。
void _expectAllCardsFramed(WidgetTester tester) {
  final Rect area = _fitArea(tester);
  final Rect toolbar = tester.getRect(find.byType(CanvasToolbar));
  for (final CanvasNode n in _nodes) {
    final Rect r = tester.getRect(_card(n.id));
    expect(
      r.left >= area.left - 0.5 &&
          r.top >= area.top - 0.5 &&
          r.right <= area.right + 0.5 &&
          r.bottom <= area.bottom + 0.5,
      isTrue,
      reason: '${n.id}：$r 应在 $area 里',
    );
    expect(r.top, greaterThanOrEqualTo(toolbar.bottom), reason: '${n.id} 不能压在浮动工具条底下');
  }
}

void main() {
  testWidgets('Shift+1 适应全部：所有卡片都落进画布区（扣掉顶部工具条那一条与底部缩放条那一截）', (tester) async {
    final ProviderContainer c = await _pumpOnCanvas(tester, 'ink_shell_fit_key_');
    final Rect stage = tester.getRect(find.byType(CanvasView));
    expect(
      stage.overlaps(tester.getRect(_card('far'))),
      isFalse,
      reason: '前提：远处那张一开始不在画布区里',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await _frames(tester, 2);

    expect(scaleOf(c.read(canvasTransformControllerProvider(_canvasId)).value), lessThan(1.0));
    _expectAllCardsFramed(tester);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('缩放条「适应」= 适应全部：同样把所有卡片框进画布区', (tester) async {
    await _pumpOnCanvas(tester, 'ink_shell_fit_bar_');

    await tester.tap(find.descendant(of: find.byType(CanvasZoomBar), matching: find.text('Fit')));
    await _frames(tester, 2);

    _expectAllCardsFramed(tester);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
