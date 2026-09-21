// 序列 / 导出标签：可用性判据 + 空态 + 拉起既有对话框。
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
import 'package:inkframe/features/storyboard/widgets/sequence_preview_dialog.dart';
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
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'node repository must not be touched by empty tabs: '
      '${invocation.memberName}');
}

class _ExplodingEdgeRepository implements EdgeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'edge repository must not be touched by empty tabs: '
      '${invocation.memberName}');
}

/// 仓储【被解析】的记账。
///
/// 光有「一碰就炸」的 fake 还不够：控制器的 build 是 async 的，里面抛出的异常
/// 被 Riverpod 收进 AsyncError，既不会冒到 zone 也不会进 tester.takeException()
/// ——于是"把 ref.watch(canvasNodesControllerProvider(canvasId ?? ''))
/// 提到 if 之前"这种改法照样全绿（空态仍然渲染，异常被吞）。
/// 真正有鉴别力的信号是【仓储 provider 有没有被读过】：控制器 build 的第一句
/// 就是 await ref.watch(nodeRepositoryProvider.future)，所以这个布尔位在
/// 异常发生之前就已经翻了。
///
/// 用例内局部（而非文件级可变布尔）：文件级布尔只在 _explodingRepos() 里重置，
/// 若未来有用例调 _expectNoRepositoryTouched 前没先调 _explodingRepos()，读到
/// 的会是【上一条用例的残值】——顺序依赖的假绿/假红。装进这个小对象后，每条
/// 用例天然拿到自己独立的一份，没有"忘了重置"这条路可走。
class _RepoTouchTracker {
  bool nodeRepoResolved = false;
  bool edgeRepoResolved = false;
}

({List<Override> overrides, _RepoTouchTracker tracker}) _explodingRepos() {
  final tracker = _RepoTouchTracker();
  final overrides = <Override>[
    nodeRepositoryProvider.overrideWith((_) async {
      tracker.nodeRepoResolved = true;
      return _ExplodingNodeRepository();
    }),
    edgeRepositoryProvider.overrideWith((_) async {
      tracker.edgeRepoResolved = true;
      return _ExplodingEdgeRepository();
    }),
  ];
  return (overrides: overrides, tracker: tracker);
}

void _expectNoRepositoryTouched(
  WidgetTester tester,
  _RepoTouchTracker tracker,
) {
  expect(
    <bool>[tracker.nodeRepoResolved, tracker.edgeRepoResolved],
    <bool>[false, false],
    reason: '空态分支碰了仓储——懒物化只挡住"没点过的标签"，点开之后的空态分支'
        '必须自证不读仓储：一旦 eager 碰 canvas/node/edge 仓储就会去起真内嵌 '
        'PostgreSQL，覆盖率收集会永挂',
  );
  expect(tester.takeException(), isNull);
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

/// 一个 config 节点 + 挂在它名下的一个 video result（R49 的链序夹具）。
/// position.x 同时喂给两者，好让"退化成 position.x 序"这条路径可观测。
List<CanvasNode> _chainedShot(String tag, {required double x}) => <CanvasNode>[
      CanvasNode(
        id: 'cfg-$tag',
        label: 'cfg-$tag',
        type: CanvasNodeType.video,
        projectId: 'p1',
        canvasId: 'c1',
        position: Offset(x, 0),
      ),
      CanvasNode(
        id: 'r-$tag',
        label: 'take-$tag',
        type: CanvasNodeType.video,
        role: NodeRole.result,
        projectId: 'p1',
        canvasId: 'c1',
        sourceNodeId: 'cfg-$tag',
        position: Offset(x, 0),
        typeConfig: const <String, Object?>{'video_url': 'videos/a.mp4'},
      ),
    ];

CanvasEdge _narrative(String id, {required String from, required String to}) =>
    CanvasEdge(
      id: id,
      canvasId: 'c1',
      sourceNodeId: from,
      targetNodeId: to,
      edgeType: EdgeType.narrative,
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
///
/// 打开画布的那一支必须同时带 project：_open 的 projectId 现在走
/// ShellState.project（spec §8.2），而生产侧三个 openCanvas 调用点全都带
/// withProject，所以"有 canvasId 却没有 project"不是可达态。
Override _shellWith({String? canvasId}) => shellControllerProvider.overrideWith(
      () => ShellNavigator(
        initial: canvasId == null
            ? const ShellState()
            : ShellState(
                tab: ShellTab.canvas,
                canvasId: canvasId,
                project: const ProjectRef(id: 'p1', name: 'Alpha'),
              ),
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

    // R49：只断"边控制器还活着"是**结构代理**，只打得中"把那行 ref.watch 删掉"
    // 这一种改法。保留订阅、只把 _open 里的 edges 换成空（`null ?? const []`）
    // 照样全绿——而后果是对话框照开、导出照跑、无任何报错，用户拿到一条镜头
    // 顺序乱掉的成片。T10 明确会重写这段 _open（projectId 改走 ShellState），
    // 正好是这段代码，所以这里必须有一条断**结果顺序**的断言。
    //
    // 构造：链序 a→b→c 与 position.x 序（c,b,a）刻意**相反**——边一旦落空，
    // orderVideoNodesForExport 会退化成 position.x 升序，顺序当场翻转。
    testWidgets('R49：导出对话框按 narrative 链序列出，而非 position.x 序',
        (tester) async {
      await _pumpExport(
        tester,
        <CanvasNode>[
          ..._chainedShot('c', x: 100),
          ..._chainedShot('b', x: 200),
          ..._chainedShot('a', x: 300),
        ],
        edges: <CanvasEdge>[
          _narrative('e-ab', from: 'cfg-a', to: 'cfg-b'),
          _narrative('e-bc', from: 'cfg-b', to: 'cfg-c'),
        ],
      );

      expect(_cta(tester, Icons.movie_outlined).onPressed, isNotNull);
      await tester.tap(find.byIcon(Icons.movie_outlined));
      await tester.pumpAndSettle();

      final double yA = tester.getTopLeft(find.text('take-a')).dy;
      final double yB = tester.getTopLeft(find.text('take-b')).dy;
      final double yC = tester.getTopLeft(find.text('take-c')).dy;
      expect(
        <double>[yA, yB, yC],
        orderedEquals(<double>[yA, yB, yC]..sort()),
        reason: '链序 a→b→c 必须赢过 position.x 序（c,b,a）——边落空会当场翻转',
      );
    });

    testWidgets('canvasId 为 null → 出去 Studio 引导，不渲染导出 CTA，且不碰仓储',
        (tester) async {
      final repos = _explodingRepos();
      await pumpInkApp(
        tester,
        const Scaffold(body: ExportTab()),
        overrides: <Override>[_shellWith(), ...repos.overrides],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.movie_outlined), findsNothing);
      expect(find.text('No canvas open'), findsOneWidget);
      expect(
        find.text('Open a canvas first, then export its video results here.'),
        findsOneWidget,
      );
      expect(find.text('Go to Studio'), findsOneWidget);
      _expectNoRepositoryTouched(tester, repos.tracker);
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

    // 【本 PR 的核心取舍，不许静默失效】序列预览的 media_kit Player 从 initState
    // 持有到 dispose 且自动播放。正因如此第 1 步才决定：序列标签只做空态 + 拉起
    // 对话框，而【不】把 SequencePreviewContent 抬成常驻标签视图——抬上去它就会
    // 在后台标签里一直播。这条约束只有"关掉对话框后 SequencePreviewContent 不在
    // 树里"能守住。
    //
    // skipOffstage: false 是必需的：默认 true 会跳过 Offstage 子树（保活宿主正是
    // 靠 Offstage 藏起非活动标签），一条"不在树里"的断言不写 false 就是假绿
    // ——本分支已经因此踩过 2/7 例恒真。
    testWidgets('关闭序列对话框后 SequencePreviewContent 离树（Player 已 dispose）',
        (tester) async {
      await _pumpSequence(
        tester,
        edges: <CanvasEdge>[_edge('e1', EdgeType.narrative)],
      );

      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byType(SequencePreviewContent, skipOffstage: false),
        findsOneWidget,
        reason: '前置条件：对话框先得真的开出来，否则下面那条"离树"是恒真的',
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.byType(SequencePreviewContent, skipOffstage: false),
        findsNothing,
        reason: '关掉后还留在树里 ⇒ media_kit Player 没 dispose ⇒ 后台标签里继续播',
      );
    });

    testWidgets('canvasId 为 null → 出去 Studio 引导，不渲染序列 CTA，且不碰仓储',
        (tester) async {
      final repos = _explodingRepos();
      await pumpInkApp(
        tester,
        const Scaffold(body: SequenceTab()),
        overrides: <Override>[_shellWith(), ...repos.overrides],
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_circle_outline), findsNothing);
      expect(find.text('No canvas open'), findsOneWidget);
      expect(
        find.text('Open a canvas first, then preview its narrative chain here.'),
        findsOneWidget,
      );
      expect(find.text('Go to Studio'), findsOneWidget);
      _expectNoRepositoryTouched(tester, repos.tracker);
    });
  });
}
