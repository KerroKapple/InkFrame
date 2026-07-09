import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
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
  List<Override> extra = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      currentCanvasIdProvider.overrideWith((ref) => canvasId),
      jobsRegistryProvider.overrideWith(() => _SeedableJobsRegistry(jobs)),
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
  testWidgets('只显示当前画布的活跃任务，无假数据', (tester) async {
    await tester.pumpWidget(_host([
      const JobState.running(jobId: 'a', providerId: 'p', canvasId: 'c1', progress: 0.45),
      const JobState.running(jobId: 'b', providerId: 'p', canvasId: 'c2', progress: 0.9),
      const JobState.succeeded(jobId: 'd', providerId: 'p', canvasId: 'c1', artifactPath: 'x'),
    ], 'c1'));
    await tester.pump();
    expect(find.text('Watch Closeup'), findsNothing);
    expect(find.text('Harbor Docks'), findsNothing);
    expect(find.textContaining('45'), findsOneWidget);
    expect(find.textContaining('90'), findsNothing);
  });

  testWidgets('任务行标题显示 provider displayName 而非 jobId(UUID)', (tester) async {
    await tester.pumpWidget(_host([
      const JobState.running(
        jobId: 'a1b2c3d4-uuid',
        providerId: 'gemini-image',
        canvasId: 'c1',
        progress: 0.3,
      ),
    ], 'c1'));
    await tester.pump();
    // FIX-013 x FIX-010：行标题取 displayName（未声明时回退 providerId）。
    expect(find.text('Gemini Image'), findsOneWidget);
    expect(find.text('a1b2c3d4-uuid'), findsNothing);
  });

  testWidgets('当前画布无活跃任务 → 空态', (tester) async {
    await tester.pumpWidget(_host(const [], 'c1'));
    await tester.pump();
    expect(find.text('No active renders'), findsOneWidget);
  });

  testWidgets('点击取消控件调用 jobQueueService.cancel(jobId)', (tester) async {
    final queue = _CapturingQueue();
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.running(
          jobId: 'job-x',
          providerId: 'gemini-image',
          canvasId: 'c1',
          progress: 0.5,
        ),
      ],
      'c1',
      extra: <Override>[
        jobQueueServiceProvider.overrideWith((ref) async => queue),
      ],
    ));
    await tester.pump();

    expect(find.byTooltip('Cancel job'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel job'));
    await tester.pump();

    expect(queue.cancelledJobId, 'job-x');
  });

  testWidgets('取消控件对 queued 显示、对终态任务不显示', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.queued(jobId: 'q', providerId: 'p', canvasId: 'c1'),
        JobState.succeeded(
          jobId: 's',
          providerId: 'p',
          canvasId: 'c1',
          artifactPath: 'x',
        ),
      ],
      'c1',
      extra: <Override>[
        jobQueueServiceProvider.overrideWith((ref) async => _CapturingQueue()),
      ],
    ));
    await tester.pump();
    // queued 行有取消；succeeded 终态被 active 过滤掉 → 只剩一个取消控件。
    expect(find.byTooltip('Cancel job'), findsOneWidget);
  });

  testWidgets('失败任务在最近失败区渲染本地化错误文案（走 l10nError）', (tester) async {
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

    expect(find.text('RECENT FAILURES'), findsOneWidget);
    // l10nError(networkTimeout) 的英文文案。
    expect(find.text('Network timed out. Please retry.'), findsOneWidget);
    // 失败任务不进入活跃列表 → 无取消控件。
    expect(find.byTooltip('Cancel job'), findsNothing);
  });
}
