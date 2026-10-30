// 选中边删除钮的删 / 撤销提示（stage/stage_edge_layer.dart 的 StageEdgeDeleteOverlay）。
//
// 这一层只在有选中边时挂着：点删除钮第一步就清选中（真控制器还会先把连线从内存里乐观拿掉），舞台骨架下一帧
// 就把整层拆了。写库往往慢于这一帧——等 removeEdge 回来，这一层的 context 早已失效。原来删除钮挂在舞台层上，
// 舞台一直在，没有这个问题；搬出来之后，撤销卡 / 失败卡要用的通知服务与文案必须在 await 之前取齐。
//
// 这里的假边控制器把 removeEdge 卡在一个 Completer 上：先出一帧确认删除钮所在层确实被拆了，再放行。
// 立即返回的假控制器（canvas_view_test 里那条）在下一帧之前就回来了，守不住这件事。
//
// 变异对照：去掉 util/canvas_edge_delete.dart 的 deleteEdgeWithUndo 里对 showCanvasUndoSnackWith 的调用 ⇒「撤销卡」红；
// 把它改回 `if (removed == null || !context.mounted) return;` 再 showCanvasUndoSnack(context, …) ⇒「撤销卡」红；
// 失败分支改回 `if (context.mounted) showCanvasSnack(…)` ⇒「失败卡」红。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/canvas/widgets/canvas_view.dart';
import 'package:inkframe/features/canvas/widgets/stage/stage_edge_layer.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';

import '../../../../_harness/fake_canvas.dart';
import '../../../../_harness/fake_toast_service.dart';
import '../../../../_harness/test_app.dart';

// ===== 夹具 =====

/// twoNodes（a / b 两张文本卡）之间的一条 data 连线。
const CanvasEdge _edge = CanvasEdge(
  id: 'e1',
  canvasId: 'c1',
  sourceNodeId: 'a',
  targetNodeId: 'b',
  edgeType: EdgeType.data,
);

// ===== 假控制器 =====

/// 连线：删除与真控制器同一个形状——先乐观移除，然后「写库」卡在 [gate] 上，直到测试放行。
/// [removeError] 非空时放行后回滚、上抛；否则返回被删的边（撤销令牌）。restore 记下收到的边并加回内存。
class _GatedEdges extends CanvasEdgesController {
  _GatedEdges({this.removeError});

  final InkError? removeError;
  final Completer<void> gate = Completer<void>();
  final List<String> removed = <String>[];
  final List<CanvasEdge> restored = <CanvasEdge>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => const <CanvasEdge>[_edge];

  @override
  Future<CanvasEdge?> removeEdge(String id) async {
    removed.add(id);
    final List<CanvasEdge> previous = state.valueOrNull ?? const <CanvasEdge>[];
    CanvasEdge? hit;
    for (final CanvasEdge e in previous) {
      if (e.id == id) hit = e;
    }
    state = AsyncData<List<CanvasEdge>>(<CanvasEdge>[
      for (final CanvasEdge e in previous)
        if (e.id != id) e,
    ]);
    await gate.future;
    final InkError? error = removeError;
    if (error != null) {
      state = AsyncData<List<CanvasEdge>>(previous);
      throw error;
    }
    return hit;
  }

  @override
  Future<void> restore(CanvasEdge edge) async {
    restored.add(edge);
    final List<CanvasEdge> previous = state.valueOrNull ?? const <CanvasEdge>[];
    state = AsyncData<List<CanvasEdge>>(<CanvasEdge>[...previous, edge]);
  }
}

// ===== 装配 =====

Future<ProviderContainer> _pump(WidgetTester tester, _GatedEdges edges) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: CanvasView()),
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => 'c1'),
      canvasNodesControllerProvider.overrideWith(() => FakeNodesController(twoNodes)),
      canvasEdgesControllerProvider.overrideWith(() => edges),
      // 泳道恒空且不触 PG，避免加载失败横幅混入额外的 close 图标。
      canvasLanesControllerProvider.overrideWith(EmptyLanesController.new),
      canvasLaneDirectionProvider('c1').overrideWith((_) async => LaneDirection.horizontal),
      fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
      toastServiceProvider.overrideWithValue(RecordingToastService()),
    ],
    surfaceSize: const Size(1200, 900),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(CanvasView)));
}

RecordingToastService _toastOf(ProviderContainer c) =>
    c.read(toastServiceProvider) as RecordingToastService;

/// 选中 e1 ⇒ 中点浮出删除钮；点它，再出一帧——删除钮所在层被拆掉，removeEdge 仍卡在 gate 上。
Future<void> _selectAndTapDelete(
  WidgetTester tester,
  ProviderContainer c,
  _GatedEdges edges,
) async {
  c.read(selectedEdgeControllerProvider('c1').notifier).select('e1');
  await tester.pumpAndSettle();

  final Finder deleteButton = find.descendant(
    of: find.byType(StageEdgeDeleteOverlay),
    matching: find.byIcon(Icons.close),
  );
  expect(deleteButton, findsOneWidget, reason: '前置：选中边后删除钮在');

  await tester.tap(deleteButton);
  // 舞台上挂着双击识别：单击可能要等 kDoubleTapTimeout（300ms）才落地。gate 不随时间放行，
  // 推一段时间只是让点击落地、清选中后的那一帧画出来。
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();

  expect(edges.removed, <String>['e1'], reason: '前置：点到了，removeEdge 已在等写库');
  expect(find.byType(StageEdgeDeleteOverlay), findsNothing,
      reason: '前置：清选中那一帧删除钮所在层确实被拆了');
  expect(_toastOf(c).shown, isEmpty, reason: '前置：写库还没回来，还没出卡');
}

void main() {
  testWidgets('删连线写库慢于一帧（删除钮所在层已拆）⇒ 仍出「Link deleted」撤销卡，撤销能复原',
      (WidgetTester tester) async {
    final _GatedEdges edges = _GatedEdges();
    final ProviderContainer c = await _pump(tester, edges);

    await _selectAndTapDelete(tester, c, edges);

    // 写库回来。
    edges.gate.complete();
    await tester.pumpAndSettle();

    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Link deleted'], reason: '删除钮所在层被拆过，撤销卡也不能丢');
    expect(toast.kinds, <ToastKind>[ToastKind.undo]);
    final ToastAction? undo = toast.shown.single.primary;
    expect(undo?.label, 'Undo');

    // 撤销卡画在 app 顶层的 ToastLayer 里、不在本测试的树上：直接调主按钮的回调。
    undo!.onPressed();
    await tester.pumpAndSettle();

    expect(edges.restored, hasLength(1));
    expect(edges.restored.single.id, 'e1');
    expect(toast.titles, <String>['Link deleted'], reason: '复原成功不再出卡');
  });

  testWidgets('删连线失败且慢于一帧（删除钮所在层已拆）⇒ 仍出「Failed to delete link」失败卡',
      (WidgetTester tester) async {
    final _GatedEdges edges = _GatedEdges(
      removeError: const LocalIOError(extra: <String, Object?>{'op': 'softDelete'}),
    );
    final ProviderContainer c = await _pump(tester, edges);

    await _selectAndTapDelete(tester, c, edges);

    // 写库失败回来：回滚、上抛。
    edges.gate.complete();
    await tester.pumpAndSettle();

    final RecordingToastService toast = _toastOf(c);
    expect(toast.titles, <String>['Failed to delete link'], reason: '删除钮所在层被拆过，失败卡也不能丢');
    expect(toast.kinds, <ToastKind>[ToastKind.error]);
    expect(toast.shown.single.primary, isNull, reason: '没删成，没有可撤销的东西');
    expect(edges.restored, isEmpty);
  });
}
