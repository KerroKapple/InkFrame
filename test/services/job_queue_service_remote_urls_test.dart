// JobQueueService._persistRemoteUrls 集成测试：
//   - JobSuccess.remoteUrls 非空 → 调 VideoDownloadService.download 一次
//   - task.mode == textToVideo → patchTypeConfig 带 'video_url'
//   - task.mode == textToImage → patchTypeConfig 带 'image_url'
//
// 复用 job_queue_service_test.dart 的核心 fakes（FakeJobRepository /
// FakeNodeRepository）；此处 inline 精简版，避免跨文件 import 私有类型。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/thumbnail_service.dart';
import 'package:inkframe/core/interfaces/video_download_service.dart';
import 'package:inkframe/core/models/cost_model.dart';
import 'package:inkframe/core/models/generation_task.dart';
import 'package:inkframe/core/models/job_status.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/models/key_validation_result.dart';
import 'package:inkframe/core/models/provider_capabilities.dart';
import 'package:inkframe/core/paths/app_paths.dart';
import 'package:inkframe/providers/provider_registry.dart';
import 'package:inkframe/services/file_resolver_service.dart';
import 'package:inkframe/services/job_queue_service.dart';

// ---------- fakes 精简版 -----------------------------------------------

class _FakeProvider implements Submittable, Pollable, KeyValidatable {
  _FakeProvider({
    required this.providerId,
    required this.pollSequence,
  }) : _capabilities = ProviderCapabilities(
          providerId: providerId,
          region: ProviderRegion.global,
          modes: const [GenerationMode.textToVideo, GenerationMode.textToImage],
          supportedRatios: const [AspectRatio.r1x1],
          supportedResolutions: const [Resolution.p1080],
          supportedDurations: const [5],
          supportedCameras: const [CameraMovement.static_],
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
          costModel: const CostModel.perCall(usdPerCall: 0.1),
          maxConcurrentJobs: 1,
          qps: 1,
          burst: 1,
        );
  final String providerId;
  final List<JobStatus> pollSequence;
  final ProviderCapabilities _capabilities;
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

  @override
  Future<KeyValidationResult> validateApiKey(String key) async =>
      const KeyValidationResult.valid();
}

class _FakeJobRepo implements JobRepository {
  final Map<String, Map<String, Object?>> rows = {};
  void seedPending(String id) {
    rows[id] = {'id': id, 'status': 'pending'};
  }

  @override
  Future<int> transitionStatus({
    required String id,
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final row = rows[id];
    if (row == null) return 0;
    final cur = row['status'] as String?;
    if (cur == null || !fromStatuses.contains(cur)) return 0;
    row['status'] = toStatus;
    row.addAll(extra);
    return 1;
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    rows[id]?.addAll(patch);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> s) async => [];
  @override
  Future<Map<String, Object?>?> findById(String id) async => rows[id];
  @override
  Future<String> create({
    required String canvasId,
    required String sourceNodeId,
    String? resultNodeId,
    required String providerId,
    required String jobType,
    required String fullPrompt,
    required String userPrompt,
    Map<String, Object?> parameters = const <String, Object?>{},
    int batchSize = 1,
    int maxRetries = 3,
    DateTime? timeoutAt,
  }) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String c, {int limit = 200}) =>
      throw UnimplementedError();
  @override
  Future<int> purgeExpired({required Duration retention}) =>
      throw UnimplementedError();
  @override
  Future<int> purgePerCanvasCap({required int cap}) =>
      throw UnimplementedError();
  @override
  Future<int> bulkTransition({
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async =>
      0;
  @override
  Future<int> hardDelete(String id) => throw UnimplementedError();
}

class _FakeNodeRepo implements NodeRepository {
  final Map<String, List<Map<String, Object?>>> patches = {};

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    patches.putIfAbsent(id, () => []).add(Map<String, Object?>.from(patch));
    return 1;
  }

  @override
  Future<String> create({
    required String canvasId,
    required String type,
    required String nodeRole,
    String label = '',
    String? sourceNodeId,
    String? laneId,
    double positionX = 0,
    double positionY = 0,
    double width = 240,
    double height = 240,
    int zIndex = 0,
    Map<String, Object?> typeConfig = const <String, Object?>{},
  }) =>
      throw UnimplementedError();
  @override
  Future<Map<String, Object?>?> findById(String id) => throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> listByCanvas(String canvasId) =>
      throw UnimplementedError();
  @override
  Future<List<Map<String, Object?>>> listOrphanResults(String canvasId) =>
      throw UnimplementedError();
  @override
  Future<int> update(String id, Map<String, Object?> patch) =>
      throw UnimplementedError();
  @override
  Future<int> softDelete(String id) => throw UnimplementedError();
  @override
  Future<int> restore(String id) => throw UnimplementedError();
  @override
  Future<int> hardDelete(String id) => throw UnimplementedError();
}

class _RecordingDownloader implements VideoDownloadService {
  final List<({String url, String destination})> calls = [];

  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    calls.add((url: url, destination: destination.path));
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(const [1, 2, 3], flush: true);
    return destination;
  }
}

InMemoryJobQueueService _build({
  required ProviderRegistry registry,
  required _FakeJobRepo repo,
  required _FakeNodeRepo nodeRepo,
  required FileResolverService fileResolver,
  required VideoDownloadService? downloader,
  ThumbnailService? thumbnail,
}) =>
    InMemoryJobQueueService(
      registry: registry,
      repo: repo,
      nodeRepo: nodeRepo,
      fileResolver: fileResolver,
      videoDownloader: downloader,
      thumbnailService: thumbnail,
      globalConcurrency: 2,
      pollInitialInterval: const Duration(milliseconds: 1),
      pollMaxInterval: const Duration(milliseconds: 5),
      pollBackoffMultiplier: 1.0,
      pollTimeout: const Duration(seconds: 2),
    );

GenerationTask _task({
  required String jobId,
  required GenerationMode mode,
  String providerId = 'fake',
  String projectId = 'proj-1',
  String canvasId = 'canvas-1',
  String resultNodeId = 'node-1',
}) =>
    GenerationTask(
      providerId: providerId,
      jobId: jobId,
      projectId: projectId,
      canvasId: canvasId,
      resultNodeId: resultNodeId,
      mode: mode,
      prompt: 'x',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
    );

void main() {
  group('InMemoryJobQueueService._persistRemoteUrls', () {
    late Directory tmp;
    late FileResolverService fileResolver;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ink_jq_remote_');
      fileResolver = DefaultFileResolverService(DefaultAppPaths.forRoot(tmp));
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('video 模式：downloader 被调用 1 次 + patchTypeConfig 含 video_url',
        () async {
      final provider = _FakeProvider(
        providerId: 'fake',
        pollSequence: const [
          JobStatus.success(remoteUrls: ['https://fake/v.mp4']),
        ],
      );
      final registry = CachingProviderRegistry({'fake': () => provider});
      final repo = _FakeJobRepo()..seedPending('jv');
      final nodeRepo = _FakeNodeRepo();
      final downloader = _RecordingDownloader();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        downloader: downloader,
      );

      final h = await svc.submit(
        _task(jobId: 'jv', mode: GenerationMode.textToVideo),
      );
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(downloader.calls, hasLength(1));
      expect(downloader.calls.single.url, 'https://fake/v.mp4');
      expect(nodeRepo.patches['node-1'], isNotNull);
      final patch = nodeRepo.patches['node-1']!.first;
      expect(patch.keys, contains('video_url'));
      expect(patch['video_url'], 'videos/jv.mp4');
      expect(patch.keys, isNot(contains('image_url')));

      // 物理文件落盘到 canvasRoot/videos/jv.mp4
      final videoFile = File(
        '${tmp.path}/projects/proj-1/canvases/canvas-1/videos/jv.mp4',
      );
      expect(videoFile.existsSync(), isTrue);
      svc.dispose();
    });

    test('image 模式：downloader 被调用 1 次 + patchTypeConfig 含 image_url',
        () async {
      final provider = _FakeProvider(
        providerId: 'fake',
        pollSequence: const [
          JobStatus.success(remoteUrls: ['https://fake/i.png']),
        ],
      );
      final registry = CachingProviderRegistry({'fake': () => provider});
      final repo = _FakeJobRepo()..seedPending('ji');
      final nodeRepo = _FakeNodeRepo();
      final downloader = _RecordingDownloader();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        downloader: downloader,
      );

      final h = await svc.submit(
        _task(jobId: 'ji', mode: GenerationMode.textToImage),
      );
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(downloader.calls, hasLength(1));
      final patch = nodeRepo.patches['node-1']!.first;
      expect(patch.keys, contains('image_url'));
      expect(patch['image_url'], 'images/ji.png');
      expect(patch.keys, isNot(contains('video_url')));
      svc.dispose();
    });

    test('downloader 抛 VideoDownloadError → JobFailure(downloadFailed)',
        () async {
      final provider = _FakeProvider(
        providerId: 'fake',
        pollSequence: const [
          JobStatus.success(remoteUrls: ['https://fake/404.mp4']),
        ],
      );
      final registry = CachingProviderRegistry({'fake': () => provider});
      final repo = _FakeJobRepo()..seedPending('jerr');
      final nodeRepo = _FakeNodeRepo();
      final failing = _FailingDownloader();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        downloader: failing,
      );

      final h = await svc.submit(
        _task(jobId: 'jerr', mode: GenerationMode.textToVideo),
      );
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      // ME-05：产物下载失败属 DownloadError（可重试），不是 provider 5xx
      expect((terminal as JobFailure).error, isA<DownloadError>());
      expect(terminal.error.code, InkErrorCode.downloadFailed);
      expect(repo.rows['jerr']!['status'], 'error');
      expect(repo.rows['jerr']!['error_code'], 'download_failed');
      svc.dispose();
    });

    // ME-34：thumbnail 路径补测（成功补 thumbnail_url / 失败不阻断 success）
    test('video 模式 + thumbnailService：patch 含 thumbnail_url 且缩略图落盘',
        () async {
      final provider = _FakeProvider(
        providerId: 'fake',
        pollSequence: const [
          JobStatus.success(remoteUrls: ['https://fake/v.mp4']),
        ],
      );
      final registry = CachingProviderRegistry({'fake': () => provider});
      final repo = _FakeJobRepo()..seedPending('jt');
      final nodeRepo = _FakeNodeRepo();
      final thumbnail = _RecordingThumbnail();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        downloader: _RecordingDownloader(),
        thumbnail: thumbnail,
      );

      final h = await svc.submit(
        _task(jobId: 'jt', mode: GenerationMode.textToVideo),
      );
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(thumbnail.calls, 1);
      final patch = nodeRepo.patches['node-1']!.first;
      expect(patch['video_url'], 'videos/jt.mp4');
      expect(patch['thumbnail_url'], 'videos/jt.jpg');
      final thumbFile = File(
        '${tmp.path}/projects/proj-1/canvases/canvas-1/videos/jt.jpg',
      );
      expect(thumbFile.existsSync(), isTrue);
      svc.dispose();
    });

    test('thumbnail 抽帧失败 → 任务仍 success，patch 无 thumbnail_url', () async {
      final provider = _FakeProvider(
        providerId: 'fake',
        pollSequence: const [
          JobStatus.success(remoteUrls: ['https://fake/v.mp4']),
        ],
      );
      final registry = CachingProviderRegistry({'fake': () => provider});
      final repo = _FakeJobRepo()..seedPending('jtf');
      final nodeRepo = _FakeNodeRepo();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        downloader: _RecordingDownloader(),
        thumbnail: _FailingThumbnail(),
      );

      final h = await svc.submit(
        _task(jobId: 'jtf', mode: GenerationMode.textToVideo),
      );
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(repo.rows['jtf']!['status'], 'success');
      final patch = nodeRepo.patches['node-1']!.first;
      expect(patch['video_url'], 'videos/jtf.mp4');
      expect(patch.keys, isNot(contains('thumbnail_url')));
      svc.dispose();
    });

    test('远程产物：resultNodeId 为空(生产缺 ID) → job 失败而非静默成功', () async {
      final provider = _FakeProvider(
        providerId: 'fake',
        pollSequence: const [
          JobStatus.success(remoteUrls: ['https://fake/out.png']),
        ],
      );
      final registry = CachingProviderRegistry({'fake': () => provider});
      final repo = _FakeJobRepo()..seedPending('jmiss');
      final nodeRepo = _FakeNodeRepo();
      final downloader = _RecordingDownloader();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        downloader: downloader,
      );

      // 依赖齐全，但 resultNodeId 缺失（生产缺 ID 故障）→ 必须失败。
      final h = await svc.submit(
        const GenerationTask(
          providerId: 'fake',
          jobId: 'jmiss',
          projectId: 'proj-1',
          canvasId: 'canvas-1',
          resultNodeId: null,
          mode: GenerationMode.textToImage,
          prompt: 'x',
          resolution: Resolution.p1080,
          aspectRatio: AspectRatio.r1x1,
        ),
      );
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      // 产物未被静默丢弃当成功：节点无任何 patch、downloader 未被调用。
      expect(nodeRepo.patches, isEmpty);
      expect(downloader.calls, isEmpty);
      svc.dispose();
    });
  });
}

class _RecordingThumbnail implements ThumbnailService {
  int calls = 0;

  @override
  Future<File> extractFirstFrame({
    required String videoPath,
    required File destination,
  }) async {
    calls++;
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(const [0xFF, 0xD8], flush: true); // JPEG sig
    return destination;
  }
}

class _FailingThumbnail implements ThumbnailService {
  @override
  Future<File> extractFirstFrame({
    required String videoPath,
    required File destination,
  }) async {
    throw const ThumbnailError('decode_failed');
  }
}

class _FailingDownloader implements VideoDownloadService {
  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    throw const VideoDownloadError(url: 'x', httpStatus: 404);
  }
}
