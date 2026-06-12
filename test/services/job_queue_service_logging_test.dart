// JobQueueService 日志注入点测试（FIX-016 / ME-21）：
// 吞错与失败路径必须经由注入的 LoggerService 落日志。
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/job_queue_service.dart';

import '../helpers/recording_logger.dart';

class _FakeProvider
    implements Submittable, Pollable, Cancellable, KeyValidatable {
  _FakeProvider({
    this.submitError,
    this.cancelError,
    this.pollSequence = const <JobStatus>[],
  });

  final InkError? submitError;
  final InkError? cancelError;
  final List<JobStatus> pollSequence;
  int pollCalls = 0;

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
        providerId: 'fake',
        region: ProviderRegion.global,
        modes: [GenerationMode.textToImage],
        supportedRatios: [AspectRatio.r1x1],
        supportedResolutions: [Resolution.p1080],
        supportedDurations: [],
        supportedCameras: [],
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
        costModel: CostModel.perCall(usdPerCall: 0.01),
        maxConcurrentJobs: 2,
        qps: 10,
        burst: 10,
      );

  @override
  Future<JobId> submit(GenerationTask task) async {
    if (submitError != null) throw submitError!;
    return 'fake-${task.jobId}';
  }

  @override
  Future<JobStatus> poll(JobId id) async {
    // 取消场景下挂起，让 cancel 有时间介入。
    if (pollSequence.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const JobStatus.inProgress(progress: 0.1);
    }
    final idx = (pollCalls).clamp(0, pollSequence.length - 1);
    pollCalls++;
    return pollSequence[idx];
  }

  @override
  Future<void> cancel(JobId id) async {
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<KeyValidationResult> validateApiKey(String key) async =>
      const KeyValidationResult.valid();
}

GenerationTask _task(String jobId) => GenerationTask(
      providerId: 'fake',
      jobId: jobId,
      mode: GenerationMode.textToImage,
      prompt: 'p',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

InMemoryJobQueueService _build(_FakeProvider provider, RecordingLogger log) =>
    InMemoryJobQueueService(
      registry: ProviderRegistry({'fake': () => provider}),
      logger: log,
      pollInitialInterval: const Duration(milliseconds: 1),
      pollMaxInterval: const Duration(milliseconds: 5),
      pollBackoffMultiplier: 1.0,
      pollTimeout: const Duration(seconds: 2),
    );

void main() {
  test('submit 抛 InkError → 失败路径写 ERROR 日志（module=jobqueue）', () async {
    final log = RecordingLogger();
    final queue = _build(
      _FakeProvider(
        submitError:
            const ProviderError(code: InkErrorCode.providerServer),
      ),
      log,
    );
    final handle = await queue.submit(_task('j-fail'));
    await handle.done;

    final errors = log.byLevel(InkLogLevel.error);
    expect(errors, isNotEmpty);
    expect(errors.first.module, 'jobqueue');
    expect(errors.first.extra?['job_id'], 'j-fail');
    expect(errors.first.extra?['error_code'],
        InkErrorCode.providerServer.wire);
    queue.dispose();
  });

  test('cancel 时 provider.cancel 抛 InkError 被吞 → 写 WARN 日志', () async {
    final log = RecordingLogger();
    final queue = _build(
      _FakeProvider(
        cancelError:
            const ProviderError(code: InkErrorCode.providerServer),
      ),
      log,
    );
    final handle = await queue.submit(_task('j-cancel'));
    // 等 submit 完成进入轮询。
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await queue.cancel('j-cancel');
    await handle.done;

    final warns = log.byLevel(InkLogLevel.warn);
    expect(warns.where((r) => r.module == 'jobqueue'), isNotEmpty);
    queue.dispose();
  });

  test('成功路径 → submit 记录排队日志', () async {
    final log = RecordingLogger();
    final queue = _build(
      _FakeProvider(pollSequence: const [JobStatus.success(remoteUrls: [])]),
      log,
    );
    final handle = await queue.submit(_task('j-ok'));
    await handle.done;

    expect(
      log.records.where(
        (r) => r.module == 'jobqueue' && r.extra?['job_id'] == 'j-ok',
      ),
      isNotEmpty,
    );
    expect(log.byLevel(InkLogLevel.error), isEmpty);
    queue.dispose();
  });
}
