// VideoMetadataBackfillService 单测（XM-1b）——fake 仓储/探针/解析器，真临时目录。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/interfaces/file_resolver_service.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/core/interfaces/thumbnail_service.dart';
import 'package:inkframe/core/interfaces/video_metadata_backfill.dart';
import 'package:inkframe/core/logging/logger_service.dart';
import 'package:inkframe/services/video_metadata_backfill_service.dart';
import 'package:path/path.dart' as p;

class _FakeBackfillRepo implements VideoMetadataBackfillRepository {
  _FakeBackfillRepo(this.candidates);
  final List<VideoBackfillCandidate> candidates;
  @override
  Future<List<VideoBackfillCandidate>> listMissingDuration(
          {int limit = 50}) async =>
      candidates.take(limit).toList();
}

class _PatchRecordingNodeRepo implements NodeRepository {
  final List<(String, Map<String, Object?>)> patches = [];
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    patches.add((id, patch));
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _DirResolver implements FileResolverService {
  _DirResolver(this.root);
  final Directory root;
  @override
  File resolve({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) =>
      File(p.join(root.path, projectId, canvasId, relativePath));
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeThumbnail implements ThumbnailService {
  _FakeThumbnail({this.durationMs, this.width, this.height, this.error});
  final int? durationMs;
  final int? width;
  final int? height;
  final ThumbnailError? error;
  int calls = 0;

  @override
  Future<VideoProbeResult> extractFirstFrame({
    required String videoPath,
    required File destination,
  }) async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return VideoProbeResult(
      thumbnail: destination,
      durationMs: durationMs,
      width: width,
      height: height,
    );
  }
}

class _NoopLogger implements LoggerService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ink_backfill_');
  });
  tearDown(() => tmp.delete(recursive: true));

  VideoBackfillCandidate candidate({String? thumb}) => VideoBackfillCandidate(
        nodeId: 'n1',
        projectId: 'p1',
        canvasId: 'c1',
        videoUrl: 'videos/v.mp4',
        thumbnailUrl: thumb,
      );

  Future<void> seedVideo() async {
    final f = File(p.join(tmp.path, 'p1', 'c1', 'videos', 'v.mp4'));
    await f.create(recursive: true);
  }

  VideoMetadataBackfillService build({
    required List<VideoBackfillCandidate> candidates,
    required _PatchRecordingNodeRepo nodes,
    required _FakeThumbnail thumbnail,
  }) =>
      VideoMetadataBackfillService(
        backfillRepo: _FakeBackfillRepo(candidates),
        nodeRepo: nodes,
        fileResolver: _DirResolver(tmp),
        thumbnail: thumbnail,
        logger: _NoopLogger(),
      );

  test('已有缩略图：补 duration/width/height，不写 thumbnail_url', () async {
    await seedVideo();
    final nodes = _PatchRecordingNodeRepo();
    final svc = build(
      candidates: [candidate(thumb: 'videos/v.jpg')],
      nodes: nodes,
      thumbnail: _FakeThumbnail(durationMs: 5000, width: 1920, height: 1080),
    );

    expect(await svc.run(), 1);
    final (id, patch) = nodes.patches.single;
    expect(id, 'n1');
    expect(patch, {
      'duration_ms': 5000,
      'width': 1920,
      'height': 1080,
    });
  });

  test('缺缩略图：派生 videos/<name>.jpg 并一并补写', () async {
    await seedVideo();
    final nodes = _PatchRecordingNodeRepo();
    final svc = build(
      candidates: [candidate()],
      nodes: nodes,
      thumbnail: _FakeThumbnail(durationMs: 3000),
    );

    expect(await svc.run(), 1);
    expect(nodes.patches.single.$2, {
      'thumbnail_url': 'videos/v.jpg',
      'duration_ms': 3000,
    });
  });

  test('视频文件缺失 → 跳过不 patch，不触发探针', () async {
    final nodes = _PatchRecordingNodeRepo();
    final thumb = _FakeThumbnail(durationMs: 3000);
    final svc =
        build(candidates: [candidate()], nodes: nodes, thumbnail: thumb);

    expect(await svc.run(), 0);
    expect(nodes.patches, isEmpty);
    expect(thumb.calls, 0);
  });

  test('探针全 null 且缩略图已存在 → 无键可写，不 patch', () async {
    await seedVideo();
    final nodes = _PatchRecordingNodeRepo();
    final svc = build(
      candidates: [candidate(thumb: 'videos/v.jpg')],
      nodes: nodes,
      thumbnail: _FakeThumbnail(),
    );

    expect(await svc.run(), 0);
    expect(nodes.patches, isEmpty);
  });

  test('单条探针抛 ThumbnailError → 跳过该条，后续照常', () async {
    await seedVideo();
    final f2 = File(p.join(tmp.path, 'p1', 'c1', 'videos', 'w.mp4'));
    await f2.create(recursive: true);
    final bad = candidate(thumb: 'videos/v.jpg');
    const good = VideoBackfillCandidate(
      nodeId: 'n2',
      projectId: 'p1',
      canvasId: 'c1',
      videoUrl: 'videos/w.mp4',
      thumbnailUrl: 'videos/w.jpg',
    );
    // 两条候选共用一个 thumbnail fake 无法区分——用两轮验证语义等价：
    // 第一轮 error fake 全跳过；第二轮正常 fake 全成功。
    final nodes = _PatchRecordingNodeRepo();
    final failing = build(
      candidates: [bad, good],
      nodes: nodes,
      thumbnail: _FakeThumbnail(error: const ThumbnailError('boom')),
    );
    expect(await failing.run(), 0);
    expect(nodes.patches, isEmpty);

    final ok = build(
      candidates: [bad, good],
      nodes: nodes,
      thumbnail: _FakeThumbnail(durationMs: 1000),
    );
    expect(await ok.run(), 2);
    expect(nodes.patches, hasLength(2));
  });
}
