import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/job_queue.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/job_queue_service.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/batch_result.dart';
import 'package:inkframe/features/generation/generation_controller.dart';
import 'package:inkframe/features/generation/providers/batch_results_controller.dart';

import '../../../_harness/fake_batch_result.dart';
import '../../../_harness/fake_unit_of_work.dart';

class _FakeNodeRepo implements NodeRepository {
  /// 转正后要靠 canvas_id 定点 invalidate 画布节点集合——这里给一个非空值，
  /// 让那条分支真的被走到（测试容器里该 family 没人监听，invalidate 是 no-op）。
  static const String canvasId = 'c1';

  final List<(String, Map<String, Object?>)> patches =
      <(String, Map<String, Object?>)>[];

  @override
  Future<int> patchTypeConfig(String id, Map<String, Object?> patch) async {
    patches.add((id, Map<String, Object?>.of(patch)));
    return 1;
  }

  @override
  Future<Map<String, Object?>?> findById(String id) async =>
      <String, Object?>{'id': id, 'canvas_id': canvasId};

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeGenerationController implements GenerationController {
  final List<String> submitted = <String>[];
  final List<int?> seeds = <int?>[];

  @override
  Future<String> submitFromConfigNode(
    String configNodeId, {
    int? seedOverride,
  }) async {
    submitted.add(configNodeId);
    seeds.add(seedOverride);
    return 'job-${submitted.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeJobQueue implements JobQueueService {
  final List<String> cancelled = <String>[];

  @override
  Future<void> cancel(String jobId) async => cancelled.add(jobId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Map<String, Object?> _row({
  required String id,
  required int slotIndex,
  String status = 'success',
  String? outputUrl,
  bool promoted = false,
  String nodeId = 'n1',
  String jobId = 'j1',
}) => <String, Object?>{
  'id': id,
  'node_id': nodeId,
  'job_id': jobId,
  'slot_index': slotIndex,
  'status': status,
  'output_url': outputUrl,
  'promoted': promoted,
};

void main() {
  late FakeBatchResultRepo repo;
  late _FakeNodeRepo nodes;
  late _FakeGenerationController gen;
  late _FakeJobQueue queue;
  late ProviderContainer container;

  setUp(() {
    repo = FakeBatchResultRepo();
    nodes = _FakeNodeRepo();
    gen = _FakeGenerationController();
    queue = _FakeJobQueue();
    container = ProviderContainer(
      overrides: <Override>[
        batchResultRepositoryProvider.overrideWith((ref) async => repo),
        nodeRepositoryProvider.overrideWith((ref) async => nodes),
        generationControllerProvider.overrideWith((ref) async => gen),
        jobQueueServiceProvider.overrideWith((ref) async => queue),
        unitOfWorkProvider.overrideWith(
          (ref) async => FakeUnitOfWork(
            FakeRepositoryScope(nodes: nodes, batchResults: repo),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<BatchResultsController> boot(String nodeId) async {
    final sub = container.listen(
      batchResultsControllerProvider(nodeId),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(batchResultsControllerProvider(nodeId).future);
    return container.read(batchResultsControllerProvider(nodeId).notifier);
  }

  List<BatchResult> slotsOf(String nodeId) =>
      container.read(batchResultsControllerProvider(nodeId)).valueOrNull!;

  test('build 列出 slot（slot_index 升序，按 node 过滤）', () async {
    await repo.create(
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 1,
      status: 'success',
    );
    await repo.create(
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 0,
      status: 'success',
    );
    await repo.create(
      nodeId: 'other',
      jobId: 'j2',
      slotIndex: 0,
      status: 'generating',
    );
    await boot('n1');
    final list = slotsOf('n1');
    expect(list, hasLength(2));
    expect(list.first.slotIndex, 0);
    expect(list.every((s) => s.nodeId == 'n1'), isTrue);
  });

  test('refresh 反映新 slot', () async {
    final notifier = await boot('n1');
    await repo.create(
      nodeId: 'n1',
      jobId: 'j1',
      slotIndex: 0,
      status: 'success',
    );
    await notifier.refresh();
    expect(slotsOf('n1'), hasLength(1));
    expect(slotsOf('n1').single.isSuccess, isTrue);
  });

  group('promote', () {
    test('写回节点产物 + 标本行 + 清掉同节点旧 promoted 行', () async {
      repo.rows['b1'] = _row(
        id: 'b1',
        slotIndex: 0,
        outputUrl: 'images/old.png',
        promoted: true,
      );
      repo.rows['b2'] = _row(
        id: 'b2',
        slotIndex: 1,
        outputUrl: 'images/new.png',
      );
      final notifier = await boot('n1');

      await notifier.promote(slotsOf('n1')[1]);

      // 1. 节点产物换成这一张
      expect(nodes.patches, hasLength(1));
      expect(nodes.patches.single.$1, 'n1');
      expect(nodes.patches.single.$2, <String, Object?>{
        'image_url': 'images/new.png',
      });
      // 2. 本行 promoted，promoted_node_id 指向当前 result 节点自己
      expect(repo.promotedIds, <String>['b2']);
      expect(repo.rows['b2']!['promoted'], isTrue);
      expect(repo.rows['b2']!['promoted_node_id'], 'n1');
      // 3. 旧那行被清掉（DB 无唯一约束，单选语义只能靠这里维持）
      expect(repo.rows['b1']!['promoted'], isFalse);
      expect(repo.rows['b1']!['promoted_node_id'], isNull);
      // 4. 状态已刷新
      expect(slotsOf('n1')[1].promoted, isTrue);
      expect(slotsOf('n1')[0].promoted, isFalse);
    });

    test('不碰别的节点的 promoted 行', () async {
      repo.rows['b1'] = _row(
        id: 'b1',
        slotIndex: 0,
        outputUrl: 'images/a.png',
      );
      repo.rows['x1'] = _row(
        id: 'x1',
        slotIndex: 0,
        nodeId: 'n2',
        outputUrl: 'images/x.png',
        promoted: true,
      );
      final notifier = await boot('n1');

      await notifier.promote(slotsOf('n1').single);

      expect(repo.rows['x1']!['promoted'], isTrue);
    });

    test('产物为空的 slot 不可转正：一行都不写', () async {
      repo.rows['b1'] = _row(id: 'b1', slotIndex: 0, status: 'error');
      final notifier = await boot('n1');

      await notifier.promote(slotsOf('n1').single);

      expect(nodes.patches, isEmpty);
      expect(repo.promotedIds, isEmpty);
    });

    test('已是当前产物的 slot 不重复转正', () async {
      repo.rows['b1'] = _row(
        id: 'b1',
        slotIndex: 0,
        outputUrl: 'images/a.png',
        promoted: true,
      );
      final notifier = await boot('n1');

      await notifier.promote(slotsOf('n1').single);

      expect(nodes.patches, isEmpty);
      expect(repo.promotedIds, isEmpty);
    });
  });

  group('rerun', () {
    test('不带 seed 覆盖时透传 null', () async {
      final notifier = await boot('n1');
      await notifier.rerun(configNodeId: 's1');
      expect(gen.submitted, <String>['s1']);
      expect(gen.seeds, <int?>[null]);
    });

    test('带 seed 覆盖时透传该 seed（不写回节点 type_config）', () async {
      final notifier = await boot('n1');
      await notifier.rerun(configNodeId: 's1', seedOverride: 4242);
      expect(gen.seeds, <int?>[4242]);
      expect(nodes.patches, isEmpty);
    });

    test('rerunFailed：有失败格就发【一次】，不按失败格数循环', () async {
      // 两个失败格（error + cancelled）。部分重跑不成立——provider 一次调用返 N 张，
      // 一次重跑就是一整批新图，循环发只会扣 k 倍额度。
      repo.rows['b1'] = _row(
        id: 'b1',
        slotIndex: 0,
        outputUrl: 'images/a.png',
      );
      repo.rows['b2'] = _row(id: 'b2', slotIndex: 1, status: 'error');
      repo.rows['b3'] = _row(id: 'b3', slotIndex: 2, status: 'cancelled');
      repo.rows['b4'] = _row(id: 'b4', slotIndex: 3, status: 'generating');
      final notifier = await boot('n1');

      await notifier.rerunFailed(configNodeId: 's1');

      expect(gen.submitted, <String>['s1']);
      expect(gen.seeds, <int?>[null], reason: '整批重跑不带 seed 覆盖');
    });

    test('rerunFailed：没有失败格时是 no-op', () async {
      repo.rows['b1'] = _row(id: 'b1', slotIndex: 0, outputUrl: 'images/a.png');
      repo.rows['b2'] = _row(id: 'b2', slotIndex: 1, status: 'generating');
      final notifier = await boot('n1');

      await notifier.rerunFailed(configNodeId: 's1');

      expect(gen.submitted, isEmpty);
    });
  });

  test('cancelBatch 走 JobQueueService.cancel（整批，不是单格）', () async {
    repo.rows['b1'] = _row(id: 'b1', slotIndex: 0, status: 'generating');
    final notifier = await boot('n1');

    await notifier.cancelBatch('j1');

    expect(queue.cancelled, <String>['j1']);
  });
}
