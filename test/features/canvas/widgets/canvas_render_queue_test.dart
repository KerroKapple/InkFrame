// CanvasRenderQueue（Workspace v2 稿的底部表格）：本画布 job 逐行渲染、取消、清除已完成、
// 失败行带本地化错误 tooltip。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/current_canvas_id.dart';
import 'package:inkframe/features/canvas/widgets/canvas_render_queue.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';

class _SeedableJobsRegistry extends JobsRegistry {
  _SeedableJobsRegistry(this._seed);
  final List<JobState> _seed;

  @override
  List<JobState> build() => List<JobState>.unmodifiable(_seed);
}

class _NodesController extends CanvasNodesController {
  _NodesController(this._nodes);
  final List<CanvasNode> _nodes;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => _nodes;
}

/// 只捕获 cancel(jobId) 调用的假 JobQueueService。
class _CapturingQueue implements JobQueueService {
  String? cancelledJobId;

  @override
  Future<void> init() async {}

  @override
  Future<JobHandle> submit(GenerationTask task) async =>
      throw UnimplementedError();

  @override
  Future<void> cancel(String jobId) async => cancelledJobId = jobId;

  @override
  void dispose() {}
}

Widget _host(
  List<JobState> jobs,
  String canvasId, {
  List<CanvasNode> nodes = const <CanvasNode>[],
  List<Override> extra = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => canvasId),
      jobsRegistryProvider.overrideWith(() => _SeedableJobsRegistry(jobs)),
      canvasNodesControllerProvider.overrideWith(() => _NodesController(nodes)),
      ...extra,
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CanvasRenderQueue()),
    ),
  );
}

void main() {
  testWidgets('只显示当前画布的 job；表头三列在场（耗时列无后端字段，已去）', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.running(jobId: 'a', providerId: 'p1', canvasId: 'c1', progress: 0.45),
        JobState.running(jobId: 'b', providerId: 'p2', canvasId: 'c2', progress: 0.9),
      ],
      'c1',
    ));
    await tester.pump();
    for (final String h in <String>['Task', 'Type', 'Progress', 'Model']) {
      expect(find.text(h), findsOneWidget);
    }
    // 无源节点 ⇒ 任务列回退 provider 名（无 displayName 时就是 id），模型列也是 id ⇒ 两处。
    expect(find.text('p1'), findsNWidgets(2));
    expect(find.text('p2'), findsNothing, reason: 'c2 的 job 不出现');
    expect(find.text('Rendering'), findsOneWidget);
  });

  testWidgets('任务列 = 源节点显示名与类型；无源节点时回退 provider displayName', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.queued(jobId: 'j1', providerId: 'gemini-image', canvasId: 'c1', sourceNodeId: 'n1'),
        JobState.queued(jobId: 'j2', providerId: 'gemini-image', canvasId: 'c1'),
      ],
      'c1',
      nodes: const <CanvasNode>[
        CanvasNode(id: 'n1', label: 'Harbor Docks', type: CanvasNodeType.image, canvasId: 'c1'),
      ],
    ));
    await tester.pump();
    expect(find.text('Harbor Docks'), findsOneWidget);
    expect(find.text('image'), findsOneWidget);
    expect(find.text('Gemini Image'), findsOneWidget);
    expect(find.text('j1'), findsNothing, reason: '不暴露 jobId');
    expect(find.text('Queued'), findsNWidgets(2));
  });

  testWidgets('无 job → 空态文案；标签角标不出', (tester) async {
    await tester.pumpWidget(_host(const <JobState>[], 'c1'));
    await tester.pump();
    expect(find.text('No active renders'), findsOneWidget);
  });

  testWidgets('点击「取消」调用 jobQueueService.cancel(jobId)', (tester) async {
    final queue = _CapturingQueue();
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.running(jobId: 'job-x', providerId: 'gemini-image', canvasId: 'c1', progress: 0.5),
      ],
      'c1',
      extra: <Override>[jobQueueServiceProvider.overrideWith((ref) async => queue)],
    ));
    await tester.pump();

    expect(find.byTooltip('Cancel job'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel job'));
    await tester.pump();

    expect(queue.cancelledJobId, 'job-x');
  });

  testWidgets('取消只对可取消的 job 出现；终态行照常列出但无取消', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.queued(jobId: 'q', providerId: 'p', canvasId: 'c1'),
        JobState.succeeded(jobId: 's', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
      ],
      'c1',
      extra: <Override>[jobQueueServiceProvider.overrideWith((ref) async => _CapturingQueue())],
    ));
    await tester.pump();
    expect(find.byTooltip('Cancel job'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
  });

  testWidgets('失败行：状态「Failed」+ tooltip 带本地化错误（走 l10nError）', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.failed(
          jobId: 'f',
          providerId: 'gemini-image',
          canvasId: 'c1',
          error: NetworkError(code: InkErrorCode.networkTimeout),
        ),
      ],
      'c1',
    ));
    await tester.pump();

    expect(find.text('Failed'), findsOneWidget);
    expect(find.byTooltip('Network timed out. Please retry.'), findsOneWidget);
    expect(find.byTooltip('Cancel job'), findsNothing);
  });

  testWidgets('已取消 job 状态「Cancelled」，不是失败', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.cancelled(jobId: 'c', providerId: 'gemini-image', canvasId: 'c1'),
      ],
      'c1',
    ));
    await tester.pump();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Failed'), findsNothing);
  });

  testWidgets('跨画布隔离：c2 的失败不出现在 c1', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.failed(
          jobId: 'f2',
          providerId: 'gemini-image',
          canvasId: 'c2',
          error: NetworkError(code: InkErrorCode.networkTimeout),
        ),
      ],
      'c1',
    ));
    await tester.pump();
    expect(find.text('Failed'), findsNothing);
    expect(find.text('No active renders'), findsOneWidget);
  });

  testWidgets('有终态 job 时出「Clear finished」，点击后清掉终态、保留活跃', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.running(jobId: 'r', providerId: 'p', canvasId: 'c1', progress: 0.2),
        JobState.succeeded(jobId: 's', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
      ],
      'c1',
    ));
    await tester.pump();
    expect(find.byKey(CanvasRenderQueue.clearDoneKey), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byKey(CanvasRenderQueue.clearDoneKey));
    await tester.pump();

    expect(find.text('Done'), findsNothing);
    expect(find.text('Rendering'), findsOneWidget);
    expect(find.byKey(CanvasRenderQueue.clearDoneKey), findsNothing);
  });
}
