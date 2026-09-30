// batchJobProgressProvider：jobId → 该 job 当前进度。
//
// 这条 family 是对比浮层「生成中 N%」进度条的唯一数据源，此前零测试：
// 注册表里同时有多条 job 时「取到的是不是本 job」完全没人钉，把
// `if (job.jobId == jobId)` 写成恒真（或恒 null）全套测试照样绿。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/generation/models/job_state.dart';
import 'package:inkframe/features/generation/providers/batch_job_progress.dart';
import 'package:inkframe/features/generation/providers/jobs_registry.dart';

/// 固定列表的注册表桩：build() 直接给定 job 列表，不经 upsert。
class _StubRegistry extends JobsRegistry {
  _StubRegistry(this.jobs);

  final List<JobState> jobs;

  @override
  List<JobState> build() => jobs;
}

ProviderContainer _containerWith(List<JobState> jobs) {
  final c = ProviderContainer(
    overrides: <Override>[
      jobsRegistryProvider.overrideWith(() => _StubRegistry(jobs)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('batchJobProgressProvider', () {
    test('两条不同 jobId 时各取各的进度——不串台', () {
      final c = _containerWith(const <JobState>[
        JobState.running(
          jobId: 'j1',
          providerId: 'p',
          canvasId: 'cv',
          progress: 0.4,
        ),
        JobState.running(
          jobId: 'j2',
          providerId: 'p',
          canvasId: 'cv',
          progress: 0.9,
        ),
      ]);

      // 关键断言：first/last 取值或恒定回退都会在这里翻车。
      expect(c.read(batchJobProgressProvider('j1')), 0.4);
      expect(c.read(batchJobProgressProvider('j2')), 0.9);
    });

    test('注册表里没有这条 job → null（不是 0）', () {
      final c = _containerWith(const <JobState>[
        JobState.running(
          jobId: 'j1',
          providerId: 'p',
          canvasId: 'cv',
          progress: 0.4,
        ),
      ]);

      // 0 会让浮层画一条 0% 的进度条；null 才是「这条 job 已不在内存里」——
      // 进程重启后读库的历史 slot 走的就是这一支，浮层据此只写「生成中」。
      expect(c.read(batchJobProgressProvider('nope')), isNull);
    });

    test('空注册表 → null', () {
      final c = _containerWith(const <JobState>[]);
      expect(c.read(batchJobProgressProvider('j1')), isNull);
    });

    test('非 running 态走 progressValue 哨兵：queued=0 / succeeded=1', () {
      final c = _containerWith(const <JobState>[
        JobState.queued(jobId: 'jq', providerId: 'p', canvasId: 'cv'),
        JobState.succeeded(
          jobId: 'js',
          providerId: 'p',
          canvasId: 'cv',
          artifactPath: 'images/a.png',
        ),
      ]);

      expect(c.read(batchJobProgressProvider('jq')), 0.0);
      expect(c.read(batchJobProgressProvider('js')), 1.0);
    });

    test('真实注册表 upsert 后能读到新值', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(batchJobProgressProvider('j1')), isNull);

      c.read(jobsRegistryProvider.notifier).upsert(
        const JobState.running(
          jobId: 'j1',
          providerId: 'p',
          canvasId: 'cv',
          progress: 0.25,
        ),
      );

      expect(c.read(batchJobProgressProvider('j1')), 0.25);
    });
  });
}
