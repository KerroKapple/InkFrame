// JobQueueService 内存实现单元测试：FakeProvider 覆盖核心路径。

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/job_queue_service.dart';

/// FakeProvider：可配置 submit/poll/cancel 行为，用于精确控制场景。
class FakeProvider implements Submittable, Pollable, Cancellable, KeyValidatable {
  FakeProvider({
    required String providerId,
    int maxConcurrentJobs = 2,
    this.submitDelay = Duration.zero,
    this.submitError,
    this.pollSequence = const [],
    this.pollDelay = Duration.zero,
    this.pollError,
    this.cancelHandler,
  }) : _capabilities = ProviderCapabilities(
          providerId: providerId,
          region: ProviderRegion.global,
          modes: const [GenerationMode.textToImage],
          supportedRatios: const [AspectRatio.r1x1],
          supportedResolutions: const [Resolution.p1080],
          supportedDurations: const [],
          supportedCameras: const [],
          maxBatchSize: 1,
          maxRefImages: 0,
          refImagesIncludeKeyframes: false,
          supportsFirstFrame: false,
          supportsLastFrame: false,
          supportsNegativePrompt: false,
          supportsSeed: false,
          supportsSound: false,
          supportsBatch: false,
          supportsCancellation: true,
          supportsPolling: true,
          costModel: const CostModel.perCall(usdPerCall: 0.01),
          maxConcurrentJobs: maxConcurrentJobs,
          qps: 10,
          burst: 10,
        );

  final ProviderCapabilities _capabilities;
  final Duration submitDelay;
  final InkError? submitError;
  final List<JobStatus> pollSequence;
  final Duration pollDelay;
  final InkError? pollError;
  final Future<void> Function(String)? cancelHandler;

  int submitCalls = 0;
  int pollCalls = 0;
  int cancelCalls = 0;
  int currentRunning = 0;
  int peakRunning = 0;

  @override
  ProviderCapabilities get capabilities => _capabilities;

  @override
  Future<JobId> submit(GenerationTask task) async {
    submitCalls++;
    currentRunning++;
    peakRunning = peakRunning > currentRunning ? peakRunning : currentRunning;
    if (submitDelay > Duration.zero) {
      await Future<void>.delayed(submitDelay);
    }
    if (submitError != null) {
      currentRunning--;
      throw submitError!;
    }
    return 'fake-${task.jobId}';
  }

  @override
  Future<JobStatus> poll(JobId id) async {
    pollCalls++;
    if (pollDelay > Duration.zero) {
      await Future<void>.delayed(pollDelay);
    }
    if (pollError != null) {
      currentRunning--;
      throw pollError!;
    }
    if (pollSequence.isEmpty) {
      throw StateError('FakeProvider: pollSequence empty (configure it)');
    }
    final idx = (pollCalls - 1).clamp(0, pollSequence.length - 1);
    final s = pollSequence[idx];
    if (s is JobSuccess || s is JobFailure) {
      currentRunning--;
    }
    return s;
  }

  @override
  Future<void> cancel(JobId id) async {
    cancelCalls++;
    if (cancelHandler != null) {
      await cancelHandler!(id);
    }
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async =>
      const KeyValidationResult.valid();
}

GenerationTask _task(String jobId, String providerId) => GenerationTask(
      providerId: providerId,
      jobId: jobId,
      mode: GenerationMode.textToImage,
      prompt: 'a fake prompt',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

ProviderRegistry _registryOf(Map<String, FakeProvider> providers) {
  return ProviderRegistry({
    for (final entry in providers.entries) entry.key: () => entry.value,
  });
}

InMemoryJobQueueService _build(
  ProviderRegistry registry, {
  int globalConcurrency = 4,
}) {
  return InMemoryJobQueueService(
    registry: registry,
    globalConcurrency: globalConcurrency,
    pollInitialInterval: const Duration(milliseconds: 1),
    pollMaxInterval: const Duration(milliseconds: 5),
    pollBackoffMultiplier: 1.0,
    pollTimeout: const Duration(seconds: 2),
  );
}

void main() {
  group('InMemoryJobQueueService.submit', () {
    test('单任务 submit→poll→success 路径', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        pollSequence: [
          const JobStatus.success(remoteUrls: ['file://x.png']),
        ],
      );
      final svc = _build(_registryOf({'fake': fake}));
      final h = await svc.submit(_task('j1', 'fake'));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect((terminal as JobSuccess).remoteUrls, ['file://x.png']);
      expect(fake.submitCalls, 1);
      expect(fake.pollCalls, 1);
      svc.dispose();
    });

    test('Provider.submit 抛 InkError → JobStatus.failure', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        submitError: const ProviderError(code: InkErrorCode.invalidKey),
      );
      final svc = _build(_registryOf({'fake': fake}));
      final h = await svc.submit(_task('j1', 'fake'));
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      expect((terminal as JobFailure).error.code, InkErrorCode.invalidKey);
      svc.dispose();
    });

    test('inProgress 两次后 success', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        // 加 delay 给 listener 注册时间，避免 broadcast stream 丢前几条
        submitDelay: const Duration(milliseconds: 5),
        pollSequence: [
          const JobStatus.inProgress(progress: 0.3),
          const JobStatus.inProgress(progress: 0.7),
          const JobStatus.success(remoteUrls: ['done']),
        ],
      );
      final svc = _build(_registryOf({'fake': fake}));
      final h = await svc.submit(_task('j1', 'fake'));
      final emitted = <JobStatus>[];
      h.status.listen(emitted.add);
      await h.done;

      expect(fake.pollCalls, 3);
      expect(emitted.whereType<JobInProgress>(), hasLength(2));
      expect(emitted.last, isA<JobSuccess>());
      svc.dispose();
    });

    test('全局并发 = 1：第二个任务必须排队', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        submitDelay: const Duration(milliseconds: 30),
        pollSequence: [
          const JobStatus.success(remoteUrls: ['ok']),
        ],
      );
      final svc = _build(_registryOf({'fake': fake}), globalConcurrency: 1);
      final h1 = await svc.submit(_task('j1', 'fake'));
      final h2 = await svc.submit(_task('j2', 'fake'));
      await Future.wait([h1.done, h2.done]);

      // 两个任务都成功，但 submit 是串行（peak running = 1）
      expect(fake.peakRunning, 1);
      expect(fake.submitCalls, 2);
      svc.dispose();
    });

    test('per-provider 并发上限：fake A 限 1，fake B 限 1，并行不串扰', () async {
      final fakeA = FakeProvider(
        providerId: 'a',
        maxConcurrentJobs: 1,
        submitDelay: const Duration(milliseconds: 20),
        pollSequence: [const JobStatus.success(remoteUrls: ['a1'])],
      );
      final fakeB = FakeProvider(
        providerId: 'b',
        maxConcurrentJobs: 1,
        submitDelay: const Duration(milliseconds: 20),
        pollSequence: [const JobStatus.success(remoteUrls: ['b1'])],
      );
      final svc = _build(
        _registryOf({'a': fakeA, 'b': fakeB}),
        globalConcurrency: 4,
      );
      final ha = await svc.submit(_task('ja', 'a'));
      final hb = await svc.submit(_task('jb', 'b'));
      await Future.wait([ha.done, hb.done]);

      // 不同 provider 可以并行
      expect(fakeA.peakRunning, 1);
      expect(fakeB.peakRunning, 1);
      svc.dispose();
    });

    test('同 jobId 重复 submit → StateError', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        submitDelay: const Duration(milliseconds: 50),
        pollSequence: [const JobStatus.success(remoteUrls: [])],
      );
      final svc = _build(_registryOf({'fake': fake}));
      await svc.submit(_task('dup', 'fake'));
      await expectLater(
        svc.submit(_task('dup', 'fake')),
        throwsA(isA<StateError>()),
      );
      svc.dispose();
    });
  });

  group('InMemoryJobQueueService.cancel', () {
    test('pending 任务 cancel → JobStatus.failure(cancelledByUser)', () async {
      final fakeBlocker = FakeProvider(
        providerId: 'block',
        maxConcurrentJobs: 1,
        submitDelay: const Duration(milliseconds: 200),
        pollSequence: [const JobStatus.success(remoteUrls: [])],
      );
      final svc = _build(
        _registryOf({'block': fakeBlocker}),
        globalConcurrency: 1,
      );
      final h1 = await svc.submit(_task('j1', 'block'));
      final h2 = await svc.submit(_task('j2', 'block')); // 卡在 pending
      await svc.cancel('j2');
      final t2 = await h2.done;

      expect(t2, isA<JobFailure>());
      expect((t2 as JobFailure).error.code, InkErrorCode.cancelledByUser);
      // 第一个继续跑完
      final t1 = await h1.done;
      expect(t1, isA<JobSuccess>());
      svc.dispose();
    });

    test('running 任务 cancel → 调 Provider.cancel + 任务结束', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        pollDelay: const Duration(milliseconds: 100), // 拖住 polling
        pollSequence: [
          const JobStatus.inProgress(progress: 0.1),
          const JobStatus.inProgress(progress: 0.5),
          const JobStatus.success(remoteUrls: ['late']),
        ],
      );
      final svc = _build(_registryOf({'fake': fake}));
      final h = await svc.submit(_task('j1', 'fake'));
      // 让它进 polling 第一帧
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await svc.cancel('j1');
      final terminal = await h.done;

      expect(fake.cancelCalls, 1);
      // 终态可能是 cancelledByUser 或正好赶上 success — 任一都接受
      expect(terminal is JobFailure || terminal is JobSuccess, isTrue);
      svc.dispose();
    });

    test('cancel 不存在的 jobId → no-op idempotent', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        pollSequence: [const JobStatus.success(remoteUrls: [])],
      );
      final svc = _build(_registryOf({'fake': fake}));
      await svc.cancel('nope'); // 不抛
      svc.dispose();
    });
  });

  group('InMemoryJobQueueService.dispose', () {
    test('dispose 后 submit 抛 StateError', () async {
      final fake = FakeProvider(
        providerId: 'fake',
        pollSequence: [const JobStatus.success(remoteUrls: [])],
      );
      final svc = _build(_registryOf({'fake': fake}));
      svc.dispose();
      await expectLater(
        svc.submit(_task('j1', 'fake')),
        throwsA(isA<StateError>()),
      );
    });

    test('dispose 时 pending 任务全部 fail', () async {
      final blocker = FakeProvider(
        providerId: 'block',
        maxConcurrentJobs: 1,
        submitDelay: const Duration(seconds: 5),
        pollSequence: [const JobStatus.success(remoteUrls: [])],
      );
      final svc = _build(
        _registryOf({'block': blocker}),
        globalConcurrency: 1,
      );
      await svc.submit(_task('j1', 'block'));
      final h2 = await svc.submit(_task('j2', 'block'));
      svc.dispose();
      final t2 = await h2.done;
      expect(t2, isA<JobFailure>());
    });
  });
}
