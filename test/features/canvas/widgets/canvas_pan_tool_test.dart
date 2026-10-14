// 平移工具（H / 工具条平移键 / 按住空格）：平移生效时，从节点卡片上起拖也是拖画布——
// 卡片不收指针、节点不动；回到选择工具，同样的拖动挪的是节点。
//
// 钉的是 canvas_view.dart 的 _PanGate：拿掉它（或让 ignoring 恒为 false），平移时从卡片
// 上起拖会被卡片自己的拖拽手势抢走 ⇒「moved 为空」那条断言当场红。空格那条走真按键
// （CanvasShortcuts 的 onKeyEvent），按下与松开两头都钉住。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_tool_mode.dart';
import 'package:inkframe/features/canvas/widgets/canvas_shortcuts.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';

import '../../../_harness/fake_canvas.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/test_app.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasShortcuts(isActive: true, child: CanvasView())),
    overrides: <Override>[
      shellControllerProvider.overrideWith(
        () => ShellNavigator(initial: const ShellState(canvasId: 'c1')),
      ),
      canvasNodesControllerProvider
          .overrideWith(() => RecordingNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => FakeEdgesController()),
      canvasLanesControllerProvider.overrideWith(() => EmptyLanesController()),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

RecordingNodesController _recorder(ProviderContainer container) =>
    container.read(canvasNodesControllerProvider('c1').notifier)
        as RecordingNodesController;

Matrix4 _ivTransform(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;

/// 舞台光标那层：InteractiveViewer 最近的 MouseRegion 祖先（_StagePanCursor 里的那一层）。
MouseCursor _stageCursor(WidgetTester tester) => tester
    .widget<MouseRegion>(
      find
          .ancestor(
            of: find.byType(InteractiveViewer),
            matching: find.byType(MouseRegion),
          )
          .first,
    )
    .cursor;

final Finder _cardA = find.byKey(const ValueKey<String>('node-card-a'));

/// 从 [start] 起拖一段（远超拖拽阈值），松手后等动画落定。
Future<void> _dragFrom(WidgetTester tester, Offset start) async {
  final TestGesture gesture = await tester.startGesture(start);
  await gesture.moveBy(const Offset(40, 0));
  await gesture.moveBy(const Offset(40, 20));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('平移工具：从卡片上起拖 → 拖的是画布、节点不动；回到选择工具 → 同样的拖动挪节点',
      (tester) async {
    final ProviderContainer container = await _pump(tester);
    final RecordingNodesController rec = _recorder(container);

    container.read(canvasToolModeProvider('c1').notifier).pan();
    await tester.pump();

    final Matrix4 before = _ivTransform(tester).clone();
    await _dragFrom(tester, tester.getCenter(_cardA));
    expect(rec.moved, isEmpty, reason: '平移时卡片不收指针，节点不该被挪');
    expect(_ivTransform(tester), isNot(before), reason: '拖的是画布：变换应该变了');

    container.read(canvasToolModeProvider('c1').notifier).select();
    await tester.pump();

    await _dragFrom(tester, tester.getCenter(_cardA));
    expect(rec.moved, <String>['a'], reason: '回到选择工具，拖卡片 = 挪节点');
  });

  testWidgets('按住空格临时平移：按住时从卡片上起拖也是拖画布；松开后拖动又挪节点',
      (tester) async {
    final ProviderContainer container = await _pump(tester);
    final RecordingNodesController rec = _recorder(container);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final Matrix4 before = _ivTransform(tester).clone();
    await _dragFrom(tester, tester.getCenter(_cardA));
    expect(rec.moved, isEmpty);
    expect(_ivTransform(tester), isNot(before));

    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pump();

    await _dragFrom(tester, tester.getCenter(_cardA));
    expect(rec.moved, <String>['a'], reason: '松开空格就回到选择：拖卡片 = 挪节点');
  });

  testWidgets('光标：平移时舞台是手形（grab），不平移时交给卡片自己（defer）', (tester) async {
    final ProviderContainer container = await _pump(tester);
    expect(_stageCursor(tester), MouseCursor.defer);

    container.read(canvasToolModeProvider('c1').notifier).pan();
    await tester.pump();
    expect(_stageCursor(tester), SystemMouseCursors.grab);

    container.read(canvasToolModeProvider('c1').notifier).select();
    await tester.pump();
    expect(_stageCursor(tester), MouseCursor.defer);
  });
}
