// 不变量：成功路径必须先 patchTypeConfig(url) 落库，再 emit/complete success。
// 用 Completer 卡住写库，断言期间不出现 success；放开后才出现。
// 等待用条件信号而非固定 pumpEventQueue：reachedGate 标志服务已推进到落盘调用点，
// handle.done 标志 persist 之后的确定性终态，二者均无墙钟/泵次数依赖。
//
// 使用 inlineBytes 成功路径（最简单且直接调用 patchTypeConfig 的路径）：
//   _persistInlineBytes → file.writeAsBytes → nodeRepo.patchTypeConfig → return null
//   → _persistTransition(to:'success') → handle._emit(status) + handle._complete(status)
// 文件写入需要真实磁盘（dart:io），指向系统 temp 目录。

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:inkframe/services/job_queue_service.dart';

// ---- _GatedNodeRepo --------------------------------------------------------
// patchTypeConfig 在 gate 放开前一直挂起，记录调用；其余方法 noSuchMethod 抛错。

class _GatedNodeRepo implements NodeRepository {
  final gate = Completer<void>();
  final reachedGate = Completer<void>(); // 服务推进到落盘调用点、即将被 gate 卡住
  bool urlWritten = false;

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    if (!reachedGate.isCompleted) reachedGate.complete();
    await gate.future; // 卡住直到测试放开
    if (patch.containsKey('image_url') || patch.containsKey('video_url')) {
      urlWritten = true;
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

// ---- FakeProvider（复制自 job_queue_service_test.dart 的最小版本）-----------

class _FakeProvider implements Submittable, Pollable {
  _FakeProvider({
    required String providerId,
    required this.pollSequence,
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
          supportsCancellation: false,
          supportsPolling: true,
          costModel: const CostModel.perCall(usdPerCall: 0.01),
          maxConcurrentJobs: 2,
          qps: 10,
          burst: 10,
        );

  final ProviderCapabilities _capabilities;
  final List<JobStatus> pollSequence;
  int _pollCalls = 0;

  @override
  ProviderCapabilities get capabilities => _capabilities;

  @override
  Future<JobId> submit(GenerationTask task) async => 'fake-${task.jobId}';

  @override
  Future<JobStatus> poll(JobId id) async {
    final idx = _pollCalls.clamp(0, pollSequence.length - 1);
    _pollCalls++;
    return pollSequence[idx];
  }
}

// ---- 辅助构建 ---------------------------------------------------------------

InMemoryJobQueueService _build(
  ProviderRegistry registry, {
  NodeRepository? nodeRepo,
  FileResolverService? fileResolver,
}) {
  return InMemoryJobQueueService(
    registry: registry,
    nodeRepo: nodeRepo,
    fileResolver: fileResolver,
    pollInitialInterval: const Duration(milliseconds: 1),
    pollMaxInterval: const Duration(milliseconds: 5),
    pollBackoffMultiplier: 1.0,
    pollTimeout: const Duration(seconds: 10),
  );
}

GenerationTask _sinkTask({
  String jobId = 'jw',
  String projectId = 'proj-1',
  String canvasId = 'canvas-1',
  String resultNodeId = 'node-1',
}) =>
    GenerationTask(
      providerId: 'fake',
      jobId: jobId,
      projectId: projectId,
      canvasId: canvasId,
      resultNodeId: resultNodeId,
      mode: GenerationMode.textToImage,
      prompt: 'order test',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

// ---- 测试 -------------------------------------------------------------------

void main() {
  late Directory tmp;
  late FileResolverService fileResolver;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ink_jq_order_');
    final paths = DefaultAppPaths.forRoot(tmp);
    fileResolver = DefaultFileResolverService(paths);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('success 仅在 image_url 落库后才 emit（patchTypeConfig before emit 不变量）',
      () async {
    final bytes = Uint8List.fromList(const [0x89, 0x50, 0x4e, 0x47]); // PNG sig
    final fake = _FakeProvider(
      providerId: 'fake',
      pollSequence: [
        JobStatus.success(remoteUrls: const [], inlineBytes: [bytes]),
      ],
    );
    final nodeRepo = _GatedNodeRepo();
    final svc = _build(
      ProviderRegistry({'fake': () => fake}),
      nodeRepo: nodeRepo,
      fileResolver: fileResolver,
    );

    final handle = await svc.submit(_sinkTask());

    bool sawSuccess = false;
    handle.status.listen((s) {
      if (s is JobSuccess) sawSuccess = true;
    });

    // 条件等待：服务推进到 patchTypeConfig 调用点并被 gate 卡住时确定性触发，
    // 替代固定 pumpEventQueue（依赖真实 poll Timer + 磁盘写耗时，CPU 抢占下漂移）。
    await nodeRepo.reachedGate.future.timeout(const Duration(seconds: 10));

    expect(nodeRepo.urlWritten, isFalse,
        reason: 'patchTypeConfig 应被 gate 卡住，尚未写入 url');
    expect(sawSuccess, isFalse,
        reason: '关键不变量：image_url 未落库前不得 emit success');

    // 放开 gate → patchTypeConfig 继续执行 → _persistTransition → emit/complete success
    nodeRepo.gate.complete();
    // handle.done 在 _complete 完成、紧随 _emit，是 persist 之后才发生的确定性终态信号，无墙钟依赖。
    final terminal = await handle.done.timeout(const Duration(seconds: 10));

    expect(nodeRepo.urlWritten, isTrue,
        reason: 'gate 放开后 patchTypeConfig 应已写入 url');
    expect(terminal, isA<JobSuccess>(),
        reason: '落库完成后应进入 success 终态（emit 在 persist 之后）');

    svc.dispose();
  });
}
