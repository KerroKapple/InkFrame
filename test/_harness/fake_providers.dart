// 行为脚本化的 Fake Provider 件。每个 fake 实现真接口（ISP 拆分后），
// 不允许用 dynamic / Object 偷懒——保证 ProviderRegistry 的 LSP 校验也能跑过。

import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';

// ─── Capabilities 工厂 ───────────────────────────────────────────────

/// 标准 image Provider capabilities。所有字段给安全默认，只暴露常改的入参。
ProviderCapabilities fakeImageCapabilities({
  String id = 'fake-image',
  ProviderRegion region = ProviderRegion.global,
  int qps = 2,
  int burst = 5,
  int maxConcurrentJobs = 1,
  bool supportsPolling = false,
  bool supportsCancellation = false,
  CostModel costModel = const CostModel.perCall(usdPerCall: 0.01),
}) {
  return ProviderCapabilities(
    providerId: id,
    region: region,
    modes: const <GenerationMode>[GenerationMode.textToImage],
    supportedRatios: const <AspectRatio>[AspectRatio.r1x1],
    supportedResolutions: const <Resolution>[Resolution.p1080],
    supportedDurations: const <int>[],
    supportedCameras: const <CameraMovement>[],
    maxBatchSize: 1,
    maxRefImages: 0,
    refImagesIncludeKeyframes: false,
    supportsFirstFrame: false,
    supportsLastFrame: false,
    supportsNegativePrompt: false,
    supportsSeed: false,
    supportsSound: false,
    supportsBatch: false,
    supportsCancellation: supportsCancellation,
    supportsPolling: supportsPolling,
    costModel: costModel,
    maxConcurrentJobs: maxConcurrentJobs,
    qps: qps,
    burst: burst,
  );
}

/// 标准 video Provider capabilities：T2V + 720p + 5s。
ProviderCapabilities fakeVideoCapabilities({
  String id = 'fake-video',
  ProviderRegion region = ProviderRegion.global,
  int qps = 2,
  int burst = 5,
  int maxConcurrentJobs = 1,
  bool supportsPolling = true,
  bool supportsCancellation = false,
}) {
  return ProviderCapabilities(
    providerId: id,
    region: region,
    modes: const <GenerationMode>[GenerationMode.textToVideo],
    supportedRatios: const <AspectRatio>[AspectRatio.r16x9],
    supportedResolutions: const <Resolution>[Resolution.p720],
    supportedDurations: const <int>[5],
    supportedCameras: const <CameraMovement>[],
    maxBatchSize: 1,
    maxRefImages: 0,
    refImagesIncludeKeyframes: false,
    supportsFirstFrame: false,
    supportsLastFrame: false,
    supportsNegativePrompt: false,
    supportsSeed: false,
    supportsSound: false,
    supportsBatch: false,
    supportsCancellation: supportsCancellation,
    supportsPolling: supportsPolling,
    costModel: const CostModel.perCall(usdPerCall: 0.05),
    maxConcurrentJobs: maxConcurrentJobs,
    qps: qps,
    burst: burst,
    pollInterval: const Duration(seconds: 1),
    pollTimeout: const Duration(minutes: 5),
  );
}

// ─── Fake 实现 ────────────────────────────────────────────────────────

/// 行为脚本化的 Submittable。
///
/// 默认实现：返回 `local://fake-job-<count>`，可用 [onSubmit] 覆盖。
/// 记录每次 submit 的 task，便于断言。
class FakeSubmittable implements Submittable {
  FakeSubmittable({
    ProviderCapabilities? capabilities,
    this.onSubmit,
  }) : capabilities = capabilities ?? fakeImageCapabilities();

  @override
  final ProviderCapabilities capabilities;

  /// 自定义 submit 行为；null 走默认。
  final Future<JobId> Function(GenerationTask task)? onSubmit;

  int submitCallCount = 0;
  final List<GenerationTask> submittedTasks = <GenerationTask>[];

  @override
  Future<JobId> submit(GenerationTask task) async {
    submitCallCount += 1;
    submittedTasks.add(task);
    if (onSubmit != null) return await onSubmit!(task);
    return 'local://fake-job-$submitCallCount';
  }
}

/// 行为脚本化的 Pollable：默认按 [statuses] 顺序消费，超长则一直返回最后一个。
class FakePollable implements Pollable {
  FakePollable({
    List<JobStatus>? statuses,
    this.onPoll,
  }) : _statuses = List<JobStatus>.of(statuses ?? <JobStatus>[
              const JobStatus.inProgress(progress: 0.5),
              const JobStatus.success(remoteUrls: <String>['https://x/y.png']),
            ]);

  final List<JobStatus> _statuses;
  final Future<JobStatus> Function(JobId id)? onPoll;

  int pollCallCount = 0;
  final List<JobId> polledIds = <JobId>[];

  @override
  Future<JobStatus> poll(JobId id) async {
    pollCallCount += 1;
    polledIds.add(id);
    if (onPoll != null) return await onPoll!(id);
    final int idx =
        pollCallCount - 1 < _statuses.length ? pollCallCount - 1 : _statuses.length - 1;
    return _statuses[idx];
  }
}

/// 行为脚本化的 KeyValidatable。默认所有 key 视为有效。
class FakeKeyValidatable implements KeyValidatable {
  FakeKeyValidatable({this.onValidate});

  /// 给定 key → 返回结果。null 走默认（valid）。
  final Future<KeyValidationResult> Function(String key)? onValidate;

  int validateCallCount = 0;
  final List<String> validatedKeys = <String>[];

  @override
  Future<KeyValidationResult> validateApiKey(String key) async {
    validateCallCount += 1;
    validatedKeys.add(key);
    if (onValidate != null) return await onValidate!(key);
    return const KeyValidationResult.valid();
  }
}

/// 三接口组合的全功能 Fake——覆盖大多数 ProviderRegistry / Controller 测试。
class FakeProvider implements Submittable, Pollable, KeyValidatable {
  FakeProvider({
    ProviderCapabilities? capabilities,
    Future<JobId> Function(GenerationTask)? onSubmit,
    List<JobStatus>? statuses,
    Future<JobStatus> Function(JobId)? onPoll,
    Future<KeyValidationResult> Function(String)? onValidate,
  })  : _submittable = FakeSubmittable(
          capabilities: capabilities,
          onSubmit: onSubmit,
        ),
        _pollable = FakePollable(statuses: statuses, onPoll: onPoll),
        _validator = FakeKeyValidatable(onValidate: onValidate);

  final FakeSubmittable _submittable;
  final FakePollable _pollable;
  final FakeKeyValidatable _validator;

  @override
  ProviderCapabilities get capabilities => _submittable.capabilities;

  @override
  Future<JobId> submit(GenerationTask task) => _submittable.submit(task);

  @override
  Future<JobStatus> poll(JobId id) => _pollable.poll(id);

  @override
  Future<KeyValidationResult> validateApiKey(String key) =>
      _validator.validateApiKey(key);

  // 透传断言钩子
  int get submitCallCount => _submittable.submitCallCount;
  List<GenerationTask> get submittedTasks => _submittable.submittedTasks;
  int get pollCallCount => _pollable.pollCallCount;
  List<JobId> get polledIds => _pollable.polledIds;
  int get validateCallCount => _validator.validateCallCount;
  List<String> get validatedKeys => _validator.validatedKeys;
}
