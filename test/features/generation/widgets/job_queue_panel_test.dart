// JobQueuePanel 三态 widget 测试：空 / 有任务 / 失败。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';
import 'package:inkframe/features/generation/widgets/job_queue_panel.dart';
import 'package:inkframe/l10n/generated/app_localizations.dart';
import 'package:inkframe/theme/app_theme.dart';

class _NoopQueue implements JobQueueService {
  String? cancelled;
  @override
  Future<void> init() async {}
  @override
  Future<JobHandle> submit(GenerationTask task) async =>
      throw UnimplementedError();
  @override
  Future<void> cancel(String jobId) async => cancelled = jobId;
  @override
  void dispose() {}
}

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: JobQueuePanel()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('empty state shows placeholder', (tester) async {
    await _pump(tester, [
      jobQueueServiceProvider.overrideWithValue(_NoopQueue()),
    ]);
    expect(find.text('No active jobs'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('active job shows progress bar + cancel button', (tester) async {
    final queue = _NoopQueue();
    await _pump(tester, [
      jobQueueServiceProvider.overrideWithValue(queue),
    ]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(JobQueuePanel)),
    );
    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.running(
            jobId: 'job-1',
            providerId: 'gemini-image',
            progress: 0.4,
          ),
        );
    await tester.pump();

    expect(find.text('gemini-image'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel job'), findsOneWidget);
    expect(find.textContaining('40%'), findsOneWidget);

    await tester.tap(find.text('Cancel job'));
    await tester.pump();
    expect(queue.cancelled, 'job-1');
  });

  testWidgets('failed job shows error message + retry when retryable',
      (tester) async {
    String? retried;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobQueueServiceProvider.overrideWithValue(_NoopQueue()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(variant: InkThemeVariant.dark, textScale: 1),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: JobQueuePanel(onRetry: (id) => retried = id),
          ),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(JobQueuePanel)),
    );
    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.failed(
            jobId: 'job-2',
            providerId: 'wanx-image',
            error: NetworkError(code: InkErrorCode.networkTimeout),
          ),
        );
    await tester.pump();

    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Network timed out. Please retry.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, 'job-2');
  });

  testWidgets('non-retryable failure hides retry button', (tester) async {
    await _pump(tester, [
      jobQueueServiceProvider.overrideWithValue(_NoopQueue()),
    ]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(JobQueuePanel)),
    );
    container.read(jobsRegistryProvider.notifier).upsert(
          const JobState.failed(
            jobId: 'job-3',
            providerId: 'gemini-image',
            error: ProviderError(code: InkErrorCode.invalidKey),
          ),
        );
    await tester.pump();
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Dismiss'), findsOneWidget);
  });
}
