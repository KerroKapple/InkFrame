// LinkActionController：连线动作编排 + db_code 23505 分流（ME-08 / FIX-009）。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/errors/ink_error.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/link_action_controller.dart';
import 'package:inkframe/features/canvas/providers/link_mode_controller.dart';

class _FakeEdgesController extends CanvasEdgesController {
  _FakeEdgesController({this.error, this.existing = const <CanvasEdge>[]});

  final InkError? error;
  final List<CanvasEdge> existing;
  final List<(String, String)> calls = <(String, String)>[];
  final List<EdgeRole> roles = <EdgeRole>[];

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => existing;

  @override
  Future<CanvasEdge> addEdge({
    required String sourceNodeId,
    required String targetNodeId,
    EdgeType edgeType = EdgeType.data,
    EdgeRole role = EdgeRole.reference,
    int sortOrder = 0,
  }) async {
    calls.add((sourceNodeId, targetNodeId));
    roles.add(role);
    final e = error;
    if (e != null) throw e;
    return CanvasEdge(
      id: 'e1',
      canvasId: arg,
      sourceNodeId: sourceNodeId,
      targetNodeId: targetNodeId,
      edgeType: edgeType,
      role: role,
      sortOrder: sortOrder,
    );
  }
}

class _FakeNodesController extends CanvasNodesController {
  _FakeNodesController(this.nodes);
  final List<CanvasNode> nodes;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => nodes;
}

CanvasNode _node(String id, CanvasNodeType type) =>
    CanvasNode(id: id, label: id, type: type, canvasId: 'c1');

(ProviderContainer, _FakeEdgesController) _make({
  InkError? error,
  List<CanvasNode> nodes = const <CanvasNode>[],
  List<CanvasEdge> existingEdges = const <CanvasEdge>[],
}) {
  final fake = _FakeEdgesController(error: error, existing: existingEdges);
  final container = ProviderContainer(
    overrides: <Override>[
      canvasEdgesControllerProvider.overrideWith(() => fake),
      canvasNodesControllerProvider.overrideWith(
        () => _FakeNodesController(nodes),
      ),
    ],
  );
  addTearDown(container.dispose);
  // autoDispose 状态需要 listener 保活。
  container.listen(linkModeControllerProvider, (_, _) {});
  container.listen(linkActionControllerProvider('c1'), (_, _) {});
  container.listen(canvasNodesControllerProvider('c1'), (_, _) {});
  container.listen(canvasEdgesControllerProvider('c1'), (_, _) {});
  return (container, fake);
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  test('成功连线 → created 事件 + addEdge(source,target) + 退出 link 模式', () async {
    final (container, fake) = _make();
    container.read(linkModeControllerProvider.notifier).start('n1');

    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n2');

    expect(fake.calls, [('n1', 'n2')]);
    expect(
      container.read(linkActionControllerProvider('c1'))?.result,
      LinkActionResult.created,
    );
    expect(container.read(linkModeControllerProvider), isNull);
  });

  test('自连 → selfLinkRejected，不触 DB，退出 link 模式', () async {
    final (container, fake) = _make();
    container.read(linkModeControllerProvider.notifier).start('n1');

    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n1');

    expect(fake.calls, isEmpty);
    expect(
      container.read(linkActionControllerProvider('c1'))?.result,
      LinkActionResult.selfLinkRejected,
    );
    expect(container.read(linkModeControllerProvider), isNull);
  });

  test('db_code 23505 → duplicate（连线已存在）', () async {
    final (container, _) = _make(
      error: const LocalIOError(extra: {'db_code': '23505'}),
    );
    container.read(linkModeControllerProvider.notifier).start('n1');

    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n2');

    expect(
      container.read(linkActionControllerProvider('c1'))?.result,
      LinkActionResult.duplicate,
    );
    expect(container.read(linkModeControllerProvider), isNull);
  });

  test('其他 InkError → failed，不误报 duplicate（ME-08）', () async {
    final (container, _) = _make(
      error: const LocalIOError(extra: {'db_code': '23503'}),
    );
    container.read(linkModeControllerProvider.notifier).start('n1');

    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n2');

    expect(
      container.read(linkActionControllerProvider('c1'))?.result,
      LinkActionResult.failed,
    );
    expect(container.read(linkModeControllerProvider), isNull);
  });

  test('无 db_code 的 InkError → failed', () async {
    final (container, _) = _make(error: const LocalIOError());
    container.read(linkModeControllerProvider.notifier).start('n1');

    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n2');

    expect(
      container.read(linkActionControllerProvider('c1'))?.result,
      LinkActionResult.failed,
    );
  });

  test('非 link 模式调用 → no-op', () async {
    final (container, fake) = _make();

    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n2');

    expect(fake.calls, isEmpty);
    expect(container.read(linkActionControllerProvider('c1')), isNull);
  });

  test('连续两次成功 → 每次都产生新事件（listener 可重复触发）', () async {
    final (container, _) = _make();
    final events = <LinkActionEvent?>[];
    container.listen<LinkActionEvent?>(
      linkActionControllerProvider('c1'),
      (_, next) => events.add(next),
    );

    container.read(linkModeControllerProvider.notifier).start('n1');
    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n2');
    container.read(linkModeControllerProvider.notifier).start('n1');
    await container
        .read(linkActionControllerProvider('c1').notifier)
        .linkTo('n3');

    expect(events.length, 2);
  });

  group('智能默认 role（image → video = first_frame 意图）', () {
    test('image 连 video 且无既有 first_frame 入边 → firstFrame', () async {
      final (container, fake) = _make(nodes: [
        _node('img1', CanvasNodeType.image),
        _node('vid1', CanvasNodeType.video),
      ]);
      await _pump();
      container.read(linkModeControllerProvider.notifier).start('img1');

      await container
          .read(linkActionControllerProvider('c1').notifier)
          .linkTo('vid1');

      expect(fake.roles, [EdgeRole.firstFrame]);
    });

    test('video 已有 first_frame 入边 → 回落 reference', () async {
      final (container, fake) = _make(
        nodes: [
          _node('img1', CanvasNodeType.image),
          _node('img2', CanvasNodeType.image),
          _node('vid1', CanvasNodeType.video),
        ],
        existingEdges: const [
          CanvasEdge(
            id: 'e0',
            canvasId: 'c1',
            sourceNodeId: 'img2',
            targetNodeId: 'vid1',
            edgeType: EdgeType.data,
            role: EdgeRole.firstFrame,
            sortOrder: 0,
          ),
        ],
      );
      await _pump();
      container.read(linkModeControllerProvider.notifier).start('img1');

      await container
          .read(linkActionControllerProvider('c1').notifier)
          .linkTo('vid1');

      expect(fake.roles, [EdgeRole.reference]);
    });

    test('image 连 image → reference（不误伤图生图参考语义）', () async {
      final (container, fake) = _make(nodes: [
        _node('img1', CanvasNodeType.image),
        _node('img2', CanvasNodeType.image),
      ]);
      await _pump();
      container.read(linkModeControllerProvider.notifier).start('img1');

      await container
          .read(linkActionControllerProvider('c1').notifier)
          .linkTo('img2');

      expect(fake.roles, [EdgeRole.reference]);
    });

    test('text 连 video → reference（源非图像产出）', () async {
      final (container, fake) = _make(nodes: [
        _node('t1', CanvasNodeType.text),
        _node('vid1', CanvasNodeType.video),
      ]);
      await _pump();
      container.read(linkModeControllerProvider.notifier).start('t1');

      await container
          .read(linkActionControllerProvider('c1').notifier)
          .linkTo('vid1');

      expect(fake.roles, [EdgeRole.reference]);
    });

    test('节点列表未就绪 → 安全回落 reference', () async {
      final (container, fake) = _make();
      container.read(linkModeControllerProvider.notifier).start('n1');

      await container
          .read(linkActionControllerProvider('c1').notifier)
          .linkTo('n2');

      expect(fake.roles, [EdgeRole.reference]);
    });
  });
}
