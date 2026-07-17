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

  testWidgets('当前画布无任务无失败 → 自动收起为细栏', (tester) async {
    await tester.pumpWidget(_host(const [], 'c1'));
    await tester.pump();
    // 收起态：不渲染面板内容，只留展开入口。
    expect(find.text('No active renders'), findsNothing);
    expect(find.byTooltip('Expand render queue'), findsOneWidget);
  });

  testWidgets('收起态点展开 → 面板出现；点收起 → 回细栏（手动覆盖）', (tester) async {
    await tester.pumpWidget(_host(const [], 'c1'));
    await tester.pump();

    await tester.tap(find.byTooltip('Expand render queue'));
    await tester.pumpAndSettle();
    expect(find.text('No active renders'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse render queue'));
    await tester.pumpAndSettle();
    expect(find.text('No active renders'), findsNothing);
    expect(find.byTooltip('Expand render queue'), findsOneWidget);
  });

  testWidgets('有活跃任务 → 自动展开', (tester) async {
    await tester.pumpWidget(_host(const [
      JobState.running(jobId: 'a', providerId: 'p', canvasId: 'c1', progress: 0.45),
    ], 'c1'));
    await tester.pump();
    expect(find.textContaining('45'), findsOneWidget);
    expect(find.byTooltip('Collapse render queue'), findsOneWidget);
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

  testWidgets('已取消任务不进入最近失败区（cancelled ≠ failure）', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.cancelled(jobId: 'c', providerId: 'gemini-image', canvasId: 'c1'),
      ],
      'c1',
    ));
    await tester.pump();
    // cancelled 是终态但非 JobFailed → 无失败区、无活跃 → 自动收起。
    expect(find.text('RECENT FAILURES'), findsNothing);
    expect(find.byTooltip('Expand render queue'), findsOneWidget);
  });

  testWidgets('跨画布失败隔离：c2 的失败不出现在 c1 的最近失败区', (tester) async {
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
    // 当前画布 c1 无任何任务 → 无最近失败区，自动收起。
    expect(find.text('RECENT FAILURES'), findsNothing);
    expect(find.text('Network timed out. Please retry.'), findsNothing);
    expect(find.byTooltip('Expand render queue'), findsOneWidget);
  });

  testWidgets('最近失败区最多展示最近 3 条（sublist(len-3) 边界）', (tester) async {
    await tester.pumpWidget(_host(
      const <JobState>[
        JobState.failed(jobId: 'f1', providerId: 'p', canvasId: 'c1', error: NetworkError(code: InkErrorCode.networkTimeout)),
        JobState.failed(jobId: 'f2', providerId: 'p', canvasId: 'c1', error: NetworkError(code: InkErrorCode.networkOffline)),
        JobState.failed(jobId: 'f3', providerId: 'p', canvasId: 'c1', error: ProviderError(code: InkErrorCode.invalidKey)),
        JobState.failed(jobId: 'f4', providerId: 'p', canvasId: 'c1', error: DownloadError()),
      ],
      'c1',
    ));
    await tester.pump();

    expect(find.text('RECENT FAILURES'), findsOneWidget);
    // 4 条失败按插入序取最新 3 条（f2/f3/f4）；最旧的 f1 被截掉。
    expect(find.text('Network timed out. Please retry.'), findsNothing); // f1 (最旧) 被截
    expect(find.text("Couldn't reach the provider. Check your network connection, then retry."), findsOneWidget); // f2
    expect(find.text('API key was rejected by the provider. Update it in Settings → API Keys.'), findsOneWidget); // f3
    expect(find.text("The generated file couldn't be downloaded. Check your connection and retry."), findsOneWidget); // f4
  });
}
