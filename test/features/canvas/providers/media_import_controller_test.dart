// MediaImportController 单测（ProviderContainer + 内存仓储 + 假导入服务 / 假抽帧）。
//
// 覆盖：先建全部壳再逐个复制回写；复制中的进度 state 与完成后移除；单个失败只清它自己（硬删壳、
// 不留文件）；不认的扩展名不建节点；视频抽首帧 / 探时长；节点控制器已释放时直写仓储；
// 复制途中壳被用户删了仍回写（软删行先复原、写、再删回去）；写库失败清文件与壳。
//
// 仓储用内存版包一层 [_SpyNodeRepository]：PG 的 patchTypeConfig 带 `deleted_at IS NULL`，
// 软删行写不进去（返回 0）；harness 的 InMemoryNodeRepository 不看 deleted_at，照它测
// 「删了照常回写」那条路会白绿。
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/media_import.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/thumbnail.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/core/interfaces/media_import_service.dart';
import 'package:inkframe/core/interfaces/thumbnail_service.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/media_import_controller.dart';
import 'package:path/path.dart' as p;

import '../../../_harness/fake_canvas.dart' show StubFileResolver;
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../helpers/recording_logger.dart';

const String _pid = 'p1';
const String _cid = 'c1';

/// PG 口径的内存节点仓储：软删行 patchTypeConfig 返回 0；记录 hardDelete；可让 patch 失败。
class _SpyNodeRepository extends InMemoryNodeRepository {
  final List<String> hardDeleted = <String>[];
  bool failPatch = false;

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    if (failPatch) {
      throw const LocalIOError(extra: <String, Object?>{'op': 'patchTypeConfig'});
    }
    if (rows[id]?['deleted_at'] != null) return 0;
    return super.patchTypeConfig(id, patch);
  }

  @override
  Future<int> hardDelete(String id) {
    hardDeleted.add(id);
    return super.hardDelete(id);
  }
}

/// 数 `run` 次数的 UnitOfWork。
class _CountingUnitOfWork implements UnitOfWork {
  _CountingUnitOfWork(this.inner);
  final UnitOfWork inner;
  int runs = 0;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) {
    runs++;
    return inner.run(action);
  }
}

/// 假导入服务：按调用顺序发 `imports/u<n>.<ext>`；可按文件名指定失败、可在复制途中挂起。
class _FakeMediaImportService implements MediaImportService {
  final List<String> copied = <String>[];
  final List<String> discarded = <String>[];

  /// basename → 复制时抛的错。
  final Map<String, LocalIOError> failures = <String, LocalIOError>{};

  /// basename → 图片宽高。
  final Map<String, ({int width, int height})> sizes = <String, ({int width, int height})>{};

  /// 每次复制开始时回调（在报进度之前），给测试看当时的库 / state。
  void Function(String sourcePath)? onCopyStart;

  /// 非 null 时，报完 0.48 / 0.485 两次进度后挂在这里，等测试放行。
  Completer<void>? gate;

  /// 复制挂到 gate 上时完成。
  Completer<void> parked = Completer<void>();

  int _n = 0;

  @override
  Future<ImportedMedia> copyIntoCanvas({
    required String projectId,
    required String canvasId,
    required String sourcePath,
    void Function(double fraction)? onProgress,
  }) async {
    copied.add(sourcePath);
    onCopyStart?.call(sourcePath);
    final String name = p.basename(sourcePath);
    final LocalIOError? failure = failures[name];
    if (failure != null) {
      await _park();
      throw failure;
    }
    onProgress?.call(0.48);
    onProgress?.call(0.485); // 变化不足 1%，不该写 state
    await _park();
    onProgress?.call(1.0);
    final ({int width, int height})? size = sizes[name];
    return ImportedMedia(
      relativePath: 'imports/u${++_n}.${importExtensionOf(sourcePath)}',
      kind: mediaImportKindOf(sourcePath)!,
      bytes: 10,
      width: size?.width,
      height: size?.height,
    );
  }

  Future<void> _park() async {
    final Completer<void>? g = gate;
    if (g == null) return;
    if (!parked.isCompleted) parked.complete();
    await g.future;
  }

  @override
  Future<void> discard({
    required String projectId,
    required String canvasId,
    required String relativePath,
  }) async {
    discarded.add(relativePath);
  }
}

/// 假抽帧：记下目标路径，按设定返回探针结果或抛 ThumbnailError。
class _FakeThumbnail implements ThumbnailService {
  _FakeThumbnail({this.fail = false});
  final bool fail;
  final List<String> destinations = <String>[];

  @override
  Future<VideoProbeResult> extractFirstFrame({
    required String videoPath,
    required File destination,
  }) async {
    destinations.add(destination.path);
    if (fail) throw const ThumbnailError('decode failed');
    return VideoProbeResult(
      thumbnail: destination,
      durationMs: 5000,
      width: 1280,
      height: 720,
    );
  }
}

MediaImportRequest _req(String path, {Offset at = const Offset(10, 20), String? laneId}) =>
    (path: path, placement: (world: at, laneId: laneId));

void main() {
  late _SpyNodeRepository repo;
  late InMemoryEdgeRepository edges;
  late _CountingUnitOfWork uow;
  late _FakeMediaImportService service;
  late RecordingLogger logger;
  late ProviderContainer container;

  final nodesProvider = canvasNodesControllerProvider(_cid);

  ProviderContainer build({ThumbnailService? thumbnail}) {
    final c = ProviderContainer(
      overrides: <Override>[
        nodeRepositoryProvider.overrideWith((_) async => repo),
        edgeRepositoryProvider.overrideWith((_) async => edges),
        unitOfWorkProvider.overrideWith((_) async => uow),
        mediaImportServiceProvider.overrideWithValue(service),
        thumbnailServiceProvider.overrideWithValue(thumbnail),
        fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
        loggerProvider.overrideWithValue(logger),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// 节点控制器加载完并保持订阅（否则 autoDispose 会把它释放掉）。
  Future<void> keepNodesAlive() async {
    container.listen(nodesProvider, (_, _) {});
    await container.read(nodesProvider.future);
  }

  MediaImportController ctrl() => container.read(mediaImportControllerProvider(_cid).notifier);

  Map<String, double> progress() => container.read(mediaImportControllerProvider(_cid));

  List<CanvasNode> liveNodes() => container.read(nodesProvider).requireValue;

  Map<String, Object?> configOf(String id) =>
      repo.rows[id]!['type_config']! as Map<String, Object?>;

  setUp(() {
    repo = _SpyNodeRepository();
    edges = InMemoryEdgeRepository();
    uow = _CountingUnitOfWork(FakeUnitOfWork(FakeRepositoryScope(nodes: repo, edges: edges)));
    service = _FakeMediaImportService();
    logger = RecordingLogger();
  });

  test('两张图一视频：先建 3 个壳（type_config 只有 origin / original_name），再逐个回写 url', () async {
    container = build();
    await keepNodesAlive();
    final List<Map<String, Object?>> configsAtFirstCopy = <Map<String, Object?>>[];
    service.onCopyStart = (String path) {
      if (configsAtFirstCopy.isEmpty && service.copied.length == 1) {
        configsAtFirstCopy.addAll(<Map<String, Object?>>[
          for (final Map<String, Object?> r in repo.rows.values)
            Map<String, Object?>.of(r['type_config']! as Map<String, Object?>),
        ]);
      }
    };
    service.sizes['雾江.jpg'] = (width: 1920, height: 1080);

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[
        _req('/in/雾江.jpg', at: const Offset(0, 0)),
        _req('/in/b.png', at: const Offset(300, 0), laneId: 'lane1'),
        _req('/in/船桨.mp4', at: const Offset(600, 0)),
      ],
    );

    // 第一次复制开始时三个壳都已在库里，且只有 origin / original_name。
    expect(configsAtFirstCopy, <Map<String, Object?>>[
      <String, Object?>{'origin': 'import', 'original_name': '雾江.jpg'},
      <String, Object?>{'origin': 'import', 'original_name': 'b.png'},
      <String, Object?>{'origin': 'import', 'original_name': '船桨.mp4'},
    ]);

    expect(result.skipped, isEmpty);
    expect(result.nodeIds, hasLength(3));
    final String a = result.nodeIds[0];
    final String b = result.nodeIds[1];
    final String v = result.nodeIds[2];

    expect(configOf(a), <String, Object?>{
      'origin': 'import',
      'original_name': '雾江.jpg',
      'image_url': 'imports/u1.jpg',
      'width': 1920,
      'height': 1080,
    });
    expect(configOf(b)['image_url'], 'imports/u2.png');
    expect(configOf(b).containsKey('width'), isFalse, reason: '探不出宽高就不写键');
    expect(configOf(v), <String, Object?>{
      'origin': 'import',
      'original_name': '船桨.mp4',
      'video_url': 'imports/u3.mp4',
    }, reason: '没有抽帧服务 ⇒ 只有 video_url');

    // 库里：产物节点、无来源、label = 原文件名、落点与泳道按请求。
    expect(repo.rows[a]!['node_role'], 'result');
    expect(repo.rows[a]!['source_node_id'], isNull);
    expect(repo.rows[a]!['label'], '雾江.jpg');
    expect(repo.rows[a]!['type'], 'image');
    expect(repo.rows[v]!['type'], 'video');
    expect(repo.rows[b]!['lane_id'], 'lane1');
    expect(repo.rows[b]!['position_x'], 300.0);

    // 内存：节点控制器在 ⇒ 走 patchTypeConfigMany，内存里也带上了 url；新节点带 projectId。
    final Map<String, CanvasNode> byId = <String, CanvasNode>{
      for (final CanvasNode n in liveNodes()) n.id: n,
    };
    expect(byId[a]!.imageUrl, 'imports/u1.jpg');
    expect(byId[v]!.videoUrl, 'imports/u3.mp4');
    expect(byId[a]!.projectId, _pid);
    expect(byId[b]!.projectId, _pid);
    expect(progress(), isEmpty);
  });

  test('复制中 state 有 nodeId 进度（变化 ≥ 1% 才写），完成后移除；壳在内存里带 projectId', () async {
    container = build();
    await keepNodesAlive();
    service.gate = Completer<void>();

    final Future<MediaImportBatchResult> pending = ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/a.png')],
    );
    await service.parked.future;

    final String id = repo.rows.keys.single;
    expect(progress(), <String, double>{id: 0.48});
    expect(liveNodes().single.projectId, _pid);
    expect(liveNodes().single.imageUrl, isNull);

    service.gate!.complete();
    final MediaImportBatchResult result = await pending;

    expect(result.nodeIds, <String>[id]);
    expect(progress(), isEmpty, reason: '完成后从进度表移除');
  });

  test('其中一个复制失败：该节点被 hardDelete（不是软删），其余两张正常；skipped 点名 copyFailed', () async {
    container = build();
    await keepNodesAlive();
    service.failures['b.png'] = const LocalIOError(
      extra: <String, Object?>{'reason': kImportReasonCopyFailed},
    );

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[
        _req('/in/a.png'),
        _req('/in/b.png'),
        _req('/in/c.webp'),
      ],
    );

    expect(result.nodeIds, hasLength(2));
    expect(result.skipped, <MediaImportSkip>[
      (fileName: 'b.png', reason: MediaImportSkipReason.copyFailed),
    ]);
    expect(repo.hardDeleted, hasLength(1));
    final String failedId = repo.hardDeleted.single;
    expect(result.nodeIds, isNot(contains(failedId)));
    expect(repo.rows.containsKey(failedId), isFalse, reason: '硬删：库里不留行，也不进回收站');
    expect(repo.rows, hasLength(2));
    for (final String id in result.nodeIds) {
      expect(repo.rows[id]!['deleted_at'], isNull);
      expect(configOf(id)['image_url'], isNotNull);
    }
    expect(liveNodes().map((CanvasNode n) => n.id), unorderedEquals(result.nodeIds));
    expect(service.discarded, isEmpty, reason: '复制失败时服务自己不留文件，没有要删的');
    expect(progress(), isEmpty);
  });

  test('pdf 不建节点、不复制，skipped 点名 unsupported', () async {
    container = build();
    await keepNodesAlive();

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/notes.pdf'), _req('/in/noext')],
    );

    expect(result.nodeIds, isEmpty);
    expect(result.skipped, <MediaImportSkip>[
      (fileName: 'notes.pdf', reason: MediaImportSkipReason.unsupported),
      (fileName: 'noext', reason: MediaImportSkipReason.unsupported),
    ]);
    expect(repo.rows, isEmpty);
    expect(service.copied, isEmpty);
  });

  test('0 字节 / 源不可读 ⇒ skipped 点名 unreadable，壳被硬删', () async {
    container = build();
    await keepNodesAlive();
    service.failures['empty.png'] = const LocalIOError(
      extra: <String, Object?>{'reason': kImportReasonEmpty},
    );
    service.failures['gone.jpg'] = const LocalIOError(
      extra: <String, Object?>{'reason': kImportReasonUnreadable},
    );

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/empty.png'), _req('/in/gone.jpg')],
    );

    expect(result.nodeIds, isEmpty);
    expect(result.skipped, <MediaImportSkip>[
      (fileName: 'empty.png', reason: MediaImportSkipReason.unreadable),
      (fileName: 'gone.jpg', reason: MediaImportSkipReason.unreadable),
    ]);
    expect(repo.rows, isEmpty, reason: '全部失败：画布上什么也不剩');
    expect(repo.hardDeleted, hasLength(2));
    expect(liveNodes(), isEmpty);
  });

  test('视频：抽帧服务给 duration 5000 ⇒ duration_ms 5000、thumbnail_url imports/<同 uuid>.jpg', () async {
    final _FakeThumbnail thumb = _FakeThumbnail();
    container = build(thumbnail: thumb);
    await keepNodesAlive();

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/船桨.mp4')],
    );

    final String id = result.nodeIds.single;
    expect(configOf(id), <String, Object?>{
      'origin': 'import',
      'original_name': '船桨.mp4',
      'video_url': 'imports/u1.mp4',
      'thumbnail_url': 'imports/u1.jpg',
      'duration_ms': 5000,
      'width': 1280,
      'height': 720,
    });
    expect(thumb.destinations, <String>[
      StubFileResolver().resolve(projectId: _pid, canvasId: _cid, relativePath: 'imports/u1.jpg').path,
    ]);
  });

  test('视频：抽帧失败吞掉（记 warn），视频照常导入、没有 thumbnail_url', () async {
    container = build(thumbnail: _FakeThumbnail(fail: true));
    await keepNodesAlive();

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/a.mov')],
    );

    final String id = result.nodeIds.single;
    expect(configOf(id)['video_url'], 'imports/u1.mov');
    expect(configOf(id).containsKey('thumbnail_url'), isFalse);
    expect(configOf(id).containsKey('duration_ms'), isFalse);
    expect(
      logger.records.where((LogRecord r) => r.msg == 'media_import.thumbnail_failed'),
      hasLength(1),
    );
  });

  test('节点控制器已释放 ⇒ 直写 repo.patchTypeConfig（不经节点控制器的事务）', () async {
    container = build();
    // 不挂订阅：importFiles 建壳时自己挂一个、建完就放，复制途中节点控制器被释放。
    service.gate = Completer<void>();

    final Future<MediaImportBatchResult> pending = ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/a.png')],
    );
    await service.parked.future;
    await pumpEventQueue();
    expect(container.exists(nodesProvider), isFalse, reason: '前提：节点控制器已释放');
    final String id = repo.rows.keys.single;

    service.gate!.complete();
    final MediaImportBatchResult result = await pending;

    expect(result.nodeIds, <String>[id]);
    expect(configOf(id)['image_url'], 'imports/u1.png');
    expect(uow.runs, 0, reason: '没走 patchTypeConfigMany 的事务');
    expect(progress(), isEmpty);
  });

  test('节点控制器已释放时复制失败 ⇒ 直接硬删壳', () async {
    container = build();
    service.gate = Completer<void>();
    service.failures['a.png'] = const LocalIOError(
      extra: <String, Object?>{'reason': kImportReasonCopyFailed},
    );

    final Future<MediaImportBatchResult> pending = ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/a.png')],
    );
    await service.parked.future;
    await pumpEventQueue();
    expect(container.exists(nodesProvider), isFalse, reason: '前提：节点控制器已释放');

    service.gate!.complete();
    final MediaImportBatchResult result = await pending;

    expect(result.nodeIds, isEmpty);
    expect(result.skipped, <MediaImportSkip>[
      (fileName: 'a.png', reason: MediaImportSkipReason.copyFailed),
    ]);
    expect(repo.hardDeleted, hasLength(1));
    expect(repo.rows, isEmpty);
    expect(container.exists(nodesProvider), isFalse, reason: '删壳不该把节点控制器又建起来');
  });

  test('复制中途用户删了壳（removeNode 软删）⇒ 复制完库里该行带 image_url 且仍是软删', () async {
    container = build();
    await keepNodesAlive();
    service.gate = Completer<void>();

    final Future<MediaImportBatchResult> pending = ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/a.png')],
    );
    await service.parked.future;
    final String id = repo.rows.keys.single;
    await container.read(nodesProvider.notifier).removeNode(id);
    expect(repo.rows[id]!['deleted_at'], isNotNull, reason: '前提：壳已软删');
    expect(liveNodes(), isEmpty);

    service.gate!.complete();
    final MediaImportBatchResult result = await pending;

    expect(result.nodeIds, <String>[id]);
    expect(configOf(id)['image_url'], 'imports/u1.png');
    expect(repo.rows[id]!['deleted_at'], isNotNull, reason: '回写后删回去：仍在回收站');
    expect(repo.hardDeleted, isEmpty);
    expect(service.discarded, isEmpty);
    expect(liveNodes(), isEmpty, reason: '删掉的卡不会因为回写又出现在画布上');
  });

  test('写库失败（仓储 patchTypeConfig 抛 LocalIOError）⇒ 文件与首帧被 discard、壳被 hardDelete、点名 copyFailed',
      () async {
    container = build(thumbnail: _FakeThumbnail());
    await keepNodesAlive();
    repo.failPatch = true;

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/a.mp4')],
    );

    expect(result.nodeIds, isEmpty);
    expect(result.skipped, <MediaImportSkip>[
      (fileName: 'a.mp4', reason: MediaImportSkipReason.copyFailed),
    ]);
    expect(service.discarded, <String>['imports/u1.mp4', 'imports/u1.jpg']);
    expect(repo.hardDeleted, hasLength(1));
    expect(repo.rows, isEmpty);
    expect(liveNodes(), isEmpty);
    expect(progress(), isEmpty);
  });

  test('clipImportLabel 按字符截到 200（emoji 不被截成半个）', () {
    expect(clipImportLabel('a.png'), 'a.png');
    final String long = '${'😀' * 250}.png';
    final String clipped = clipImportLabel(long);
    expect(clipped.runes.length, kImportLabelMaxChars);
    expect(clipped, '😀' * 200);
  });

  test('原文件名超长 ⇒ label 截到 200 个字符，original_name 存全名', () async {
    container = build();
    await keepNodesAlive();
    final String name = '${'雾' * 250}.jpg';

    final MediaImportBatchResult result = await ctrl().importFiles(
      projectId: _pid,
      requests: <MediaImportRequest>[_req('/in/$name')],
    );

    final String id = result.nodeIds.single;
    expect((repo.rows[id]!['label']! as String).runes.length, kImportLabelMaxChars);
    expect(configOf(id)['original_name'], name);
  });
}
