// 序列 / 导出标签的可用性判据（T7 过渡形状）。
//
// 本文件的用例【整体搬运】自 canvas_top_chrome_sequence_test.dart 与
// canvas_top_chrome_export_test.dart——那两个文件随 CanvasTopChrome 删除，但
// 覆盖面一条不许丢：判据本身（hasNarrativeEdges / canExportVideo）是原样搬到
// lib/features/shell/util/tab_availability.dart 的纯函数，不是重写。
//
// 与旧用例的唯一形状差异：入口从顶栏 IconButton 变成标签里的 InkGhostButton，
// 于是断言从 IconButton.onPressed 改成 InkGhostButton.onPressed。禁用/可用的
// 语义与 tooltip 文案一字未动。
//
// canvasId == null 那一支【不 watch 任何仓储】——序列/导出标签一旦 eager 碰
// canvas/node/edge 仓储就会去起真内嵌 PG，boot 级测试会挂到 isolate 超时。
// 本文件用「一碰就抛」的 fake 仓储把这条自证出来。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/core/di/repositories.dart';
import 'package:inkframe/core/interfaces/edge_repository.dart';
import 'package:inkframe/core/interfaces/node_repository.dart';
import 'package:inkframe/features/canvas/models/canvas_edge.dart';
import 'package:inkframe/features/canvas/models/canvas_node.dart';
import 'package:inkframe/features/canvas/providers/canvas_edges_controller.dart';
import 'package:inkframe/features/canvas/providers/canvas_nodes_controller.dart';
import 'package:inkframe/features/shell/models/shell_state.dart';
import 'package:inkframe/features/shell/providers/shell_controller.dart';
import 'package:inkframe/features/shell/widgets/tabs/export_tab.dart';
import 'package:inkframe/features/shell/widgets/tabs/sequence_tab.dart';
import 'package:inkframe/theme/primitives/ink_ghost_button.dart';

import '../../_harness/test_app.dart';

class _FakeNodesController extends CanvasNodesController {
  _FakeNodesController(this.nodes);
  final List<CanvasNode> nodes;

  @override
  Future<List<CanvasNode>> build(String canvasId) async => nodes;
}

class _FakeEdgesController extends CanvasEdgesController {
  _FakeEdgesController(this.edges);
  final List<CanvasEdge> edges;

  @override
  Future<List<CanvasEdge>> build(String canvasId) async => edges;
}

/// 被碰到就炸：用来证明 canvasId == null 那一支真的不读仓储。
class _ExplodingNodeRepository implements NodeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('node repository must not be touched by empty tabs');
}

class _ExplodingEdgeRepository implements EdgeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('edge repository must not be touched by empty tabs');
}

CanvasNode _videoResult(String id, {String? canvasId = 'c1'}) => CanvasNode(
      id: id,
      label: id,
      type: CanvasNodeType.video,
      role: NodeRole.result,
      projectId: 'p1',
      canvasId: canvasId,
      sourceNodeId: 'cfg-$id',
      typeConfig: const <String, Object?>{'video_url': 'videos/a.mp4'},
    );

CanvasEdge _edge(String id, EdgeType type) => CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: 'a',
      targetNodeId: 'b',
      edgeType: type,
    );

const _shot = CanvasNode(
  id: 'a',
  label: 'a',
  type: CanvasNodeType.shot,
  projectId: 'p1',
  canvasId: 'c1',
  typeConfig: <String, Object?>{'shot_notes': 'x'},
);

/// 播种外壳态（canvasId 是 ShellState 的派生投影，禁止 override 投影本身）。
Override _shellWith({String? canvasId}) => shellControllerProvider.overrideWith(
      () => ShellNavigator(
        initial: canvasId == null
            ? const ShellState()
            : ShellState(tab: ShellTab.canvas, canvasId: canvasId),
      ),
    );

InkGhostButton _cta(WidgetTester tester, IconData icon) =>
    tester.widget<InkGhostButton>(
      find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(InkGhostButton),
      ),
    );

String _tooltip(WidgetTester tester, IconData icon) => tester
    .widget<Tooltip>(
      find.ancestor(of: find.byIcon(icon), matching: find.byType(Tooltip)),
    )
    .message!;

Future<void> _pumpExport(
  WidgetTester tester,
  List<CanvasNode> nodes, {
  List<CanvasEdge> edges = const <CanvasEdge>[],
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: ExportTab()),
    overrides: <Override>[
      _shellWith(canvasId: 'c1'),
      canvasNodesControllerProvider
          .overrideWith(() => _FakeNodesController(nodes)),
      canvasEdgesControllerProvider
          .overrideWith(() => _FakeEdgesController(edges)),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSequence(
  WidgetTester tester, {
  required List<CanvasEdge> edges,
  List<CanvasNode> nodes = const <CanvasNode>[_shot],
}) async {
  await pumpInkApp(
    tester,
    const Scaffold(body: SequenceTab()),
    overrides: <Override>[
      _shellWith(canvasId: 'c1'),
      canvasNodesControllerProvider
          .overrideWith(() => _FakeNodesController(nodes)),
      canvasEdgesControllerProvider
          .overrideWith(() => _FakeEdgesController(edges)),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('导出标签', () {
    testWidgets('有 video result 节点 → 导出可用', (tester) async {
      await _pumpExport(tester, <CanvasNode>[_videoResult('n1')]);

      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(_cta(tester, Icons.movie_outlined).onPressed, isNotNull);
      expect(_tooltip(tester, Icons.movie_outlined), 'Export video');
    });

    testWidgets('无 video result（仅 config / 无 videoUrl）→ 禁用 + 说明 tooltip',
        (tester) async {
      await _pumpExport(tester, <CanvasNode>[
        const CanvasNode(
          id: 'cfg1',
          label: 'cfg1',
          type: CanvasNodeType.video,
          canvasId: 'c1',
        ),
        const CanvasNode(
          id: 'r-nourl',
          label: 'r-nourl',
          type: CanvasNodeType.video,
          role: NodeRole.result,
          canvasId: 'c1',
          sourceNodeId: 'cfg1',
        ),
      ]);

      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(_cta(tester, Icons.movie_outlined).onPressed, isNull);
      expect(
        _tooltip(tester, Icons.movie_outlined),
        'No video results on this canvas yet',
      );
    });

    testWidgets('按压时过滤：缺 canvasId 的节点不进对话框（与 controller 过滤一致）',
        (tester) async {
      await _pumpExport(tester, <CanvasNode>[
        _videoResult('kept-node'),
        _videoResult('dropped-node', canvasId: null),
      ]);

      expect(_cta(tester, Icons.movie_outlined).onPressed, isNotNull);
      await tester.tap(find.byIcon(Icons.movie_outlined));
      await tester.pumpAndSettle();

      expect(find.text('kept-node'), findsOneWidget);
      expect(find.text('dropped-node'), findsNothing);
    });

    testWidgets('canvasId 为 null → 出去 Studio 引导，不渲染导出 CTA，且不碰仓储',
        (tester) async {
      await pumpInkApp(
        tester,
        const Scaffold(body: ExportTab()),
        overrides: <Override>[
          _shellWith(),
          nodeRepositoryProvider
              .overrideWith((_) async => _ExplodingNodeRepository()),
          edgeRepositoryProvider
              .overrideWith((_) async => _ExplodingEdgeRepository()),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.movie_outlined), findsNothing);
      expect(find.text('No canvas open'), findsOneWidget);
      expect(find.text('Go to Studio'), findsOneWidget);
    });
  });

  // 拆分标签时最容易丢的东西：旧 CanvasTopChrome 里序列按钮 watch 边、导出按钮
  // watch 节点，两者互相替对方把 autoDispose family 撑着。拆成两个标签后这层
  // 【隐式】依赖断了：没订阅的那一侧在 _open 里 ref.read 只拿到 AsyncLoading，
  // 序列按钮会变哑键，导出会静默退化成非叙事链序。两条都不会抛错。
  group('跨控制器订阅（拆分标签后最容易静默丢的一条）', () {
    testWidgets('序列标签订阅了节点控制器', (tester) async {
      await _pumpSequence(
        tester,
        edges: <CanvasEdge>[_edge('e1', EdgeType.narrative)],
      );
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(SequenceTab)),
        listen: false,
      );

      expect(
        container.exists(canvasNodesControllerProvider('c1')),
        isTrue,
        reason: '没订阅节点 ⇒ _open 读到 AsyncLoading ⇒ 按钮变哑键',
      );
    });

    testWidgets('导出标签订阅了边控制器', (tester) async {
      await _pumpExport(tester, <CanvasNode>[_videoResult('n1')]);
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(ExportTab)),
        listen: false,
      );

      expect(
        container.exists(canvasEdgesControllerProvider('c1')),
        isTrue,
        reason: '没订阅边 ⇒ 导出默认序静默退化成非叙事链序（EX-1′ 失效）',
      );
    });
  });

  group('序列标签', () {
    testWidgets('有 narrative 边 → 序列预览可用', (tester) async {
      await _pumpSequence(
        tester,
        edges: <CanvasEdge>[_edge('e1', EdgeType.narrative)],
      );

      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
      expect(_cta(tester, Icons.play_circle_outline).onPressed, isNotNull);
    });

    testWidgets('无边 → 禁用', (tester) async {
      await _pumpSequence(tester, edges: const <CanvasEdge>[]);

      expect(_cta(tester, Icons.play_circle_outline).onPressed, isNull);
    });

    testWidgets('只有 data / generation_source 边 → 仍禁用（不是叙事链）',
        (tester) async {
      await _pumpSequence(tester, edges: <CanvasEdge>[
        _edge('e1', EdgeType.data),
        _edge('e2', EdgeType.generationSource),
      ]);

      expect(_cta(tester, Icons.play_circle_outline).onPressed, isNull);
    });

    testWidgets('点击打开序列预览对话框', (tester) async {
      await _pumpSequence(
        tester,
        edges: <CanvasEdge>[_edge('e1', EdgeType.narrative)],
      );

      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pump(); // 起 route 过渡
      await tester.pump(const Duration(milliseconds: 400)); // 过渡走完 + 首帧回调

      // 单个无产物的 shot → 占位文案在场即证明清单构建与对话框都通了。
      expect(find.text('Not generated yet'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink()); // 收尾:走 dispose 取消定时器
    });

    testWidgets('canvasId 为 null → 出去 Studio 引导，不渲染序列 CTA，且不碰仓储',
        (tester) async {
      await pumpInkApp(
        tester,
        const Scaffold(body: SequenceTab()),
        overrides: <Override>[
          _shellWith(),
          nodeRepositoryProvider
              .overrideWith((_) async => _ExplodingNodeRepository()),
          edgeRepositoryProvider
              .overrideWith((_) async => _ExplodingEdgeRepository()),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.text('No canvas open'), findsOneWidget);
    });
  });
}
