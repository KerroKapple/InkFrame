// JobQueueService 批量/变体生产侧（M2 P0）：
//   - batchSize>1 逐 URL 下载到 images/{jobId}-{i}.png，逐 slot 落终态
//   - 部分成功（≥1 张）→ job success，失败 slot 独立 error
//   - 全败 → job 失败
//   - URL 数 < batchSize → 缺失 slot 收敛 error
//   - 取消：已成功 slot 保留，generating slot → cancelled，job 对外 cancelled
//   - init() 孤儿回收：generating slot → cancelled(cancelled_on_exit)
//   - batchSize==1 主路径：不触碰 slot 表，命名仍 {jobId}.png

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/generation_provider.dart';
import 'package:inkframe/core/interfaces/job_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
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

import '../_harness/fake_batch_result.dart';

// ---------- fakes -------------------------------------------------------

class _FakeProvider implements Submittable, Pollable, KeyValidatable {
  _FakeProvider({
    required this.providerId,
    required this.pollSequence,
  }) : _capabilities = ProviderCapabilities(
          providerId: providerId,
          region: ProviderRegion.global,
          modes: const [GenerationMode.textToImage],
          supportedRatios: const [AspectRatio.r1x1],
          supportedResolutions: const [Resolution.p1080],
          supportedDurations: const [5],
          supportedCameras: const [CameraMovement.static_],
          maxBatchSize: 4,
          maxRefImages: 0,
          refImagesIncludeKeyframes: false,
          supportsFirstFrame: false,
          supportsLastFrame: false,
          supportsNegativePrompt: false,
          supportsSeed: false,
          supportsSound: false,
          supportsBatch: true,
          supportsCancellation: false,
          supportsPolling: true,
          costModel: const CostModel.perCall(usdPerCall: 0.1),
          maxConcurrentJobs: 2,
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
  void seed(String id, {String status = 'pending'}) {
    rows[id] = {'id': id, 'status': status};
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
  Future<int> bulkTransition({
    required List<String> fromStatuses,
    required String toStatus,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    var n = 0;
    for (final row in rows.values) {
      if (fromStatuses.contains(row['status'])) {
        row['status'] = toStatus;
        row.addAll(extra);
        n++;
      }
    }
    return n;
  }

  @override
  Future<int> update(String id, Map<String, Object?> patch) async {
    rows[id]?.addAll(patch);
    return 1;
  }

  @override
  Future<List<Map<String, Object?>>> listByStatus(List<String> s) async =>
      rows.values.where((r) => s.contains(r['status'])).toList();
  @override
  Future<Map<String, Object?>?> findById(String id) async => rows[id];
  @override
  Future<int> purgeExpired({required Duration retention}) async => 0;
  @override
  Future<int> purgePerCanvasCap({required int cap}) async => 0;
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
  Future<List<Map<String, Object?>>> listByCanvas(String c,
          {int limit = 200}) =>
      throw UnimplementedError();
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
  Future<Map<String, Object?>?> findById(String id) =>
      throw UnimplementedError();
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

/// URL 含 'bad' 时抛 404，其余落盘成功。
class _SelectiveDownloader implements VideoDownloadService {
  final List<String> succeeded = [];

  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    if (url.contains('bad')) {
      throw VideoDownloadError(url: url, httpStatus: 404);
    }
    succeeded.add(url);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(const [1, 2, 3], flush: true);
    return destination;
  }
}

/// 首张下载成功后触发 [afterFirst]（用于循环中 cancel），并统计调用次数。
class _CancelAfterFirstDownloader implements VideoDownloadService {
  Future<void> Function()? afterFirst;
  int calls = 0;

  @override
  Future<File> download({
    required String url,
    required File destination,
  }) async {
    calls++;
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(const [1, 2, 3], flush: true);
    if (calls == 1) {
      await afterFirst?.call();
    }
    return destination;
  }
}

// ---------- helpers -----------------------------------------------------

const _kNode = 'node-1';

InMemoryJobQueueService _build({
  required ProviderRegistry registry,
  required _FakeJobRepo repo,
  required _FakeNodeRepo nodeRepo,
  required FileResolverService fileResolver,
  required FakeBatchResultRepo batchRepo,
  VideoDownloadService? downloader,
}) =>
    InMemoryJobQueueService(
      registry: registry,
      repo: repo,
      nodeRepo: nodeRepo,
      fileResolver: fileResolver,
      batchResultRepo: batchRepo,
      videoDownloader: downloader,
      globalConcurrency: 2,
      pollInitialInterval: const Duration(milliseconds: 1),
      pollMaxInterval: const Duration(milliseconds: 5),
      pollBackoffMultiplier: 1.0,
      pollTimeout: const Duration(seconds: 5),
    );

GenerationTask _task({
  required String jobId,
  int batchSize = 3,
  String providerId = 'fake',
}) =>
    GenerationTask(
      providerId: providerId,
      jobId: jobId,
      projectId: 'proj-1',
      canvasId: 'canvas-1',
      resultNodeId: _kNode,
      mode: GenerationMode.textToImage,
      prompt: 'x',
      resolution: Resolution.p1080,
      aspectRatio: AspectRatio.r1x1,
      batchSize: batchSize,
    );

Future<void> _seedSlots(
  FakeBatchResultRepo repo,
  String jobId,
  int count, {
  String status = 'generating',
}) async {
  for (var i = 0; i < count; i++) {
    await repo.create(
      nodeId: _kNode,
      jobId: jobId,
      slotIndex: i,
      status: status,
    );
  }
}

Map<String, Object?> _slot(FakeBatchResultRepo repo, int index) =>
    repo.rows.values.firstWhere((r) => r['slot_index'] == index);

void main() {
  group('InMemoryJobQueueService 批量 slot 落库', () {
    late Directory tmp;
    late FileResolverService fileResolver;
    late _FakeJobRepo repo;
    late _FakeNodeRepo nodeRepo;
    late FakeBatchResultRepo batchRepo;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ink_jq_batch_');
      fileResolver = DefaultFileResolverService(DefaultAppPaths.forRoot(tmp));
      repo = _FakeJobRepo();
      nodeRepo = _FakeNodeRepo();
      batchRepo = FakeBatchResultRepo();
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('多 URL 全成功：逐 slot success + 命名 -i + 主图=首张 + job success', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: [
          'https://fake/0.png',
          'https://fake/1.png',
          'https://fake/2.png',
        ]),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jb1');
      await _seedSlots(batchRepo, 'jb1', 3);
      final downloader = _SelectiveDownloader();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: downloader,
      );
      final h = await svc.submit(_task(jobId: 'jb1'));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(repo.rows['jb1']!['status'], 'success');
      for (var i = 0; i < 3; i++) {
        final s = _slot(batchRepo, i);
        expect(s['status'], 'success', reason: 'slot $i');
        expect(s['output_url'], 'images/jb1-$i.png');
        expect(s['completed_at'], isNotNull);
        final f = File(
          '${tmp.path}/projects/proj-1/canvases/canvas-1/images/jb1-$i.png',
        );
        expect(f.existsSync(), isTrue, reason: 'file $i');
      }
      // 首张成功图作主图（维持现有主图渲染）。
      expect(nodeRepo.patches[_kNode]!.first['image_url'], 'images/jb1-0.png');
      svc.dispose();
    });

    test('部分失败：失败 slot 独立 error(download_failed)，job 仍 success', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: [
          'https://fake/0.png',
          'https://fake/bad.png',
          'https://fake/2.png',
        ]),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jb2');
      await _seedSlots(batchRepo, 'jb2', 3);

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jb2'));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(repo.rows['jb2']!['status'], 'success');
      expect(_slot(batchRepo, 0)['status'], 'success');
      expect(_slot(batchRepo, 1)['status'], 'error');
      expect(_slot(batchRepo, 1)['error_code'], 'download_failed');
      expect(_slot(batchRepo, 2)['status'], 'success');
      expect(nodeRepo.patches[_kNode]!.first['image_url'], 'images/jb2-0.png');
      svc.dispose();
    });

    test('全败 → job error + 全 slot error', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: [
          'https://fake/bad0.png',
          'https://fake/bad1.png',
          'https://fake/bad2.png',
        ]),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jb3');
      await _seedSlots(batchRepo, 'jb3', 3);

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jb3'));
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      expect((terminal as JobFailure).error, isA<DownloadError>());
      expect(repo.rows['jb3']!['status'], 'error');
      for (var i = 0; i < 3; i++) {
        expect(_slot(batchRepo, i)['status'], 'error', reason: 'slot $i');
        expect(_slot(batchRepo, i)['error_code'], 'download_failed');
      }
      expect(nodeRepo.patches, isEmpty, reason: '全败不 patch 主图');
      svc.dispose();
    });

    test('URL 数 < batchSize → 缺失 slot 收敛 error，job 仍 success', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: ['https://fake/0.png']),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jb4');
      await _seedSlots(batchRepo, 'jb4', 3);

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jb4'));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(_slot(batchRepo, 0)['status'], 'success');
      expect(_slot(batchRepo, 1)['status'], 'error');
      expect(_slot(batchRepo, 1)['error_code'], 'provider_invalid_response');
      expect(_slot(batchRepo, 2)['status'], 'error');
      svc.dispose();
    });

    test('取消：已成功 slot 保留，generating slot → cancelled，job 对外 cancelled',
        () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.inProgress(progress: 0.2),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jc1');
      // slot0 模拟先前已成功；slot1/2 仍 generating。
      await _seedSlots(batchRepo, 'jc1', 1, status: 'success');
      await batchRepo.create(
          nodeId: _kNode, jobId: 'jc1', slotIndex: 1, status: 'generating');
      await batchRepo.create(
          nodeId: _kNode, jobId: 'jc1', slotIndex: 2, status: 'generating');

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jc1'));
      await h.status.firstWhere((s) => s is JobInProgress);
      await svc.cancel('jc1');
      final terminal = await h.done;

      // 对外仍是 cancelled——不得因有成功 slot 补发 success。
      expect(terminal, isA<JobFailure>());
      expect((terminal as JobFailure).error, isA<CancelledError>());
      expect(repo.rows['jc1']!['status'], 'cancelled');
      expect(_slot(batchRepo, 0)['status'], 'success', reason: '已成功 slot 保留');
      expect(_slot(batchRepo, 1)['status'], 'cancelled');
      expect(_slot(batchRepo, 2)['status'], 'cancelled');
      svc.dispose();
    });

    test('init() 孤儿回收：generating slot → cancelled(cancelled_on_exit)，终态 slot 不动',
        () async {
      final registry = CachingProviderRegistry({
        'fake': () =>
            _FakeProvider(providerId: 'fake', pollSequence: const []),
      });
      repo.seed('jo1', status: 'polling');
      await _seedSlots(batchRepo, 'jo1', 1, status: 'success');
      await batchRepo.create(
          nodeId: _kNode, jobId: 'jo1', slotIndex: 1, status: 'generating');

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
      );
      await svc.init();

      expect(repo.rows['jo1']!['status'], 'cancelled');
      expect(_slot(batchRepo, 0)['status'], 'success');
      expect(_slot(batchRepo, 1)['status'], 'cancelled');
      expect(_slot(batchRepo, 1)['error_code'], 'cancelled_on_exit');
      svc.dispose();
    });

    test('batchSize==1 主路径不变：不触碰 slot 表 + 命名仍 {jobId}.png', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: ['https://fake/one.png']),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('j1');

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'j1', batchSize: 1));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(batchRepo.rows, isEmpty, reason: '单张不建/不写 slot 行');
      expect(nodeRepo.patches[_kNode]!.first['image_url'], 'images/j1.png');
      final f = File(
        '${tmp.path}/projects/proj-1/canvases/canvas-1/images/j1.png',
      );
      expect(f.existsSync(), isTrue);
      svc.dispose();
    });

    test('inlineBytes 批量：逐张写盘 + slot success + 主图=首张', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: [
        JobStatus.success(
          remoteUrls: const [],
          inlineBytes: [
            Uint8List.fromList(const [1]),
            Uint8List.fromList(const [2]),
          ],
        ),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jbi');
      await _seedSlots(batchRepo, 'jbi', 2);

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
      );
      final h = await svc.submit(_task(jobId: 'jbi', batchSize: 2));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      for (var i = 0; i < 2; i++) {
        expect(_slot(batchRepo, i)['status'], 'success');
        expect(_slot(batchRepo, i)['output_url'], 'images/jbi-$i.png');
        final f = File(
          '${tmp.path}/projects/proj-1/canvases/canvas-1/images/jbi-$i.png',
        );
        expect(f.existsSync(), isTrue, reason: 'file $i');
      }
      expect(nodeRepo.patches[_kNode]!.first['image_url'], 'images/jbi-0.png');
      svc.dispose();
    });

    test('provider 直接失败 → slot 收敛 error（错误码=provider 错误）', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.failure(
          error: ProviderError(code: InkErrorCode.providerServer),
        ),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jf1');
      await _seedSlots(batchRepo, 'jf1', 2);

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jf1', batchSize: 2));
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      expect(repo.rows['jf1']!['status'], 'error');
      for (var i = 0; i < 2; i++) {
        expect(_slot(batchRepo, i)['status'], 'error');
        expect(_slot(batchRepo, i)['error_code'], 'provider_5xx');
      }
      svc.dispose();
    });

    test('零产出：batchSize=3 + success 但两路产物皆空 → job error + 全 slot error',
        () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: []),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jz1');
      await _seedSlots(batchRepo, 'jz1', 3);

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jz1'));
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      final err = (terminal as JobFailure).error;
      expect(err, isA<ProviderError>());
      expect(err.code, InkErrorCode.providerInvalidResponse);
      expect(repo.rows['jz1']!['status'], 'error');
      for (var i = 0; i < 3; i++) {
        expect(_slot(batchRepo, i)['status'], 'error', reason: 'slot $i');
        expect(
          _slot(batchRepo, i)['error_code'],
          'provider_invalid_response',
          reason: 'slot $i',
        );
      }
      expect(nodeRepo.patches, isEmpty, reason: '零产出不 patch 主图');
      svc.dispose();
    });

    test('batchSize==1 零产出 success → 维持 success（语义④）', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: []),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jz2');

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jz2', batchSize: 1));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(repo.rows['jz2']!['status'], 'success');
      expect(batchRepo.rows, isEmpty);
      svc.dispose();
    });

    test('循环中取消：第 1 张后 cancel → 剩余 slot cancelled、已成功保留、job cancelled',
        () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.success(remoteUrls: [
          'https://fake/0.png',
          'https://fake/1.png',
          'https://fake/2.png',
        ]),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jcl');
      await _seedSlots(batchRepo, 'jcl', 3);
      final downloader = _CancelAfterFirstDownloader();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: downloader,
      );
      downloader.afterFirst = () => svc.cancel('jcl');
      final h = await svc.submit(_task(jobId: 'jcl'));
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      expect((terminal as JobFailure).error, isA<CancelledError>());
      expect(repo.rows['jcl']!['status'], 'cancelled');
      expect(_slot(batchRepo, 0)['status'], 'success', reason: '已成功 slot 保留');
      expect(_slot(batchRepo, 1)['status'], 'cancelled');
      expect(_slot(batchRepo, 2)['status'], 'cancelled');
      expect(downloader.calls, 1, reason: '取消后不再下载剩余张');
      svc.dispose();
    });

    test('非取消语境的 rows==0 二次失败 → slot 收敛 error 而非 cancelled', () async {
      // job 行已先落终态（fromStatuses 不命中 → 0 行），但并无用户取消——
      // slot 必须收敛 error，不得从 rows==0 反推成 cancel 赢。
      final provider = _FakeProvider(providerId: 'fake', pollSequence: const [
        JobStatus.failure(
          error: ProviderError(code: InkErrorCode.providerServer),
        ),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jr0', status: 'error');
      await _seedSlots(batchRepo, 'jr0', 2);

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: _SelectiveDownloader(),
      );
      final h = await svc.submit(_task(jobId: 'jr0', batchSize: 2));
      final terminal = await h.done;

      expect(terminal, isA<JobFailure>());
      expect((terminal as JobFailure).error, isA<ProviderError>());
      for (var i = 0; i < 2; i++) {
        expect(_slot(batchRepo, i)['status'], 'error', reason: 'slot $i');
        expect(_slot(batchRepo, i)['error_code'], 'provider_5xx',
            reason: 'slot $i');
      }
      svc.dispose();
    });

    test('inline 与 remote 并存（批量）→ 只按 inline 落，remote 不下载、无双写', () async {
      final provider = _FakeProvider(providerId: 'fake', pollSequence: [
        JobStatus.success(
          remoteUrls: const ['https://fake/r0.png', 'https://fake/r1.png'],
          inlineBytes: [
            Uint8List.fromList(const [7]),
            Uint8List.fromList(const [8]),
          ],
        ),
      ]);
      final registry = CachingProviderRegistry({'fake': () => provider});
      repo.seed('jm1');
      await _seedSlots(batchRepo, 'jm1', 2);
      final downloader = _SelectiveDownloader();

      final svc = _build(
        registry: registry,
        repo: repo,
        nodeRepo: nodeRepo,
        fileResolver: fileResolver,
        batchRepo: batchRepo,
        downloader: downloader,
      );
      final h = await svc.submit(_task(jobId: 'jm1', batchSize: 2));
      final terminal = await h.done;

      expect(terminal, isA<JobSuccess>());
      expect(downloader.succeeded, isEmpty, reason: 'inline 优先，remote 跳过');
      for (var i = 0; i < 2; i++) {
        expect(_slot(batchRepo, i)['status'], 'success', reason: 'slot $i');
        expect(_slot(batchRepo, i)['output_url'], 'images/jm1-$i.png');
        final f = File(
          '${tmp.path}/projects/proj-1/canvases/canvas-1/images/jm1-$i.png',
        );
        expect(f.readAsBytesSync(), [7 + i], reason: '文件内容来自 inline，未被覆盖');
      }
      expect(nodeRepo.patches[_kNode], hasLength(1), reason: '主图只 patch 一次');
      expect(nodeRepo.patches[_kNode]!.first['image_url'], 'images/jm1-0.png');
      svc.dispose();
    });
  });
}
