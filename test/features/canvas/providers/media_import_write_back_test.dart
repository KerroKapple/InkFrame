// MediaImportController 回写：库是准绳，回写写 0 行不能静默算成功。
//
// 旧路径：这张卡还在节点控制器内存里 ⇒ 只走 patchTypeConfigMany。它不看行数，壳行已软删
// （被懒启动的空壳清扫收走 / removeNode 已排进串行队列、排在回写前面）或已硬删时写 0 行
// 照样「成功」——内存显示成图，库里没有 url，重开画布卡片就没了，文件变孤儿。
//
// 三条：
//   ① 复制途中壳行被软删、内存不动 ⇒ 放行后库里带上 url；
//   ② 复制途中 removeNode 已入队（排在一个卡住的写之后，还没执行）⇒ 回写先落库，软删的行带 url；
//   ③ 复制途中壳行被硬删、内存不动 ⇒ 不算导入成功：文件 discard、卡从内存移走、点名 copyFailed。
//
// 仓储用内存版包一层 [_PgLikeNodeRepository]：PG 的 patchTypeConfig 带 `deleted_at IS NULL`，
// 软删行写不进去（返回 0）；harness 的 InMemoryNodeRepository 不看 deleted_at。
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/constants/import_keys.dart';
import 'package:inkframe/core/di/file_resolver.dart';
import 'package:inkframe/core/di/logger.dart';
import 'package:inkframe/core/di/media_import.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/di/thumbnail.dart';
import 'package:inkframe/core/interfaces/media_import_service.dart';
import 'package:inkframe/core/interfaces/unit_of_work.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/media_import_controller.dart';

import '../../../_harness/fake_canvas.dart' show StubFileResolver;
import '../../../_harness/fake_repositories.dart';
import '../../../_harness/fake_unit_of_work.dart';
import '../../../helpers/recording_logger.dart';

const String _pid = 'p1';
const String _cid = 'c1';

/// PG 口径的内存节点仓储：软删行 patchTypeConfig 返回 0。
class _PgLikeNodeRepository extends InMemoryNodeRepository {
  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    if (rows[id]?['deleted_at'] != null) return 0;
    return super.patchTypeConfig(id, patch);
  }
}

/// [hold] 非 null 时，每次 run 先等它完成——用来把节点控制器的串行队列卡在一个写上。
class _HoldableUnitOfWork implements UnitOfWork {
  _HoldableUnitOfWork(this.inner);
  final UnitOfWork inner;
  Completer<void>? hold;

  @override
  Future<T> run<T>(Future<T> Function(RepositoryScope scope) action) async {
    final Completer<void>? h = hold;
    if (h != null) await h.future;
    return inner.run(action);
  }
}

/// 假导入服务：发 `imports/u<n>.<ext>`；报完 0.48 后挂在 [gate] 上等测试放行。
class _GatedImportService implements MediaImportService {
  final List<String> discarded = <String>[];
  final Completer<void> gate = Completer<void>();
  final Completer<void> parked = Completer<void>();
  int _n = 0;

  @override
  Future<ImportedMedia> copyIntoCanvas({
    required String projectId,
    required String canvasId,
    required String sourcePath,
    void Function(double fraction)? onProgress,
  }) async {
    onProgress?.call(0.48);
    if (!parked.isCompleted) parked.complete();
    await gate.future;
    onProgress?.call(1.0);
    return ImportedMedia(
      relativePath: 'imports/u${++_n}.${importExtensionOf(sourcePath)}',
      kind: mediaImportKindOf(sourcePath)!,
      bytes: 10,
    );
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

void main() {
  late _PgLikeNodeRepository repo;
  late _HoldableUnitOfWork uow;
  late _GatedImportService service;
  late ProviderContainer container;

  final nodesProvider = canvasNodesControllerProvider(_cid);

  setUp(() {
    repo = _PgLikeNodeRepository();
    final InMemoryEdgeRepository edges = InMemoryEdgeRepository();
    uow = _HoldableUnitOfWork(
      FakeUnitOfWork(FakeRepositoryScope(nodes: repo, edges: edges)),
    );
    service = _GatedImportService();
    container = ProviderContainer(
      overrides: <Override>[
        nodeRepositoryProvider.overrideWith((_) async => repo),
        edgeRepositoryProvider.overrideWith((_) async => edges),
        unitOfWorkProvider.overrideWith((_) async => uow),
        mediaImportServiceProvider.overrideWithValue(service),
        thumbnailServiceProvider.overrideWithValue(null),
        fileResolverServiceProvider.overrideWithValue(StubFileResolver()),
        loggerProvider.overrideWithValue(RecordingLogger()),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> keepNodesAlive() async {
    container.listen(nodesProvider, (_, _) {});
    await container.read(nodesProvider.future);
  }

  Future<MediaImportBatchResult> startImport() => container
      .read(mediaImportControllerProvider(_cid).notifier)
      .importFiles(
        projectId: _pid,
        requests: <MediaImportRequest>[
          (path: '/in/a.png', placement: (world: Offset.zero, laneId: null)),
        ],
      );

  /// 本次导入建的壳（库里 origin=import 的那一行）。
  String shellId() => repo.rows.entries
      .where((MapEntry<String, Map<String, Object?>> e) =>
          (e.value['type_config']! as Map<String, Object?>)[ImportKeys.origin] ==
          ImportKeys.originImport)
      .single
      .key;

  Map<String, Object?> configOf(String id) =>
      repo.rows[id]!['type_config']! as Map<String, Object?>;

  List<CanvasNode> liveNodes() => container.read(nodesProvider).requireValue;

  test('① 复制途中壳行被软删（清扫收走）、内存不动 ⇒ 放行后库里带上 image_url', () async {
    await keepNodesAlive();
    final Future<MediaImportBatchResult> pending = startImport();
    await service.parked.future;
    final String id = shellId();
    // 模拟懒启动的空壳清扫：只动库，不动节点控制器内存。
    repo.rows[id]!['deleted_at'] = DateTime.now().toUtc().toIso8601String();
    expect(liveNodes().map((CanvasNode n) => n.id), contains(id), reason: '前提：内存里还在');

    service.gate.complete();
    final MediaImportBatchResult result = await pending;

    expect(configOf(id)['image_url'], 'imports/u1.png', reason: '库里必须落 url，不能只改内存');
    expect(repo.rows[id]!['deleted_at'], isNotNull, reason: '回写不改变行的软删状态');
    expect(result.nodeIds, <String>[id]);
  });

  test('② removeNode 已入队但还没执行时放行复制 ⇒ 回写先落库，删完的行带 image_url', () async {
    final String blocker = await repo.create(
      canvasId: _cid,
      type: 'image',
      nodeRole: 'result',
      typeConfig: const <String, Object?>{'image_url': 'images/x.png'},
    );
    await keepNodesAlive();
    final Future<MediaImportBatchResult> pending = startImport();
    await service.parked.future;
    final String id = shellId();

    // 卡住节点控制器的串行队列：先删一张别的卡（卡在 uow.run 上），再删壳（排在它后面）。
    uow.hold = Completer<void>();
    final Future<Object?> removeBlocker =
        container.read(nodesProvider.notifier).removeNode(blocker);
    await pumpEventQueue();
    final Future<Object?> removeShell =
        container.read(nodesProvider.notifier).removeNode(id);
    await pumpEventQueue();
    expect(liveNodes().map((CanvasNode n) => n.id), contains(id),
        reason: '前提：壳的 removeNode 还没执行');

    service.gate.complete();
    await pumpEventQueue();
    uow.hold!.complete();
    final MediaImportBatchResult result = await pending;
    await removeBlocker;
    await removeShell;

    expect(repo.rows[id]!['deleted_at'], isNotNull, reason: '前提：壳最终被软删');
    expect(configOf(id)['image_url'], 'imports/u1.png', reason: '软删的行也带上了 url（撤销删除时完整）');
    expect(liveNodes().map((CanvasNode n) => n.id), isNot(contains(id)));
    expect(result.nodeIds, <String>[id]);
  });

  test('③ 复制途中壳行被硬删、内存不动 ⇒ 回写 0 行不算成功：文件 discard、卡移走、点名 copyFailed',
      () async {
    await keepNodesAlive();
    final Future<MediaImportBatchResult> pending = startImport();
    await service.parked.future;
    final String id = shellId();
    await repo.hardDelete(id);
    expect(liveNodes().map((CanvasNode n) => n.id), contains(id), reason: '前提：内存里还在');

    service.gate.complete();
    final MediaImportBatchResult result = await pending;

    expect(result.nodeIds, isEmpty, reason: '库里没有这一行，不能报导入成功');
    expect(result.skipped, <MediaImportSkip>[
      (fileName: 'a.png', reason: MediaImportSkipReason.copyFailed),
    ]);
    expect(service.discarded, <String>['imports/u1.png'], reason: '文件不留成孤儿');
    expect(liveNodes().map((CanvasNode n) => n.id), isNot(contains(id)),
        reason: '内存里不留一张库里没有的卡');
  });
}
