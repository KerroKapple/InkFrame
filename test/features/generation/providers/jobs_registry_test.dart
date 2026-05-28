// JobsRegistry：upsert / remove / clearTerminated 单测。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('upsert 追加新 job，重复 jobId 原位更新', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    notifier.upsert(const JobState.queued(jobId: 'a', providerId: 'p'));
    notifier.upsert(const JobState.queued(jobId: 'b', providerId: 'p'));
    notifier.upsert(
      const JobState.running(jobId: 'a', providerId: 'p', progress: 0.3),
    );
    final state = container.read(jobsRegistryProvider);
    expect(state.map((e) => e.jobId).toList(), ['a', 'b']);
    expect(state[0], isA<JobRunning>());
  });

  test('remove 删除指定 jobId，不存在的 jobId 静默', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    notifier.upsert(const JobState.queued(jobId: 'a', providerId: 'p'));
    notifier.remove('does-not-exist');
    expect(container.read(jobsRegistryProvider).length, 1);
    notifier.remove('a');
    expect(container.read(jobsRegistryProvider), isEmpty);
  });

  test('clearTerminated 清掉所有终态条目', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    notifier.upsert(const JobState.running(jobId: 'a', providerId: 'p'));
    notifier.upsert(
      const JobState.succeeded(
        jobId: 'b',
        providerId: 'p',
        artifactPath: 'images/b.png',
      ),
    );
    notifier.upsert(
      const JobState.failed(
        jobId: 'c',
        providerId: 'p',
        error: UnknownError(cause: 'boom'),
      ),
    );
    notifier.upsert(const JobState.cancelled(jobId: 'd', providerId: 'p'));
    notifier.clearTerminated();
    final state = container.read(jobsRegistryProvider);
    expect(state.length, 1);
    expect(state.single.jobId, 'a');
  });
}
