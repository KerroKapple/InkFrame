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
    notifier.upsert(const JobState.queued(jobId: 'a', providerId: 'p', canvasId: 'cv-1'));
    notifier.upsert(const JobState.queued(jobId: 'b', providerId: 'p', canvasId: 'cv-1'));
    notifier.upsert(
      const JobState.running(jobId: 'a', providerId: 'p', canvasId: 'cv-1', progress: 0.3),
    );
    final state = container.read(jobsRegistryProvider);
    expect(state.map((e) => e.jobId).toList(), ['a', 'b']);
    expect(state[0], isA<JobRunning>());
  });

  test('remove 删除指定 jobId，不存在的 jobId 静默', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    notifier.upsert(const JobState.queued(jobId: 'a', providerId: 'p', canvasId: 'cv-1'));
    notifier.remove('does-not-exist');
    expect(container.read(jobsRegistryProvider).length, 1);
    notifier.remove('a');
    expect(container.read(jobsRegistryProvider), isEmpty);
  });

  test('clearTerminated 清掉所有终态条目', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    notifier.upsert(const JobState.running(jobId: 'a', providerId: 'p', canvasId: 'cv-1'));
    notifier.upsert(
      const JobState.succeeded(
        jobId: 'b',
        providerId: 'p',
        canvasId: 'cv-1',
        artifactPath: 'images/b.png',
      ),
    );
    notifier.upsert(
      const JobState.failed(
        jobId: 'c',
        providerId: 'p',
        canvasId: 'cv-1',
        error: UnknownError(cause: 'boom'),
      ),
    );
    notifier.upsert(const JobState.cancelled(jobId: 'd', providerId: 'p', canvasId: 'cv-1'));
    notifier.clearTerminated();
    final state = container.read(jobsRegistryProvider);
    expect(state.length, 1);
    expect(state.single.jobId, 'a');
  });

  test('upsert 相同状态跳过，不触发通知', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    var notifications = 0;
    container.listen(
      jobsRegistryProvider,
      (_, _) => notifications++,
      fireImmediately: false,
    );
    const job = JobState.running(
      jobId: 'a',
      providerId: 'p',
      canvasId: 'cv-1',
      progress: 0.5,
    );
    notifier.upsert(job);
    expect(notifications, 1);
    notifier.upsert(job); // 值相等 → 跳过
    expect(notifications, 1);
    notifier.upsert(const JobState.running(
      jobId: 'a',
      providerId: 'p',
      canvasId: 'cv-1',
      progress: 0.6,
    ));
    expect(notifications, 2);
  });

  test('终态条目超过上限时剔除最旧终态', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    for (var i = 0; i < kJobsRegistryMaxTerminal + 3; i++) {
      notifier.upsert(JobState.succeeded(
        jobId: 'job-$i',
        providerId: 'p',
        canvasId: 'cv-1',
        artifactPath: 'images/$i.png',
      ));
    }
    final state = container.read(jobsRegistryProvider);
    expect(state.length, kJobsRegistryMaxTerminal);
    // 最旧的 3 条被剔除，最新的保留
    expect(state.first.jobId, 'job-3');
    expect(state.last.jobId, 'job-${kJobsRegistryMaxTerminal + 2}');
  });

  test('活跃条目不受终态保留上限影响', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    notifier.upsert(const JobState.running(
      jobId: 'active-1',
      providerId: 'p',
      canvasId: 'cv-1',
    ));
    for (var i = 0; i < kJobsRegistryMaxTerminal + 5; i++) {
      notifier.upsert(JobState.cancelled(
        jobId: 'term-$i',
        providerId: 'p',
        canvasId: 'cv-1',
      ));
    }
    final state = container.read(jobsRegistryProvider);
    expect(state.where((e) => !e.isTerminal).single.jobId, 'active-1');
    expect(
      state.where((e) => e.isTerminal).length,
      kJobsRegistryMaxTerminal,
    );
  });

  test('活跃条目超过硬上限时剔除最旧活跃（卡死非终态 job 兜底）', () {
    final notifier = container.read(jobsRegistryProvider.notifier);
    for (var i = 0; i < kJobsRegistryMaxActive + 4; i++) {
      notifier.upsert(JobState.running(
        jobId: 'stuck-$i',
        providerId: 'p',
        canvasId: 'cv-1',
      ));
    }
    final state = container.read(jobsRegistryProvider);
    expect(state.length, kJobsRegistryMaxActive);
    // 最旧 4 条被剔除，最新保留
    expect(state.first.jobId, 'stuck-4');
    expect(state.last.jobId, 'stuck-${kJobsRegistryMaxActive + 3}');
  });

  test('activeForSourceNode 返回该节点的活跃 job；终态 / 他节点过滤', () {
    final reg = container.read(jobsRegistryProvider.notifier);
    reg.upsert(const JobState.running(
        jobId: 'a', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1', progress: 0.3));
    reg.upsert(const JobState.running(
        jobId: 'b', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n2', progress: 0.5));
    reg.upsert(const JobState.succeeded(
        jobId: 'c', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n3', artifactPath: 'x.png'));

    expect(reg.activeForSourceNode('n1')?.jobId, 'a');
    expect(reg.activeForSourceNode('n2')?.jobId, 'b');
    expect(reg.activeForSourceNode('n3'), isNull, reason: '终态不算活跃');
    expect(reg.activeForSourceNode('absent'), isNull);
  });

  test('activeForSourceNode 多个活跃取最近插入', () {
    final reg = container.read(jobsRegistryProvider.notifier);
    reg.upsert(const JobState.queued(
        jobId: 'old', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1'));
    reg.upsert(const JobState.running(
        jobId: 'new', providerId: 'p', canvasId: 'c1', sourceNodeId: 'n1', progress: 0.2));
    expect(reg.activeForSourceNode('n1')?.jobId, 'new');
  });

  test('forCanvas 只返回指定画布的活跃任务，按插入序', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final reg = container.read(jobsRegistryProvider.notifier);

    reg.upsert(const JobState.running(jobId: 'a', providerId: 'p', canvasId: 'c1', progress: 0.1));
    reg.upsert(const JobState.running(jobId: 'b', providerId: 'p', canvasId: 'c2', progress: 0.2));
    reg.upsert(const JobState.queued(jobId: 'd', providerId: 'p', canvasId: 'c1'));
    reg.upsert(const JobState.succeeded(jobId: 'e', providerId: 'p', canvasId: 'c1', artifactPath: 'x.png'));

    final c1Active = reg.forCanvas('c1');
    expect(c1Active.map((s) => s.jobId).toList(), <String>['a', 'd']); // 终态 e 被过滤
  });
}
