// 泳道动作（util/canvas_lane_actions.dart）：解散泳道（不确认 + 撤销卡）与删除泳道和内容（有生成中任务先确认）。
//
// 装配：真 CanvasLanesController / CanvasNodesController 跑在 InMemory 三件套 + FakeUnitOfWork 上；通知卡记进
// RecordingToastService；JobQueueService 用本文件的 [_FakeQueue] 记下 cancel 收到的 id；活动任务直接种进
// jobsRegistryProvider。BuildContext / WidgetRef 从一个 Consumer 里拿——它顺带 watch 住动作要读的 autoDispose
// provider（画布页开着时由舞台骨架 watch 着）。
//
// 变异对照：解散时调了 history.record ⇒「历史栈 undo 为空」红；activeJobsInLane 不排除终态 ⇒「无活动任务：不弹框」
// 红（种了一条 succeeded）；动作层总是弹确认 ⇒ 同条红；从不弹 ⇒「有 running 任务：弹框」红；确认后不取消任务 ⇒
// 「cancel 被调用 N 次」红；删完不清选中 ⇒「选中集去掉被删节点」红。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/toast_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/features/canvas/models/style_lane.dart';
import 'package:inkframe/features/canvas/providers/canvas_history_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_lanes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_selection_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_transform_controller.dart';
import 'package:inkframe/features/canvas/providers/lane_collapse_controller.dart';
import 'package:inkframe/features/canvas/providers/selected_edge_controller.dart';
import 'package:inkframe/features/canvas/util/canvas_lane_actions.dart';
import 'package:inkframe/features/canvas/util/lane_geometry.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/notifications/providers/toast_service_provider.dart';

import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_toast_service.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../_harness/test_app.dart';
import '../../../helpers/recording_logger.dart';

const String _cv = 'c1';

/// 记下 cancel 收到的 id；[onCancel] 在每次 cancel 时回调（钉「先取消、再删」的顺序）。
class _FakeQueue implements JobQueueService {
  _FakeQueue({this.onCancel});

  final void Function()? onCancel;
  final List<String> cancelled = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<JobHandle> submit(GenerationTask task) => throw UnimplementedError();

  @override
  Future<void> cancel(String jobId) async {
    onCancel?.call();
    cancelled.add(jobId);
  }

  @override
  void dispose() {}
}

/// 库 + 已挂好的界面。道 Ink（n1、n2，n1→n2 一条边）在上，空道 Cyber 在下；道外 x，x→n1 一条边。
class _Env {
  _Env(this.c, this.ctx, this.ref);

  final ProviderContainer c;
  final BuildContext ctx;
  final WidgetRef ref;

  late final InMemoryNodeRepository nodes;
  late final InMemoryEdgeRepository edges;
  late final InMemoryStyleLaneRepository lanes;
  late final RecordingToastService toasts;
  late final _FakeQueue queue;
  late final String ink;
  late final String cyber;
  late final String n1;
  late final String n2;
  late final String x;
  late final String eInner;
  late final String eIn;

  StyleLane laneOf(String id) =>
      c.read(canvasLanesControllerProvider(_cv)).valueOrNull!.firstWhere((StyleLane l) => l.id == id);

  List<String> get laneIds => <String>[
        for (final StyleLane l in c.read(canvasLanesControllerProvider(_cv)).valueOrNull!) l.id,
      ];

  bool laneDeleted(String id) => lanes.rows[id]!['deleted_at'] != null;
  bool nodeDeleted(String id) => nodes.rows[id]!['deleted_at'] != null;
}

Future<_Env> _pump(WidgetTester tester, {void Function(_Env env)? onCancel}) async {
  final InMemoryNodeRepository nodes = InMemoryNodeRepository();
  final InMemoryEdgeRepository edges = InMemoryEdgeRepository();
  final InMemoryStyleLaneRepository lanes = InMemoryStyleLaneRepository();
  final String ink = await lanes.create(canvasId: _cv, label: 'Ink', sortOrder: 0);
  final String cyber = await lanes.create(canvasId: _cv, label: 'Cyber', sortOrder: 1);
  final String n1 = await nodes.create(
      canvasId: _cv, type: 'image', nodeRole: 'config', laneId: ink, positionX: 100, positionY: 120);
  final String n2 = await nodes.create(
      canvasId: _cv,
      type: 'image',
      nodeRole: 'result',
      sourceNodeId: n1,
      laneId: ink,
      positionX: 400,
      positionY: 120);
  final String x = await nodes.create(
      canvasId: _cv, type: 'text', nodeRole: 'config', positionX: 100, positionY: 1200);
  final String eInner =
      await edges.create(canvasId: _cv, sourceNodeId: n1, targetNodeId: n2, edgeType: 'data');
  final String eIn =
      await edges.create(canvasId: _cv, sourceNodeId: x, targetNodeId: n1, edgeType: 'data');

  final RecordingToastService toasts = RecordingToastService();
  late final _Env env;
  final _FakeQueue queue = _FakeQueue(onCancel: () => onCancel?.call(env));

  late BuildContext ctx;
  late WidgetRef wref;
  await pumpInkApp(
    tester,
    Scaffold(
      body: Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          ref.watch(canvasNodesControllerProvider(_cv));
          ref.watch(canvasLanesControllerProvider(_cv));
          ref.watch(laneCollapseProvider(_cv));
          ref.watch(canvasSelectionControllerProvider(_cv));
          ref.watch(selectedEdgeControllerProvider(_cv));
          ref.watch(canvasTransformControllerProvider(_cv));
          ref.watch(canvasLaneDirectionProvider(_cv));
          ctx = context;
          wref = ref;
          return const SizedBox.shrink();
        },
      ),
    ),
    overrides: <Override>[
      nodeRepositoryProvider.overrideWith((ref) async => nodes),
      edgeRepositoryProvider.overrideWith((ref) async => edges),
      styleLaneRepositoryProvider.overrideWith((ref) async => lanes),
      unitOfWorkProvider.overrideWith(
        (ref) async => FakeUnitOfWork(FakeRepositoryScope(nodes: nodes, edges: edges, styleLanes: lanes)),
      ),
      canvasLaneDirectionProvider(_cv).overrideWith((_) async => LaneDirection.horizontal),
      toastServiceProvider.overrideWithValue(toasts),
      jobQueueServiceProvider.overrideWith((ref) async => queue),
      loggerProvider.overrideWithValue(RecordingLogger()),
    ],
  );
  await tester.pumpAndSettle();
  env = _Env(ProviderScope.containerOf(ctx), ctx, wref)
    ..nodes = nodes
    ..edges = edges
    ..lanes = lanes
    ..toasts = toasts
    ..queue = queue
    ..ink = ink
    ..cyber = cyber
    ..n1 = n1
    ..n2 = n2
    ..x = x
    ..eInner = eInner
    ..eIn = eIn;
  expect(env.laneIds, <String>[ink, cyber], reason: '前置：两条道都载好了');
  return env;
}

/// 跑一个动作：不直接 await（中途可能弹框），推帧直到稳定再收尾。
Future<void> _run(WidgetTester tester, Future<void> action) async {
  await tester.pumpAndSettle();
  await action;
  await tester.pumpAndSettle();
}

void _seedJob(_Env env, JobState job) => env.c.read(jobsRegistryProvider.notifier).upsert(job);

void main() {
  group('dissolveLaneWithUndo', () {
    testWidgets('解散：无对话框，出撤销卡「Lane “Ink” dissolved」，历史栈 undo 为空', (WidgetTester tester) async {
      final _Env env = await _pump(tester);

      await _run(
        tester,
        dissolveLaneWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink)),
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect(env.toasts.titles, <String>['Lane “Ink” dissolved']);
      expect(env.toasts.kinds, <ToastKind>[ToastKind.undo]);
      expect(env.toasts.shown.single.primary?.label, 'Undo');
      expect(env.c.read(canvasHistoryControllerProvider(_cv)).undo, isEmpty, reason: '解散不进撤销栈');
      expect(env.laneIds, <String>[env.cyber]);
      expect(env.laneDeleted(env.ink), isTrue);
      expect(env.nodes.rows[env.n1]!['lane_id'], isNull);
      expect(env.nodes.rows[env.n2]!['lane_id'], isNull);
    });

    testWidgets('点卡上撤销 ⇒ restoreDissolved 被调、道回来、节点回到道里', (WidgetTester tester) async {
      final _Env env = await _pump(tester);
      await _run(
        tester,
        dissolveLaneWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink)),
      );

      env.toasts.shown.last.primary!.onPressed();
      await tester.pumpAndSettle();

      expect(env.laneIds, <String>[env.ink, env.cyber]);
      expect(env.laneDeleted(env.ink), isFalse);
      expect(env.nodes.rows[env.n1]!['lane_id'], env.ink);
      expect(env.nodes.rows[env.n1]!['position_y'], 120);
      expect(env.toasts.kinds, <ToastKind>[ToastKind.undo], reason: '撤销成功不再出卡');
    });

    testWidgets('解散折叠中的道：不报错，解散后从折叠集合里移除', (WidgetTester tester) async {
      final _Env env = await _pump(tester);
      env.c.read(laneCollapseProvider(_cv).notifier).toggle(env.ink);
      await tester.pump();

      await _run(
        tester,
        dissolveLaneWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink)),
      );

      expect(env.c.read(laneCollapseProvider(_cv)), isNot(contains(env.ink)));
      expect(env.toasts.titles, <String>['Lane “Ink” dissolved']);
    });
  });

  group('deleteLaneWithContentsWithUndo', () {
    testWidgets('无活动任务：不弹框，直接删 + 卡「Lane “Ink” and 2 nodes deleted」', (WidgetTester tester) async {
      final _Env env = await _pump(tester);
      // 终态任务不触发确认。
      _seedJob(
        env,
        JobState.succeeded(
            jobId: 'j-done', providerId: 'p', canvasId: _cv, sourceNodeId: env.n1, artifactPath: 'a.png'),
      );

      await _run(
        tester,
        deleteLaneWithContentsWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink)),
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect(env.toasts.titles, <String>['Lane “Ink” and 2 nodes deleted']);
      expect(env.toasts.kinds, <ToastKind>[ToastKind.undo]);
      expect(env.laneDeleted(env.ink), isTrue);
      expect(env.nodeDeleted(env.n1), isTrue);
      expect(env.nodeDeleted(env.n2), isTrue);
      expect(env.nodeDeleted(env.x), isFalse);
      expect(env.queue.cancelled, isEmpty);
      expect(env.c.read(canvasHistoryControllerProvider(_cv)).undo, isEmpty, reason: '不进撤销栈');
    });

    testWidgets('空道：卡「Lane “Cyber” deleted」', (WidgetTester tester) async {
      final _Env env = await _pump(tester);

      await _run(
        tester,
        deleteLaneWithContentsWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.cyber)),
      );

      expect(env.toasts.titles, <String>['Lane “Cyber” deleted']);
      expect(env.laneIds, <String>[env.ink]);
    });

    testWidgets('有 running 任务：弹框；点取消 ⇒ 无写入、无 cancel', (WidgetTester tester) async {
      final _Env env = await _pump(tester);
      _seedJob(env, JobState.running(jobId: 'j1', providerId: 'p', canvasId: _cv, sourceNodeId: env.n1));

      final Future<void> action =
          deleteLaneWithContentsWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Delete lane “Ink” and its nodes?'), findsOneWidget);
      expect(find.textContaining('1 job in this lane'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await _run(tester, action);

      expect(find.byType(AlertDialog), findsNothing);
      expect(env.queue.cancelled, isEmpty);
      expect(env.laneDeleted(env.ink), isFalse);
      expect(env.nodeDeleted(env.n1), isFalse);
      expect(env.laneIds, <String>[env.ink, env.cyber]);
      expect(env.toasts.shown, isEmpty);
    });

    testWidgets('点确认 ⇒ 道内活动任务逐个 cancel、然后删；别的画布的任务不动', (WidgetTester tester) async {
      final List<bool> laneGoneAtCancel = <bool>[];
      final _Env env = await _pump(tester, onCancel: (_Env e) => laneGoneAtCancel.add(e.laneDeleted(e.ink)));
      _seedJob(env, JobState.running(jobId: 'j1', providerId: 'p', canvasId: _cv, sourceNodeId: env.n1));
      _seedJob(env, JobState.queued(jobId: 'j2', providerId: 'p', canvasId: _cv, resultNodeId: env.n2));
      _seedJob(env, JobState.running(jobId: 'j-other', providerId: 'p', canvasId: 'c2', sourceNodeId: env.n1));

      final Future<void> action =
          deleteLaneWithContentsWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 jobs in this lane'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete and cancel jobs'));
      await _run(tester, action);

      expect(env.queue.cancelled, <String>['j1', 'j2']);
      expect(laneGoneAtCancel, <bool>[false, false], reason: '先取消任务、再删');
      expect(env.laneDeleted(env.ink), isTrue);
      expect(env.nodeDeleted(env.n1), isTrue);
      expect(env.toasts.titles, <String>['Lane “Ink” and 2 nodes deleted']);
    });

    testWidgets('删除后选中集去掉被删节点、选中的边被删了就清', (WidgetTester tester) async {
      final _Env env = await _pump(tester);
      env.c.read(canvasSelectionControllerProvider(_cv).notifier).replace(<String>[env.n1, env.x]);
      env.c.read(selectedEdgeControllerProvider(_cv).notifier).select(env.eIn);
      await tester.pump();

      await _run(
        tester,
        deleteLaneWithContentsWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink)),
      );

      expect(env.c.read(canvasSelectionControllerProvider(_cv)), <String>{env.x});
      expect(env.c.read(selectedEdgeControllerProvider(_cv)), isNull);
      expect(env.edges.rows[env.eIn]!['deleted_at'], isNotNull);
    });

    testWidgets('删除后点撤销 ⇒ 道、节点、边全部复原', (WidgetTester tester) async {
      final _Env env = await _pump(tester);
      await _run(
        tester,
        deleteLaneWithContentsWithUndo(env.ctx, env.ref, canvasId: _cv, lane: env.laneOf(env.ink)),
      );

      env.toasts.shown.last.primary!.onPressed();
      await tester.pumpAndSettle();

      expect(env.laneIds, <String>[env.ink, env.cyber]);
      expect(env.nodeDeleted(env.n1), isFalse);
      expect(env.nodeDeleted(env.n2), isFalse);
      expect(env.edges.rows[env.eInner]!['deleted_at'], isNull);
      expect(env.edges.rows[env.eIn]!['deleted_at'], isNull);
    });
  });
}
